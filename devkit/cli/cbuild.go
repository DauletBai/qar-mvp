package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func buildFromC(cfg *buildConfig) error {
	tempDir, err := os.MkdirTemp("", "qar-cbuild")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tempDir)

	elfPath := filepath.Join(tempDir, "firmware.elf")

	cc := cfg.cCompiler
	if cc == "" {
		cc = os.Getenv("QAR_CC")
	}
	if cc == "" {
		cc = "riscv32-unknown-elf-gcc"
	}
	extraFlags := []string{}
	ldFlags := []string{}
	if envFlags := os.Getenv("QAR_CFLAGS"); envFlags != "" {
		extraFlags = append(extraFlags, strings.Fields(envFlags)...)
	}
	if cfg.cFlags != "" {
		extraFlags = append(extraFlags, strings.Fields(cfg.cFlags)...)
	}
	if envLd := os.Getenv("QAR_LDFLAGS"); envLd != "" {
		ldFlags = append(ldFlags, strings.Fields(envLd)...)
	}
	if cfg.ldFlags != "" {
		ldFlags = append(ldFlags, strings.Fields(cfg.ldFlags)...)
	}
	if len(cfg.cPaths) > 0 {
		fmt.Printf("Compiling %d C source(s): %s\n", len(cfg.cPaths), strings.Join(cfg.cPaths, ", "))
	}
	args := []string{
		"-Os",
		"-nostdlib",
		"-nostartfiles",
		"-march=rv32i",
		"-mabi=ilp32",
		"-T", "devkit/cli/linker.ld",
		"devkit/sdk/crt0.S",
		"devkit/sdk/runtime.c",
		"devkit/sdk/hal_init.c",
		"-I", "devkit",
		"-o", elfPath,
	}

	args = append(args, cfg.cPaths...)
	args = append(args, extraFlags...)
	args = append(args, ldFlags...)
	cmd := exec.Command(cc, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("C compilation failed: %w (command: %s %s)", err, cc, strings.Join(args, " "))
	}

	elf2qar := filepath.Join("devkit", "tools", "elf2qar", "elf2qar")
	if _, err := os.Stat(elf2qar); err != nil {
		return fmt.Errorf("elf2qar not found (%s). Build it via make in devkit/tools/elf2qar", elf2qar)
	}

	elfArgs := []string{
		"--elf", elfPath,
		"--program", cfg.programOut,
		"--data", cfg.dataOut,
		fmt.Sprintf("--imem=%d", cfg.imemDepth),
		fmt.Sprintf("--dmem=%d", cfg.dmemDepth),
	}
	cmd = exec.Command(elf2qar, elfArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("elf2qar failed: %w", err)
	}

	return nil
}
