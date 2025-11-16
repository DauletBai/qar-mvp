package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

type asmLine struct {
	op   string
	args []string
	line int
	raw  string
	pc   uint32
}

type buildConfig struct {
	asmPath    string
	dataPath   string
	programOut string
	dataOut    string
	imemDepth  int
	dmemDepth  int
}

type sourceLine struct {
	text string
	file string
	line int
}

type asmParser struct {
	macros map[string]int32
}

func newAsmParser() *asmParser {
	return &asmParser{
		macros: map[string]int32{},
	}
}

var macroTable map[string]int32
var labelTable map[string]uint32

func (p *asmParser) loadFile(path string) ([]sourceLine, error) {
	var lines []sourceLine
	if err := p.expandFile(path, &lines); err != nil {
		return nil, err
	}
	return lines, nil
}

func (p *asmParser) expandFile(path string, out *[]sourceLine) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	dir := filepath.Dir(path)
	lineNum := 0
	for scanner.Scan() {
		lineNum++
		raw := scanner.Text()
		trimmed := strings.TrimSpace(stripComment(raw))
		if trimmed == "" {
			continue
		}
		lower := strings.ToLower(trimmed)
		switch {
		case strings.HasPrefix(lower, ".include"):
			start := strings.Index(trimmed, "\"")
			end := strings.LastIndex(trimmed, "\"")
			if start == -1 || end == start {
				return fmt.Errorf("%s:%d: malformed .include directive", path, lineNum)
			}
			includePath := trimmed[start+1 : end]
			if !filepath.IsAbs(includePath) {
				includePath = filepath.Join(dir, includePath)
			}
			if err := p.expandFile(includePath, out); err != nil {
				return err
			}
		case strings.HasPrefix(lower, ".equ"):
			payload := strings.TrimSpace(trimmed[len(".equ"):])
			payload = strings.ReplaceAll(payload, ",", " ")
			fields := strings.Fields(payload)
			if len(fields) < 2 {
				return fmt.Errorf("%s:%d: .equ expects name and value", path, lineNum)
			}
			val, err := p.evalMacroValue(fields[1])
			if err != nil {
				return fmt.Errorf("%s:%d: %v", path, lineNum, err)
			}
			p.macros[strings.ToUpper(fields[0])] = val
		default:
			*out = append(*out, sourceLine{text: raw, file: path, line: lineNum})
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return nil
}

func (p *asmParser) evalMacroValue(token string) (int32, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return 0, fmt.Errorf("empty macro value")
	}
	if val, ok := p.macros[strings.ToUpper(token)]; ok {
		return val, nil
	}
	v, err := strconv.ParseInt(token, 0, 64)
	if err != nil {
		return 0, err
	}
	const maxInt32 = 1<<31 - 1
	const minInt32 = -1 << 31
	if v > maxInt32 {
		v = v - (1 << 32)
	}
	if v < minInt32 || v > maxInt32 {
		return 0, fmt.Errorf("macro value %s out of range", token)
	}
	return int32(v), nil
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}

	cmd := os.Args[1]
	switch cmd {
	case "build":
		runBuild(os.Args[2:])
	case "run":
		runRun(os.Args[2:])
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, "Usage: qarsim <build|run> [options]\n")
	fmt.Fprintf(os.Stderr, "Use --asm <file> to point at the .qar assembly and --data <file> for the data initializer.\n")
	os.Exit(1)
}

func defaultBuildFlagSet(name string) (*flag.FlagSet, *buildConfig) {
	cfg := &buildConfig{}
	fs := flag.NewFlagSet(name, flag.ExitOnError)
	fs.StringVar(&cfg.asmPath, "asm", "", "Path to .qar assembly file")
	fs.StringVar(&cfg.dataPath, "data", "", "Path to data description file (optional)")
	fs.StringVar(&cfg.programOut, "program", "program.hex", "Output path for program hex")
	fs.StringVar(&cfg.dataOut, "data-out", "data.hex", "Output path for data hex")
	fs.IntVar(&cfg.imemDepth, "imem", 64, "Instruction memory depth (words)")
	fs.IntVar(&cfg.dmemDepth, "dmem", 64, "Data memory depth (words)")
	return fs, cfg
}

