CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra
LDFLAGS ?=

all: qhex

qhex: main.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

main.o: main.c

clean:
	rm -f qhex main.o

.PHONY: all clean
