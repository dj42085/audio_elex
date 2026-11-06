#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#include "Vdelta_sigma_dac_stream.h"
#include "verilated.h"

extern "C" {
#include "helix_mp3.h"
}

namespace {

constexpr uint64_t kSimulationDurationNs = 2'000'000;
constexpr uint64_t kClockPeriodNs = 20;
constexpr uint32_t kSamplePeriodCycles = 1134;
constexpr uint32_t kResetCycles = 5;
constexpr size_t kPcmChannels = 2;

struct MemoryStream {
    const uint8_t *data;
    size_t size;
    size_t offset;
};

int seek_memory(void *user_data, int offset)
{
    auto *stream = static_cast<MemoryStream *>(user_data);
    if (offset < 0 || static_cast<size_t>(offset) > stream->size)
        return -1;
    stream->offset = static_cast<size_t>(offset);
    return 0;
}

size_t read_memory(void *user_data, void *buffer, size_t size)
{
    auto *stream = static_cast<MemoryStream *>(user_data);
    const size_t count = std::min(size, stream->size - stream->offset);
    std::copy_n(stream->data + stream->offset, count,
        static_cast<uint8_t *>(buffer));
    stream->offset += count;
    return count;
}

uint8_t output_state(const Vdelta_sigma_dac_stream &top)
{
    return static_cast<uint8_t>(
        (top.dac_out      ? 1u : 0u) |
        (top.pwm_high     ? 1u << 1 : 0u) |
        (top.pwm_low      ? 1u << 2 : 0u) |
        (top.pwm_n_high   ? 1u << 3 : 0u) |
        (top.pwm_n_low    ? 1u << 4 : 0u) |
        (top.sync_out     ? 1u << 5 : 0u));
}

void write_vector_row(std::ofstream &out, uint64_t time_ns, uint8_t state)
{
    out << std::scientific << std::setprecision(12)
        << static_cast<double>(time_ns) * 1.0e-9;
    for (unsigned bit = 0; bit < 6; ++bit)
        out << ' ' << ((state >> bit) & 1u) << 's';
    out << '\n';
}

} // namespace

int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " input.mp3 output.vec\n";
        return 2;
    }

    std::ifstream mp3_file(argv[1], std::ios::binary);
    if (!mp3_file) {
        std::cerr << "Cannot open MP3 input: " << argv[1] << '\n';
        return 1;
    }
    const std::vector<uint8_t> mp3_data(
        std::istreambuf_iterator<char>(mp3_file), {});
    if (mp3_data.empty()) {
        std::cerr << "MP3 input is empty: " << argv[1] << '\n';
        return 1;
    }

    MemoryStream memory = {mp3_data.data(), mp3_data.size(), 0};
    helix_mp3_io_t io = {seek_memory, read_memory, &memory};
    helix_mp3_t decoder;
    const int init_error = helix_mp3_init(&decoder, &io);
    if (init_error != 0) {
        std::cerr << "Helix decoder initialization failed: " << init_error
                  << '\n';
        return 1;
    }

    const size_t simulation_cycles = kSimulationDurationNs / kClockPeriodNs;
    const size_t decoded_frame_capacity =
        simulation_cycles / kSamplePeriodCycles + 2;
    std::vector<int16_t> pcm(decoded_frame_capacity * kPcmChannels);
    const size_t decoded_frames = helix_mp3_read_pcm_frames_s16(
        &decoder, pcm.data(), decoded_frame_capacity);
    const uint32_t sample_rate = helix_mp3_get_sample_rate(&decoder);
    helix_mp3_deinit(&decoder);
    if (decoded_frames == 0) {
        std::cerr << "MP3 input contains no decodable PCM frames\n";
        return 1;
    }

    std::ofstream vector_file(argv[2]);
    if (!vector_file) {
        std::cerr << "Cannot create XSPICE vector file: " << argv[2] << '\n';
        return 1;
    }
    vector_file << "* Verilator DAC outputs: dac_out pwm_high pwm_low "
                   "pwm_n_high pwm_n_low sync_out\n"
                << "* Generated from the first 2 ms of " << argv[1] << '\n';

    Vdelta_sigma_dac_stream top;
    top.clk = 0;
    top.rst_n = 0;
    top.test_mode = 0;
    top.sample_data = 0;
    top.sample_valid = 0;
    top.eval();

    uint8_t last_state = output_state(top);
    write_vector_row(vector_file, 0, last_state);
    size_t pcm_frame = 0;

    for (size_t cycle = 0; cycle < simulation_cycles; ++cycle) {
        top.rst_n = cycle >= kResetCycles;
        top.clk = 0;
        top.eval();

        const bool have_sample = top.rst_n && pcm_frame < decoded_frames;
        top.sample_valid = have_sample;
        if (have_sample) {
            const int32_t mixed =
                (static_cast<int32_t>(pcm[pcm_frame * 2]) +
                    pcm[pcm_frame * 2 + 1]) / 2;
            top.sample_data =
                static_cast<uint16_t>(static_cast<int16_t>(mixed)) ^ 0x8000u;
        }
        top.eval();
        const bool accepted = have_sample && top.sample_ready;

        top.clk = 1;
        top.eval();
        if (accepted)
            ++pcm_frame;

        const uint8_t state = output_state(top);
        if (state != last_state) {
            write_vector_row(vector_file, (cycle + 1) * kClockPeriodNs,
                state);
            last_state = state;
        }
    }

    top.final();
    vector_file.close();
    if (!vector_file) {
        std::cerr << "Failed writing XSPICE vector file: " << argv[2] << '\n';
        return 1;
    }

    std::cout << "Decoded " << decoded_frames << " PCM frames at "
              << sample_rate << " Hz; streamed " << pcm_frame
              << " frames through " << simulation_cycles
              << " DAC clocks (2 ms).\nWrote " << argv[2] << '\n';
    return 0;
}
