CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra
LDFLAGS ?=

all: elf2qar

elf2qar: main.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

main.o: main.c

clean:
	rm -f elf2qar main.o

.PHONY: all clean