func runBuild(args []string) {
	fs, cfg := defaultBuildFlagSet("build")
	if err := fs.Parse(args); err != nil {
		exitErr(err)
	}
	if err := doBuild(cfg); err != nil {
		exitErr(err)
	}
}

func runRun(args []string) {
	fs, cfg := defaultBuildFlagSet("run")
	script := fs.String("script", "./scripts/run_core_exec.sh", "Simulation script to invoke after build")
	if err := fs.Parse(args); err != nil {
		exitErr(err)
	}
	if err := doBuild(cfg); err != nil {
		exitErr(err)
	}
	cmd := exec.Command(*script)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		exitErr(fmt.Errorf("simulation failed: %w", err))
	}
}

func doBuild(cfg *buildConfig) error {
	if cfg.asmPath == "" {
		return errors.New("--asm is required")
	}
	if cfg.imemDepth <= 0 {
		return errors.New("imem depth must be positive")
	}
	if cfg.dmemDepth <= 0 {
		return errors.New("dmem depth must be positive")
	}

	insts, labels, err := parseAssembly(cfg.asmPath)
	if err != nil {
		return err
	}
	labelTable = labels
	if len(insts) > cfg.imemDepth {
		return fmt.Errorf("program has %d instructions but imem depth is %d", len(insts), cfg.imemDepth)
	}

	words := make([]uint32, cfg.imemDepth)
	for i := range words {
		words[i] = 0x00000013 // NOP
	}
	for i, inst := range insts {
		encoded, err := encodeInstruction(inst, labels)
		if err != nil {
			return err
		}
		words[i] = encoded
	}
	if err := writeHexFile(cfg.programOut, words); err != nil {
		return err
	}

	dataWords := make([]uint32, cfg.dmemDepth)
	if cfg.dataPath != "" {
		vals, err := parseDataFile(cfg.dataPath)
		if err != nil {
			return err
		}
		if len(vals) > cfg.dmemDepth {
			return fmt.Errorf("data file contains %d words but dmem depth is %d", len(vals), cfg.dmemDepth)
		}
		copy(dataWords, vals)
	}
	if err := writeHexFile(cfg.dataOut, dataWords); err != nil {
		return err
	}

	fmt.Printf("Generated %s (%d words) and %s (%d words)\n", cfg.programOut, cfg.imemDepth, cfg.dataOut, cfg.dmemDepth)
	return nil
}

