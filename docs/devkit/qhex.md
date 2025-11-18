# `qhex`: Hex Utility (C Tool)

To demonstrate native C tooling in the QAR DevKit, the repository now ships with `qhex`, a small command-line helper that parses our `program.hex`/`data.hex` files, reports basic statistics, and can emit a raw little-endian binary blob suitable for FPGA loaders or ROM initialisers.

## Building

`qhex` is written in portable C11 and only depends on a POSIX toolchain (Clang, GCC, etc.). Build it once with:

```sh
cd devkit/tools/qhex
make          # produces the qhex binary
```

You can override the compiler by exporting `CC=<your-cc>`.

## Usage

```
./qhex [--bin output.bin] <hex-file>
```

Examples:

```sh
# Print stats for the default firmware
./qhex ../../../program.hex

# Convert a freshly built program into raw binary
./qhex --bin qar_core.bin ../../../program.hex
```

This utility is intentionally simple, but it proves out the "fourth" language in our open-source toolchain (Verilog + Icarus + Go + C). We will extend it—or add more C-based helpers—as the DevKit grows.
