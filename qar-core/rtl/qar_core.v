// =============================================
// QAR-Core v0.1 - Minimal Core
// - RV32I subset: ADDI, ADD
// - Single-cycle style execution
// - Simple instruction memory (imem)
// =============================================

module qar_core (
    input  wire        clk,
    input  wire        rst_n,

    // Memory interface (not used yet in MVP)
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_we,
    input  wire [31:0] mem_rdata
);

    // Program Counter
    reg [31:0] pc;

    // Simple instruction memory (8 words)
    reg [31:0] imem [0:7];
    reg [31:0] instr;

    // Decode fields
    wire [6:0]  opcode  = instr[6:0];
    wire [4:0]  rd      = instr[11:7];
    wire [2:0]  funct3  = instr[14:12];
    wire [4:0]  rs1     = instr[19:15];
    wire [4:0]  rs2     = instr[24:20];
    wire [6:0]  funct7  = instr[31:25];
    wire [31:0] imm_i   = {{20{instr[31]}}, instr[31:20]};

    // Register file interface
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;
    reg  [4:0]  rf_raddr1;
    reg  [4:0]  rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

    // ALU interface
    reg  [31:0] alu_op_a;
    reg  [31:0] alu_op_b;
    reg  [3:0]  alu_op_sel;
    wire [31:0] alu_result;

    // ALU operation encodings (must match alu.v)
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;

    // Opcodes
    localparam OPCODE_OP_IMM = 7'b0010011; // ADDI
    localparam OPCODE_OP     = 7'b0110011; // ADD

    // Instruction memory initialization
    // Program:
    //   ADDI x1, x0, 5
    //   ADDI x2, x0, 3
    //   ADD  x3, x1, x2
    initial begin
        // These encodings are standard RV32I:
        // ADDI x1,x0,5  = 0x00500093
        // ADDI x2,x0,3  = 0x00300113
        // ADD  x3,x1,x2 = 0x002081b3
        imem[0] = 32'h00500093;
        imem[1] = 32'h00300113;
        imem[2] = 32'h002081b3;
        imem[3] = 32'h00000013; // NOP (ADDI x0, x0, 0)
        imem[4] = 32'h00000013;
        imem[5] = 32'h00000013;
        imem[6] = 32'h00000013;
        imem[7] = 32'h00000013;
    end

    // Register file instance (named for debug in testbench)
    regfile rf_inst (
        .clk   (clk),
        .we    (rf_we),
        .waddr (rf_waddr),
        .wdata (rf_wdata),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2)
    );

    // ALU instance
    alu alu_inst (
        .op_a  (alu_op_a),
        .op_b  (alu_op_b),
        .alu_op(alu_op_sel),
        .result(alu_result)
    );

    // For now, external memory interface is unused
    assign mem_addr  = 32'b0;
    assign mem_wdata = 32'b0;
    assign mem_we    = 1'b0;

    // Combinational decode and execute preparation
    always @(*) begin
        // Default values
        rf_we      = 1'b0;
        rf_waddr   = 5'd0;
        rf_wdata   = 32'b0;
        rf_raddr1  = rs1;
        rf_raddr2  = rs2;
        alu_op_a   = rf_rdata1;
        alu_op_b   = rf_rdata2;
        alu_op_sel = ALU_ADD; // default

        case (opcode)
            OPCODE_OP_IMM: begin
                // ADDI
                if (funct3 == 3'b000) begin
                    alu_op_a   = rf_rdata1;
                    alu_op_b   = imm_i;
                    alu_op_sel = ALU_ADD;
                    rf_we      = 1'b1;
                    rf_waddr   = rd;
                    rf_wdata   = alu_result;
                end
            end

            OPCODE_OP: begin
                // R-type instructions
                if (funct3 == 3'b000 && funct7 == 7'b0000000) begin
                    // ADD
                    alu_op_a   = rf_rdata1;
                    alu_op_b   = rf_rdata2;
                    alu_op_sel = ALU_ADD;
                    rf_we      = 1'b1;
                    rf_waddr   = rd;
                    rf_wdata   = alu_result;
                end
            end

            default: begin
                // NOP or unsupported instruction
                rf_we = 1'b0;
            end
        endcase
    end

    // Sequential: PC update and instruction fetch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc    <= 32'b0;
            instr <= 32'b0;
        end else begin
            instr <= imem[pc[4:2]]; // word-aligned, 8 entries
            pc    <= pc + 4;
        end
    end

endmodule
