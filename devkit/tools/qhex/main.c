#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    uint32_t *words;
    size_t count;
    size_t capacity;
} word_buffer;

static void usage(const char *prog) {
    fprintf(stderr,
            "Usage: %s [--bin output.bin] <hex-file>\n"
            "Reads a QAR hex file (32-bit words) and prints statistics. "
            "Optionally emits a raw little-endian binary image for FPGA loaders.\n",
            prog);
}

static int append_word(word_buffer *buf, uint32_t value) {
    if (buf->count == buf->capacity) {
        size_t new_cap = buf->capacity ? buf->capacity * 2 : 64;
        uint32_t *new_words = realloc(buf->words, new_cap * sizeof(uint32_t));
        if (!new_words) {
            return -1;
        }
        buf->words = new_words;
        buf->capacity = new_cap;
    }
    buf->words[buf->count++] = value;
    return 0;
}

static int write_binary(const char *path, const word_buffer *buf) {
    FILE *out = fopen(path, "wb");
    if (!out) {
        fprintf(stderr, "qhex: failed to open %s for writing: %s\n",
                path, strerror(errno));
        return -1;
    }
    for (size_t i = 0; i < buf->count; ++i) {
        uint32_t w = buf->words[i];
        uint8_t bytes[4] = {
            (uint8_t)(w & 0xFF),
            (uint8_t)((w >> 8) & 0xFF),
            (uint8_t)((w >> 16) & 0xFF),
            (uint8_t)((w >> 24) & 0xFF),
        };
        if (fwrite(bytes, 1, sizeof(bytes), out) != sizeof(bytes)) {
            fprintf(stderr, "qhex: failed to write %s: %s\n",
                    path, strerror(errno));
            fclose(out);
            return -1;
        }
    }
    fclose(out);
    return 0;
}

int main(int argc, char **argv) {
    const char *bin_out = NULL;
    const char *hex_path = NULL;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--bin") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "qhex: --bin requires a path\n");
                usage(argv[0]);
                return 1;
            }
            bin_out = argv[++i];
            continue;
        }
        if (hex_path) {
            fprintf(stderr, "qhex: multiple input files specified\n");
            usage(argv[0]);
            return 1;
        }
        hex_path = argv[i];
    }

    if (!hex_path) {
        usage(argv[0]);
        return 1;
    }

    FILE *in = fopen(hex_path, "r");
    if (!in) {
        fprintf(stderr, "qhex: failed to open %s: %s\n", hex_path, strerror(errno));
        return 1;
    }

    char line[256];
    word_buffer buf = {0};
    size_t nonzero = 0;
    size_t line_num = 0;
    while (fgets(line, sizeof(line), in)) {
        line_num++;
        char *hash = strchr(line, '#');
        if (hash) {
            *hash = '\0';
        }
        char *trim = line;
        while (*trim == ' ' || *trim == '\t')
            trim++;
        if (*trim == '\0' || *trim == '\n')
            continue;
        uint32_t value = 0;
        if (sscanf(trim, "%x", &value) != 1) {
            fprintf(stderr, "qhex: %s:%zu: invalid word '%s'\n", hex_path, line_num, trim);
            fclose(in);
            free(buf.words);
            return 1;
        }
        if (append_word(&buf, value) != 0) {
            fprintf(stderr, "qhex: out of memory\n");
            fclose(in);
            free(buf.words);
            return 1;
        }
        if (value != 0)
            nonzero++;
    }
    fclose(in);

    printf("qhex: %s contains %zu words (0x%zx), %zu non-zero\n",
           hex_path, buf.count, buf.count, nonzero);
    if (buf.count > 0) {
        printf("qhex: word[0] = 0x%08x, word[last] = 0x%08x\n",
               buf.words[0], buf.words[buf.count - 1]);
    }

    if (bin_out) {
        if (write_binary(bin_out, &buf) != 0) {
            free(buf.words);
            return 1;
        }
        printf("qhex: wrote %s (%zu bytes)\n", bin_out, buf.count * sizeof(uint32_t));
    }

    free(buf.words);
    return 0;
}
