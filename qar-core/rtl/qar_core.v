// =============================================
// QAR-Core v0.2 - Minimal Core
// - RV32I subset: ADDI, ADD, SUB, logic ops, shifts
// - Adds LW/SW data path, BEQ branching, data RAM
// - Instruction/data memories initialized from hex files
// =============================================
`default_nettype none

module qar_core (
    input  wire        clk,
    input  wire        rst_n,

    // Simple memory interface (mirrors internal data RAM activity)
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_we,
    input  wire [31:0] mem_rdata
);

    localparam IMEM_DEPTH       = 64;
    localparam IMEM_ADDR_WIDTH  = 6;
    localparam IMEM_ADDR_MSB    = IMEM_ADDR_WIDTH + 1;
    localparam DMEM_DEPTH       = 256;
    localparam DMEM_ADDR_WIDTH  = 8;
    localparam DMEM_ADDR_MSB    = DMEM_ADDR_WIDTH + 1;
    localparam DMEM_INIT_LAST   = 63;

    // Program Counter
    reg [31:0] pc;
    reg [31:0] pc_next;

    // Instruction/data memories
    reg [31:0] imem [0:IMEM_DEPTH-1];
    reg [31:0] dmem [0:DMEM_DEPTH-1];
    wire [31:0] instr;

    // Decode fields
    wire [6:0]  opcode  = instr[6:0];
    wire [4:0]  rd      = instr[11:7];
    wire [2:0]  funct3  = instr[14:12];
    wire [4:0]  rs1     = instr[19:15];
    wire [4:0]  rs2     = instr[24:20];
    wire [6:0]  funct7  = instr[31:25];
    wire [31:0] imm_i   = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s   = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b   = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    // Register file interface
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;
    reg  [4:0]  rf_raddr1;
    reg  [4:0]  rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] load_addr_calc;
    wire [31:0] store_addr_calc;

    // ALU interface
    reg  [31:0] alu_op_a;
    reg  [31:0] alu_op_b;
    reg  [3:0]  alu_op_sel;
    wire [31:0] alu_result;

    // Data memory control
    reg                        data_we;
    reg  [DMEM_ADDR_WIDTH-1:0] data_addr;
    reg  [31:0]                data_wdata;
    wire [31:0]                data_rdata;

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
    localparam OPCODE_OP     = 7'b0110011; // R-type
    localparam OPCODE_LOAD   = 7'b0000011; // LW
    localparam OPCODE_STORE  = 7'b0100011; // SW
    localparam OPCODE_BRANCH = 7'b1100011; // BEQ

    assign data_rdata = dmem[data_addr];
    assign instr = imem[pc[IMEM_ADDR_MSB:2]];
    assign load_addr_calc  = rf_rdata1 + imm_i;
    assign store_addr_calc = rf_rdata1 + imm_s;

    // Mirror internal RAM interactions on external interface (for future expansion)
    assign mem_addr  = { {(32-(DMEM_ADDR_WIDTH+2)){1'b0}}, data_addr, 2'b00 };
    assign mem_wdata = data_wdata;
    assign mem_we    = data_we;
    wire [31:0] mem_rdata_unused;
    assign mem_rdata_unused = mem_rdata;

    // Instruction/data memory initialization
    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < IMEM_DEPTH; init_idx = init_idx + 1)
            imem[init_idx] = 32'b0;
        for (init_idx = 0; init_idx < DMEM_DEPTH; init_idx = init_idx + 1)
            dmem[init_idx] = 32'b0;

        $display("QAR-Core: loading program from program.hex ...");
        $readmemh("program.hex", imem);

        $display("QAR-Core: loading data memory from data.hex ...");
        $readmemh("data.hex", dmem, 0, DMEM_INIT_LAST);
    end

    // Register file instance
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

    // Data memory write path
    always @(posedge clk) begin
        if (data_we)
            dmem[data_addr] <= data_wdata;
    end

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
        alu_op_sel = ALU_ADD;
        pc_next    = pc + 4;
        data_we    = 1'b0;
        data_addr  = {DMEM_ADDR_WIDTH{1'b0}};
        data_wdata = 32'b0;

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
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            // ADD
                            alu_op_sel = ALU_ADD;
                            rf_we      = 1'b1;
                            rf_waddr   = rd;
                            rf_wdata   = alu_result;
                        end else if (funct7 == 7'b0100000) begin
                            // SUB
                            alu_op_sel = ALU_SUB;
                            rf_we      = 1'b1;
                            rf_waddr   = rd;
                            rf_wdata   = alu_result;
                        end
                    end
                    3'b111: begin
                        // AND
                        alu_op_sel = ALU_AND;
                        rf_we      = 1'b1;
                        rf_waddr   = rd;
                        rf_wdata   = alu_result;
                    end
                    3'b110: begin
                        // OR
                        alu_op_sel = ALU_OR;
                        rf_we      = 1'b1;
                        rf_waddr   = rd;
                        rf_wdata   = alu_result;
                    end
                    3'b100: begin
                        // XOR
                        alu_op_sel = ALU_XOR;
                        rf_we      = 1'b1;
                        rf_waddr   = rd;
                        rf_wdata   = alu_result;
                    end
                    3'b001: begin
                        // SLL
                        alu_op_sel = ALU_SLL;
                        rf_we      = 1'b1;
                        rf_waddr   = rd;
                        rf_wdata   = alu_result;
                    end
                    3'b101: begin
                        // SRL
                        if (funct7 == 7'b0000000) begin
                            alu_op_sel = ALU_SRL;
                            rf_we      = 1'b1;
                            rf_waddr   = rd;
                            rf_wdata   = alu_result;
                        end
                    end
                    default: begin
                        rf_we = 1'b0;
                    end
                endcase
            end

            OPCODE_LOAD: begin
                if (funct3 == 3'b010) begin
                    data_addr = load_addr_calc[DMEM_ADDR_MSB:2];
                    rf_we     = 1'b1;
                    rf_waddr  = rd;
                    rf_wdata  = data_rdata;
                end
            end

            OPCODE_STORE: begin
                if (funct3 == 3'b010) begin
                    data_addr = store_addr_calc[DMEM_ADDR_MSB:2];
                    data_we   = 1'b1;
                    data_wdata= rf_rdata2;
                end
            end

            OPCODE_BRANCH: begin
                if (funct3 == 3'b000) begin
                    if (rf_rdata1 == rf_rdata2)
                        pc_next = pc + imm_b;
                end
            end

            default: begin
                rf_we = 1'b0;
            end
        endcase
    end

    // Sequential: PC update and instruction fetch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

endmodule

`default_nettype wire
