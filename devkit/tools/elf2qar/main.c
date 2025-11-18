#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <arpa/inet.h>

/* Minimal ELF32 definitions */
#define EI_NIDENT 16

typedef struct {
    unsigned char e_ident[EI_NIDENT];
    uint16_t e_type;
    uint16_t e_machine;
    uint32_t e_version;
    uint32_t e_entry;
    uint32_t e_phoff;
    uint32_t e_shoff;
    uint32_t e_flags;
    uint16_t e_ehsize;
    uint16_t e_phentsize;
    uint16_t e_phnum;
    uint16_t e_shentsize;
    uint16_t e_shnum;
    uint16_t e_shstrndx;
} Elf32_Ehdr;

typedef struct {
    uint32_t p_type;
    uint32_t p_offset;
    uint32_t p_vaddr;
    uint32_t p_paddr;
    uint32_t p_filesz;
    uint32_t p_memsz;
    uint32_t p_flags;
    uint32_t p_align;
} Elf32_Phdr;

#define PT_LOAD 1
#define EM_RISCV 243

typedef struct {
    uint32_t base_addr;
    uint32_t size_words;
    uint32_t addr_mask;
    uint8_t *buffer;
} image_t;

static void usage(const char *prog) {
    fprintf(stderr,
            "Usage: %s --elf <input.elf> --program program.hex --data data.hex "
            "[--imem 64] [--dmem 64]\n",
            prog);
    exit(1);
}

static void image_init(image_t *img, uint32_t base, uint32_t size_words) {
    img->base_addr = base;
    img->size_words = size_words;
    img->addr_mask = (size_words * 4) - 1;
    img->buffer = (uint8_t *)calloc(size_words, 4);
    if (!img->buffer) {
        fprintf(stderr, "elf2qar: out of memory\n");
        exit(1);
    }
}

static void image_store(image_t *img, uint32_t addr, const uint8_t *data, uint32_t len) {
    if (addr < img->base_addr || addr + len > img->base_addr + img->size_words * 4) {
        return;
    }
    uint32_t offset = addr - img->base_addr;
    memcpy(img->buffer + offset, data, len);
}

static void image_write_hex(const image_t *img, const char *path) {
    FILE *out = fopen(path, "w");
    if (!out) {
        fprintf(stderr, "elf2qar: failed to open %s: %s\n", path, strerror(errno));
        exit(1);
    }
    for (uint32_t word = 0; word < img->size_words; ++word) {
        uint32_t offset = word * 4;
        uint32_t value = img->buffer[offset] |
                         (img->buffer[offset + 1] << 8) |
                         (img->buffer[offset + 2] << 16) |
                         (img->buffer[offset + 3] << 24);
        fprintf(out, "%08x\n", value);
    }
    fclose(out);
}

int main(int argc, char **argv) {
    const char *elf_path = NULL;
    const char *program_hex = "program.hex";
    const char *data_hex = "data.hex";
    uint32_t imem_words = 64;
    uint32_t dmem_words = 64;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--elf") == 0) {
            if (++i >= argc) usage(argv[0]);
            elf_path = argv[i];
        } else if (strcmp(argv[i], "--program") == 0) {
            if (++i >= argc) usage(argv[0]);
            program_hex = argv[i];
        } else if (strcmp(argv[i], "--data") == 0) {
            if (++i >= argc) usage(argv[0]);
            data_hex = argv[i];
        } else if (strcmp(argv[i], "--imem") == 0) {
            if (++i >= argc) usage(argv[0]);
            imem_words = (uint32_t)strtoul(argv[i], NULL, 0);
        } else if (strcmp(argv[i], "--dmem") == 0) {
            if (++i >= argc) usage(argv[0]);
            dmem_words = (uint32_t)strtoul(argv[i], NULL, 0);
        } else {
            usage(argv[0]);
        }
    }

    if (!elf_path) {
        usage(argv[0]);
    }

    FILE *elf = fopen(elf_path, "rb");
    if (!elf) {
        fprintf(stderr, "elf2qar: failed to open %s: %s\n", elf_path, strerror(errno));
        return 1;
    }

    Elf32_Ehdr ehdr;
    if (fread(&ehdr, sizeof(ehdr), 1, elf) != 1) {
        fprintf(stderr, "elf2qar: failed to read ELF header\n");
        fclose(elf);
        return 1;
    }
    if (ehdr.e_ident[0] != 0x7f || ehdr.e_ident[1] != 'E' ||
        ehdr.e_ident[2] != 'L' || ehdr.e_ident[3] != 'F') {
        fprintf(stderr, "elf2qar: not an ELF file\n");
        fclose(elf);
        return 1;
    }
    if (ehdr.e_machine != EM_RISCV) {
        fprintf(stderr, "elf2qar: unsupported machine %u\n", ehdr.e_machine);
        fclose(elf);
        return 1;
    }

    image_t imem, dmem;
    image_init(&imem, 0x00000000u, imem_words);
    image_init(&dmem, 0x00000000u, dmem_words);

    if (fseek(elf, ehdr.e_phoff, SEEK_SET) != 0) {
        fprintf(stderr, "elf2qar: failed to seek program headers\n");
        fclose(elf);
        return 1;
    }

    for (uint16_t i = 0; i < ehdr.e_phnum; ++i) {
        Elf32_Phdr phdr;
        if (fread(&phdr, sizeof(phdr), 1, elf) != 1) {
            fprintf(stderr, "elf2qar: failed to read program header %u\n", i);
            fclose(elf);
            return 1;
        }
        if (phdr.p_type != PT_LOAD || phdr.p_filesz == 0) {
            continue;
        }
        uint8_t *segment = (uint8_t *)malloc(phdr.p_filesz);
        if (!segment) {
            fprintf(stderr, "elf2qar: out of memory\n");
            fclose(elf);
            return 1;
        }
        long curr = ftell(elf);
        if (fseek(elf, phdr.p_offset, SEEK_SET) != 0) {
            fprintf(stderr, "elf2qar: failed to seek to segment data\n");
            free(segment);
            fclose(elf);
            return 1;
        }
        if (fread(segment, 1, phdr.p_filesz, elf) != phdr.p_filesz) {
            fprintf(stderr, "elf2qar: failed to read segment data\n");
            free(segment);
            fclose(elf);
            return 1;
        }
        fseek(elf, curr, SEEK_SET);

        if (phdr.p_vaddr < 0x20000000u) {
            image_store(&imem, phdr.p_vaddr, segment, phdr.p_filesz);
        } else {
            image_store(&dmem, phdr.p_vaddr - 0x20000000u, segment, phdr.p_filesz);
        }
        free(segment);
    }

    fclose(elf);

    image_write_hex(&imem, program_hex);
    image_write_hex(&dmem, data_hex);

    free(imem.buffer);
    free(dmem.buffer);

    return 0;
}