func exitErr(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

func parseAssembly(path string) ([]asmLine, map[string]uint32, error) {
	parser := newAsmParser()
	lines, err := parser.loadFile(path)
	if err != nil {
		return nil, nil, err
	}

	var insts []asmLine
	labels := map[string]uint32{}
	var pc uint32

	for _, src := range lines {
		line := stripComment(src.text)
		if strings.TrimSpace(line) == "" {
			continue
		}
		line = strings.TrimSpace(line)
		for {
			colon := strings.Index(line, ":")
			if colon == -1 {
				break
			}
			label := strings.TrimSpace(line[:colon])
			if label == "" {
				return nil, nil, fmt.Errorf("%s:%d: empty label", src.file, src.line)
			}
			if _, exists := labels[label]; exists {
				return nil, nil, fmt.Errorf("%s:%d: duplicate label %q", src.file, src.line, label)
			}
			labels[label] = pc
			line = strings.TrimSpace(line[colon+1:])
			if line == "" {
				break
			}
		}
		if line == "" {
			continue
		}
		fields := splitFields(line)
		if len(fields) == 0 {
			continue
		}
		op := strings.ToUpper(fields[0])
		args := parseArgs(strings.Join(fields[1:], " "))
		insts = append(insts, asmLine{op: op, args: args, line: src.line, raw: src.text, pc: pc})
		pc += 4
	}
	macroTable = parser.macros
	return insts, labels, nil
}

func encodeInstruction(inst asmLine, labels map[string]uint32) (uint32, error) {
	switch inst.op {
	case "NOP":
		return 0x00000013, nil
	case "ADDI":
		rd, rs1, imm, err := parseRRI(inst)
		if err != nil {
			return 0, err
		}
		word, err := encodeI(rd, rs1, imm, 0b000, 0x13)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "ADD", "SUB", "AND", "OR", "XOR", "SLL", "SRL":
		return encodeRType(inst)
	case "LUI":
		if len(inst.args) != 2 {
			return 0, fmt.Errorf("line %d: LUI expects rd, imm", inst.line)
		}
		rd, err := parseRegister(inst.args[0])
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		imm, err := parseImmediate(inst.args[1])
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		word, err := encodeUType(rd, imm, 0x37)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "AUIPC":
		if len(inst.args) != 2 {
			return 0, fmt.Errorf("line %d: AUIPC expects rd, imm", inst.line)
		}
		rd, err := parseRegister(inst.args[0])
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		imm, err := parseImmediate(inst.args[1])
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		word, err := encodeUType(rd, imm, 0x17)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "LW":
		rd, base, imm, err := parseLoadStoreArgs(inst)
		if err != nil {
			return 0, err
		}
		word, err := encodeI(rd, base, imm, 0b010, 0x03)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "SW":
		rs2, base, imm, err := parseLoadStoreArgs(inst)
		if err != nil {
			return 0, err
		}
		word, err := encodeSType(rs2, base, imm, 0b010)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU":
		return encodeBranch(inst, labels)
	case "JAL":
		return encodeJType(inst, labels)
	case "JALR":
		rd, rs1, imm, err := parseRRI(inst)
		if err != nil {
			return 0, err
		}
		word, err := encodeI(rd, rs1, imm, 0b000, 0x67)
		if err != nil {
			return 0, fmt.Errorf("line %d: %w", inst.line, err)
		}
		return word, nil
	case "CSRRW", "CSRRS", "CSRRC":
		rd, csr, rs1, err := parseCSRArgs(inst)
		if err != nil {
			return 0, err
		}
		var funct3 uint32
		switch inst.op {
		case "CSRRW":
			funct3 = 0b001
		case "CSRRS":
			funct3 = 0b010
		case "CSRRC":
			funct3 = 0b011
		}
		return encodeSystem(rd, rs1, csr, funct3)
	case "ECALL":
		if len(inst.args) != 0 {
			return 0, fmt.Errorf("line %d: ECALL takes no operands", inst.line)
		}
		return 0x00000073, nil
	case "MRET":
		if len(inst.args) != 0 {
			return 0, fmt.Errorf("line %d: MRET takes no operands", inst.line)
		}
		return 0x30200073, nil
	default:
		return 0, fmt.Errorf("line %d: unsupported opcode %s", inst.line, inst.op)
	}
}

func encodeRType(inst asmLine) (uint32, error) {
	if len(inst.args) != 3 {
		return 0, fmt.Errorf("line %d: %s expects 3 operands", inst.line, inst.op)
	}
	rd, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	rs1, err := parseRegister(inst.args[1])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	rs2, err := parseRegister(inst.args[2])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	var funct3, funct7 uint32
	switch inst.op {
	case "ADD":
		funct3, funct7 = 0b000, 0b0000000
	case "SUB":
		funct3, funct7 = 0b000, 0b0100000
	case "AND":
		funct3, funct7 = 0b111, 0b0000000
	case "OR":
		funct3, funct7 = 0b110, 0b0000000
	case "XOR":
		funct3, funct7 = 0b100, 0b0000000
	case "SLL":
		funct3, funct7 = 0b001, 0b0000000
	case "SRL":
		funct3, funct7 = 0b101, 0b0000000
	default:
		return 0, fmt.Errorf("line %d: unsupported R-type %s", inst.line, inst.op)
	}
	opcode := uint32(0x33)
	return (funct7 << 25) | (uint32(rs2) << 20) | (uint32(rs1) << 15) |
		(funct3 << 12) | (uint32(rd) << 7) | opcode, nil
}

func encodeUType(rd int, imm int32, opcode uint32) (uint32, error) {
	if imm < 0 || imm >= (1<<20) {
		return 0, fmt.Errorf("immediate %d out of range for U-type", imm)
	}
	return (uint32(imm) << 12) | (uint32(rd) << 7) | opcode, nil
}

func encodeBranch(inst asmLine, labels map[string]uint32) (uint32, error) {
	if len(inst.args) != 3 {
		return 0, fmt.Errorf("line %d: %s expects 3 operands", inst.line, inst.op)
	}
	rs1, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	rs2, err := parseRegister(inst.args[1])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	offset, err := resolveLabelOrImmediate(inst.args[2], inst.pc, labels)
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	funct3 := uint32(0)
	switch inst.op {
	case "BEQ":
		funct3 = 0b000
	case "BNE":
		funct3 = 0b001
	case "BLT":
		funct3 = 0b100
	case "BGE":
		funct3 = 0b101
	case "BLTU":
		funct3 = 0b110
	case "BGEU":
		funct3 = 0b111
	}
	word, err := encodeBType(rs1, rs2, offset, funct3)
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	return word, nil
}

func encodeJType(inst asmLine, labels map[string]uint32) (uint32, error) {
	if len(inst.args) != 2 {
		return 0, fmt.Errorf("line %d: JAL expects 2 operands", inst.line)
	}
	rd, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	offset, err := resolveLabelOrImmediate(inst.args[1], inst.pc, labels)
	if err != nil {
		return 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	if offset%2 != 0 {
		return 0, fmt.Errorf("line %d: jal target must be 2-byte aligned", inst.line)
	}
	if offset < -(1<<20) || offset > ((1<<20)-1) {
		return 0, fmt.Errorf("line %d: jal offset out of range", inst.line)
	}
	imm := uint32(offset) & 0x1FFFFF
	opcode := uint32(0x6F)
	bit20 := (imm >> 20) & 0x1
	bits10_1 := (imm >> 1) & 0x3FF
	bit11 := (imm >> 11) & 0x1
	bits19_12 := (imm >> 12) & 0xFF
	return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | (bits10_1 << 21) |
		(uint32(rd) << 7) | opcode, nil
}

func encodeSystem(rd, rs1 int, csr int32, funct3 uint32) (uint32, error) {
	if csr < 0 || csr > 0xFFF {
		return 0, fmt.Errorf("csr %d out of range", csr)
	}
	opcode := uint32(0x73)
	return (uint32(csr) << 20) | (uint32(rs1) << 15) | (funct3 << 12) | (uint32(rd) << 7) | opcode, nil
}

func encodeI(rd, rs1 int, imm int32, funct3 uint32, opcode uint32) (uint32, error) {
	if imm < -2048 || imm > 2047 {
		return 0, fmt.Errorf("immediate %d out of range for I-type", imm)
	}
	uimm := uint32(uint16(uint32(int32(imm) & 0xFFF)))
	return (uimm << 20) | (uint32(rs1) << 15) | (funct3 << 12) | (uint32(rd) << 7) | opcode, nil
}

func encodeSType(rs2, rs1 int, imm int32, funct3 uint32) (uint32, error) {
	if imm < -2048 || imm > 2047 {
		return 0, fmt.Errorf("immediate %d out of range for S-type", imm)
	}
	uimm := uint32(uint16(uint32(int32(imm) & 0xFFF)))
	immLo := uimm & 0x1F
	immHi := (uimm >> 5) & 0x7F
	opcode := uint32(0x23)
	return (immHi << 25) | (uint32(rs2) << 20) | (uint32(rs1) << 15) |
		(funct3 << 12) | (immLo << 7) | opcode, nil
}

func encodeBType(rs1, rs2 int, imm int32, funct3 uint32) (uint32, error) {
	if imm%2 != 0 {
		return 0, fmt.Errorf("branch offset must be 2-byte aligned (got %d)", imm)
	}
	if imm < -4096 || imm > 4094 {
		return 0, fmt.Errorf("branch offset %d out of range", imm)
	}
	uimm := uint32(int32(imm) & 0x1FFF)
	bit12 := (uimm >> 12) & 0x1
	bit11 := (uimm >> 11) & 0x1
	bits10_5 := (uimm >> 5) & 0x3F
	bits4_1 := (uimm >> 1) & 0xF
	opcode := uint32(0x63)
	return (bit12 << 31) | (bits10_5 << 25) | (uint32(rs2) << 20) |
		(uint32(rs1) << 15) | (funct3 << 12) | (bits4_1 << 8) | (bit11 << 7) | opcode, nil
}

func parseRRI(inst asmLine) (int, int, int32, error) {
	if len(inst.args) != 3 {
		return 0, 0, 0, fmt.Errorf("line %d: %s expects 3 operands", inst.line, inst.op)
	}
	rd, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	rs1, err := parseRegister(inst.args[1])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	imm, err := parseImmediate(inst.args[2])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	return rd, rs1, imm, nil
}

func parseCSRArgs(inst asmLine) (int, int32, int, error) {
	if len(inst.args) != 3 {
		return 0, 0, 0, fmt.Errorf("line %d: %s expects rd, csr, rs1", inst.line, inst.op)
	}
	rd, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	csr, err := parseCSR(inst.args[1])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	rs1, err := parseRegister(inst.args[2])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	return rd, csr, rs1, nil
}

func parseLoadStoreArgs(inst asmLine) (int, int, int32, error) {
	if len(inst.args) != 2 {
		return 0, 0, 0, fmt.Errorf("line %d: %s expects 2 operands", inst.line, inst.op)
	}
	reg1, err := parseRegister(inst.args[0])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	imm, base, err := parseOffsetArg(inst.args[1])
	if err != nil {
		return 0, 0, 0, fmt.Errorf("line %d: %w", inst.line, err)
	}
	return reg1, base, imm, nil
}

func parseOffsetArg(arg string) (int32, int, error) {
	arg = strings.TrimSpace(arg)
	if arg == "" {
		return 0, 0, errors.New("missing offset/base")
	}
	open := strings.Index(arg, "(")
	close := strings.Index(arg, ")")
	if open == -1 || close == -1 || close <= open {
		return 0, 0, fmt.Errorf("invalid offset syntax %q", arg)
	}
	immStr := strings.TrimSpace(arg[:open])
	baseStr := strings.TrimSpace(arg[open+1 : close])
	if immStr == "" {
		immStr = "0"
	}
	imm, err := parseImmediate(immStr)
	if err != nil {
		return 0, 0, err
	}
	base, err := parseRegister(baseStr)
	if err != nil {
		return 0, 0, err
	}
	return imm, base, nil
}

func resolveLabelOrImmediate(token string, pc uint32, labels map[string]uint32) (int32, error) {
	token = strings.TrimSpace(token)
	if val, err := parseImmediate(token); err == nil {
		return val, nil
	}
	addr, ok := labels[token]
	if !ok {
		return 0, fmt.Errorf("unknown label %s", token)
	}
	return int32(addr) - int32(pc), nil
}

func splitFields(line string) []string {
	return strings.Fields(line)
}

func parseArgs(argStr string) []string {
	if strings.TrimSpace(argStr) == "" {
		return nil
	}
	parts := strings.Split(argStr, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		trimmed := strings.TrimSpace(p)
		if trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func stripComment(line string) string {
	for _, sep := range []string{"#", "//"} {
		if idx := strings.Index(line, sep); idx != -1 {
			line = line[:idx]
		}
	}
	return line
}

func parseRegister(token string) (int, error) {
	token = strings.ToLower(strings.TrimSpace(token))
	if idx, ok := registerMap[token]; ok {
		return idx, nil
	}
	return 0, fmt.Errorf("unknown register %s", token)
}

func parseImmediate(token string) (int32, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return 0, errors.New("empty immediate")
	}
	if val, ok := lookupMacro(token); ok {
		return val, nil
	}
	if val, ok, err := parseLabelImmediate(token); ok {
		return val, err
	}
	val, err := strconv.ParseInt(token, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid immediate %s", token)
	}
	const maxInt32 = 1<<31 - 1
	const minInt32 = -1 << 31
	if val > maxInt32 {
		val = val - (1 << 32)
	}
	if val < minInt32 || val > maxInt32 {
		return 0, fmt.Errorf("immediate %s out of 32-bit range", token)
	}
	return int32(val), nil
}

func parseCSR(token string) (int32, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return 0, errors.New("empty CSR name")
	}
	upper := strings.ToUpper(token)
	if val, ok := lookupMacro(token); ok {
		return val, nil
	}
	if addr, ok := csrNameMap[upper]; ok {
		return int32(addr), nil
	}
	val, err := strconv.ParseInt(token, 0, 32)
	if err != nil {
		return 0, fmt.Errorf("unknown CSR %s", token)
	}
	if val < 0 || val > 0xFFF {
		return 0, fmt.Errorf("csr value %d out of range", val)
	}
	return int32(val), nil
}

func parseLabelImmediate(token string) (int32, bool, error) {
	if labelTable == nil {
		return 0, false, nil
	}
	token = strings.TrimSpace(token)
	if strings.HasPrefix(token, "%hi(") && strings.HasSuffix(token, ")") {
		name := strings.TrimSpace(token[4 : len(token)-1])
		addr, ok := labelTable[name]
		if !ok {
			return 0, true, fmt.Errorf("unknown label %s", name)
		}
		value := int32((addr + 0x800) >> 12)
		return value, true, nil
	}
	if strings.HasPrefix(token, "%lo(") && strings.HasSuffix(token, ")") {
		name := strings.TrimSpace(token[4 : len(token)-1])
		addr, ok := labelTable[name]
		if !ok {
			return 0, true, fmt.Errorf("unknown label %s", name)
		}
		lo := int32(addr & 0xFFF)
		if lo >= 0x800 {
			lo -= 0x1000
		}
		return lo, true, nil
	}
	return 0, false, nil
}

func lookupMacro(token string) (int32, bool) {
	if macroTable == nil {
		return 0, false
	}
	val, ok := macroTable[strings.ToUpper(token)]
	return val, ok
}

func parseDataFile(path string) ([]uint32, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var values []uint32
	reader := bufio.NewReader(file)
	for {
		line, err := reader.ReadString('\n')
		if err != nil && err != io.EOF {
			return nil, err
		}
		line = stripComment(line)
		fields := strings.Fields(line)
		for _, f := range fields {
			val, err := strconv.ParseInt(f, 0, 32)
			if err != nil {
				return nil, fmt.Errorf("invalid data value %s", f)
			}
			values = append(values, uint32(int32(val)))
		}
		if err == io.EOF {
			break
		}
	}
	return values, nil
}

func writeHexFile(path string, words []uint32) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil && !errors.Is(err, os.ErrExist) {
		return err
	}
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	for _, w := range words {
		if _, err := fmt.Fprintf(writer, "%08x\n", w); err != nil {
			return err
		}
	}
	return writer.Flush()
}

var csrNameMap = map[string]int{
	"MSTATUS":  0x300,
	"MIE":      0x304,
	"MTVEC":    0x305,
	"MSCRATCH": 0x340,
	"MEPC":     0x341,
	"MCAUSE":   0x342,
	"MIP":      0x344,
	"MTIME":    0x701,
	"MTIMECMP": 0x720,
	"IRQPRIO":  0xBC0,
	"IRQACK":   0xBC1,
}

var registerMap = map[string]int{
	"x0": 0, "zero": 0,
	"x1": 1, "ra": 1,
	"x2": 2, "sp": 2,
	"x3": 3, "gp": 3,
	"x4": 4, "tp": 4,
	"x5": 5, "t0": 5,
	"x6": 6, "t1": 6,
	"x7": 7, "t2": 7,
	"x8": 8, "s0": 8, "fp": 8,
	"x9": 9, "s1": 9,
	"x10": 10, "a0": 10,
	"x11": 11, "a1": 11,
	"x12": 12, "a2": 12,
	"x13": 13, "a3": 13,
	"x14": 14, "a4": 14,
	"x15": 15, "a5": 15,
	"x16": 16, "a6": 16,
	"x17": 17, "a7": 17,
	"x18": 18, "s2": 18,
	"x19": 19, "s3": 19,
	"x20": 20, "s4": 20,
	"x21": 21, "s5": 21,
	"x22": 22, "s6": 22,
	"x23": 23, "s7": 23,
	"x24": 24, "s8": 24,
	"x25": 25, "s9": 25,
	"x26": 26, "s10": 26,
	"x27": 27, "s11": 27,
	"x28": 28, "t3": 28,
	"x29": 29, "t4": 29,
	"x30": 30, "t5": 30,
	"x31": 31, "t6": 31,
}
