#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include "Vaudio_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Audio Downsampling Configurations
#define CLK_FREQ_HZ     50000000  // 50 MHz
#define SAMPLE_RATE_HZ  44100     // Target Output PCM Audio rate
#define CYCLES_PER_SAMPLE (CLK_FREQ_HZ / SAMPLE_RATE_HZ)

// Simple structure to write standard RIFF WAV headers
void write_wav_header(std::ofstream &f, uint32_t num_samples) {
    uint32_t sub_chunk_2_size = num_samples * 2; // 16-bit mono = 2 bytes/sample
    uint32_t chunk_size = 36 + sub_chunk_2_size;
    
    f.write("RIFF", 4);
    f.write(reinterpret_cast<char*>(&chunk_size), 4);
    f.write("WAVEfmt ", 8);
    
    uint32_t sub_chunk_1_size = 16;
    uint16_t audio_format = 1; // PCM
    uint16_t num_channels = 1; // Mono
    uint32_t sample_rate = SAMPLE_RATE_HZ;
    uint32_t byte_rate = SAMPLE_RATE_HZ * 2;
    uint16_t block_align = 2;
    uint16_t bits_per_sample = 16;
    
    f.write(reinterpret_cast<char*>(&sub_chunk_1_size), 4);
    f.write(reinterpret_cast<char*>(&audio_format), 2);
    f.write(reinterpret_cast<char*>(&num_channels), 2);
    f.write(reinterpret_cast<char*>(&sample_rate), 4);
    f.write(reinterpret_cast<char*>(&byte_rate), 4);
    f.write(reinterpret_cast<char*>(&block_align), 2);
    f.write(reinterpret_cast<char*>(&bits_per_sample), 2);
    f.write("data", 4);
    f.write(reinterpret_cast<char*>(&sub_chunk_2_size), 4);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // 1. Enable tracing globally before instantiating the model
    Verilated::traceEverOn(true);

    Vaudio_top* top = new Vaudio_top;

    // 2. Initialize the VCD trace object and open output file
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99); // Trace 99 levels of hierarchy
    tfp->open("waveform.vcd");

    // Open an input MP3 file to stream into the core
    std::ifstream mp3_file("input.mp3", std::ios::binary);
    if (!mp3_file) {
        std::cerr << "Error: Could not open input.mp3" << std::endl;
        tfp->close();
        delete tfp;
        delete top;
        return -1;
    }
    std::vector<uint8_t> mp3_buffer((std::istreambuf_iterator<char>(mp3_file)), std::istreambuf_iterator<char>());
    size_t mp3_ptr = 0;

    // Open output WAV file to log reconstructed Delta-Sigma DAC output
    std::ofstream wav_file("output_dac.wav", std::ios::binary);
    write_wav_header(wav_file, 0); // Temporary header, fix at end

    // Simulation Tracking Variables
    uint64_t main_time = 0;
    uint32_t sample_accumulator = 0;
    uint32_t cycle_count = 0;
    uint32_t total_saved_samples = 0;

    // Reset Sequence
    top->rst = 1;
    top->clk = 0;
    for (int i = 0; i < 10; i++) {
        top->clk = !top->clk;
        top->eval();
        tfp->dump(main_time); // Dump reset transitions
        main_time++;
    }
    top->rst = 0;

    std::cout << "Starting Simulation. Streaming MP3 data into hardware..." << std::endl;

    // Simulation Loop
    while (!Verilated::gotFinish() && mp3_ptr < mp3_buffer.size()) {
        // Falling edge logic
        top->clk = 0;
        top->eval();
        tfp->dump(main_time); // Dump falling edge state
        main_time++;

        // Handle input AXI-Stream/FIFO handshake with Helix Wrapper
        if (top->mp3_ready && (mp3_ptr < mp3_buffer.size())) {
            top->mp3_data = mp3_buffer[mp3_ptr];
            top->mp3_valid = 1;
        } else {
            top->mp3_valid = 0;
        }

        // Rising edge logic
        top->clk = 1;
        top->eval();
        tfp->dump(main_time); // Dump rising edge state
        main_time++;

        // Advance pointers if a byte transfer happened
        if (top->mp3_ready && top->mp3_valid) {
            mp3_ptr++;
        }

        // --- Delta Sigma Reconstruction Filter ---
        // Accumulate 1-bit pulses over the downsampling window
        sample_accumulator += top->dac_out;
        cycle_count++;

        if (cycle_count >= CYCLES_PER_SAMPLE) {
            // Map the pulse count average to a signed 16-bit integer range
            // (sample_accumulator / CYCLES_PER_SAMPLE) scales 0.0 to 1.0
            double normalized = (double)sample_accumulator / CYCLES_PER_SAMPLE;
            int16_t pcm_sample = static_cast<int16_t>((normalized * 65535.0) - 32768.0);
            
            wav_file.write(reinterpret_cast<char*>(&pcm_sample), sizeof(pcm_sample));
            total_saved_samples++;

            // Reset box-car averages
            sample_accumulator = 0;
            cycle_count = 0;
        }
    }

    // Go back and update the correct WAV file sizes in the header
    wav_file.seekp(0, std::ios::beg);
    write_wav_header(wav_file, total_saved_samples);

    // 3. Close and clean up the VCD trace file
    tfp->close();
    delete tfp;

    wav_file.close();
    delete top;
    std::cout << "Simulation completed. Audio saved to output_dac.wav and VCD saved to waveform.vcd" << std::endl;
    return 0;
}

