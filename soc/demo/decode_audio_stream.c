#include <stdio.h>
#include <string.h>

#include <generated/csr.h>

#include "decode_audio_stream.h"
#include "helix_mp3.h"

#define AUDIO_STREAM_BASE 0x01400000u
#define AUDIO_STREAM_END  0x02000000u

typedef struct {
    const uint8_t *data;
    size_t size;
    size_t offset;
} audio_stream_t;

static int audio_stream_seek(void *user_data, int offset)
{
    audio_stream_t *stream = user_data;

    if (offset < 0 || (size_t)offset > stream->size)
        return -1;

    stream->offset = (size_t)offset;
    return 0;
}

static size_t audio_stream_read(void *user_data, void *buffer, size_t size)
{
    audio_stream_t *stream = user_data;
    size_t bytes_to_read = stream->size - stream->offset;

    if (bytes_to_read > size)
        bytes_to_read = size;
    memcpy(buffer, stream->data + stream->offset, bytes_to_read);
    stream->offset += bytes_to_read;
    return bytes_to_read;
}

void decode_audio_stream(void)
{
    helix_mp3_t mp3;
    audio_stream_t stream = {
        .data = (const uint8_t *)AUDIO_STREAM_BASE,
        .size = AUDIO_STREAM_END - AUDIO_STREAM_BASE,
        .offset = 0
    };
    helix_mp3_io_t io = {
        .seek = audio_stream_seek,
        .read = audio_stream_read,
        .user_data = &stream
    };
    int16_t pcm_buffer[HELIX_MP3_MAX_SAMPLES_PER_FRAME];

    dac_test_mode_write(0);
    printf("Looping MP3 playback to DAC\n");

    while (1) {
        int err = helix_mp3_init(&mp3, &io);
        if (err != 0) {
            printf("Failed to initialize Helix decoder: %d\n", err);
            return;
        }

        else {
            printf("Helix decoder initialized\n");
        }

        size_t frames_decoded;
        while ((frames_decoded = helix_mp3_read_pcm_frames_s16(
            &mp3, pcm_buffer, HELIX_MP3_MAX_SAMPLES_PER_FRAME / 2)) > 0) {
            for (size_t frame = 0; frame < frames_decoded; frame++) {
                int32_t mono_sample = ((int32_t)pcm_buffer[2 * frame] +
                    pcm_buffer[2 * frame + 1]) / 2;
                uint16_t dac_sample = (uint16_t)(int16_t)mono_sample ^ 0x8000;

                while (!dac_sample_ready_read()) {
                }
                dac_sample_data_write(dac_sample);
            }
        }

        helix_mp3_deinit(&mp3);
        stream.offset = 0;
        printf("finshed decoding audio stream.\n");
        break;
    }
}
