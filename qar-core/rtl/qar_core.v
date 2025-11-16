// =============================================
// QAR-Core v0.3 - Minimal Core with Streaming DMEM
// - RV32I subset extended with arithmetic/logic, LW/SW, BEQ/BNE/BLT/BGE/BGEU
// - Supports JAL/JALR, basic CSR file, and ECALL trap redirect
// - Instruction memory initialized from program.hex
// - Data memory accessed through a simple valid/ready handshake
// =============================================
`default_nettype none

module qar_core #(
    parameter IMEM_DEPTH       = 64,
    parameter DMEM_DEPTH       = 256,
    parameter USE_INTERNAL_MEM = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    // Data memory handshake
    output reg         mem_valid,
    output reg         mem_we,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire        mem_ready,
    input  wire [31:0] mem_rdata
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam IMEM_ADDR_WIDTH = clog2(IMEM_DEPTH);
    localparam IMEM_ADDR_MSB   = IMEM_ADDR_WIDTH + 1;
    localparam DMEM_ADDR_WIDTH = clog2(DMEM_DEPTH);

    // Program Counter + instruction memory
    reg [31:0] pc;
    reg [31:0] instr;
    reg [31:0] imem [0:IMEM_DEPTH-1];
    integer imem_init_idx;

    initial begin
        for (imem_init_idx = 0; imem_init_idx < IMEM_DEPTH; imem_init_idx = imem_init_idx + 1)
            imem[imem_init_idx] = 32'b0;
        $display("QAR-Core: loading program from program.hex ...");
        $readmemh("program.hex", imem);
    end

    // Decode helpers
    wire [6:0]  opcode  = instr[6:0];
    wire [4:0]  rd      = instr[11:7];
    wire [2:0]  funct3  = instr[14:12];
    wire [4:0]  rs1     = instr[19:15];
    wire [4:0]  rs2     = instr[24:20];
    wire [6:0]  funct7  = instr[31:25];
    wire [31:0] imm_i   = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s   = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b   = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_j   = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Register file interface
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;
    reg  [4:0]  rf_raddr1;
    reg  [4:0]  rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

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

    // ALU interface
    reg  [31:0] alu_op_a;
    reg  [31:0] alu_op_b;
    reg  [3:0]  alu_op_sel;
    wire [31:0] alu_result;
    wire [31:0] jalr_sum = rf_rdata1 + imm_i;

    alu alu_inst (
        .op_a  (alu_op_a),
        .op_b  (alu_op_b),
        .alu_op(alu_op_sel),
        .result(alu_result)
    );

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;

    // Opcodes
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_OP     = 7'b0110011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_SYSTEM = 7'b1110011;

    // CSR storage (minimal set)
    reg [31:0] csr_mstatus;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;

    localparam CSR_ADDR_MSTATUS = 12'h300;
    localparam CSR_ADDR_MTVEC   = 12'h305;
    localparam CSR_ADDR_MEPC    = 12'h341;
    localparam CSR_ADDR_MCAUSE  = 12'h342;

    // Memory handshake bookkeeping
    reg                  data_pending;
    reg                  data_is_load;
    reg  [4:0]           data_rd_pending;
    reg  [31:0]          data_addr_reg;
    reg  [31:0]          data_wdata_reg;

    wire [DMEM_ADDR_WIDTH-1:0] data_word_addr = data_addr_reg[DMEM_ADDR_WIDTH+1:2];

    // Optional internal DMEM (responds immediately)
    wire        mem_ready_in;
    wire [31:0] mem_rdata_in;

    generate
        if (USE_INTERNAL_MEM) begin : gen_internal_dmem
            reg [31:0] dmem [0:DMEM_DEPTH-1];
            integer dmem_init_idx;
            initial begin
                for (dmem_init_idx = 0; dmem_init_idx < DMEM_DEPTH; dmem_init_idx = dmem_init_idx + 1)
                    dmem[dmem_init_idx] = 32'b0;
                $display("QAR-Core: loading data memory from data.hex ...");
                $readmemh("data.hex", dmem);
            end

            assign mem_ready_in = data_pending ? 1'b1 : 1'b0;
            assign mem_rdata_in = dmem[data_word_addr];

            always @(posedge clk) begin
                if (data_pending && mem_we && mem_valid && mem_ready_in)
                    dmem[data_word_addr] <= data_wdata_reg;
            end
        end else begin : gen_external_dmem
            assign mem_ready_in = mem_ready;
            assign mem_rdata_in = mem_rdata;
            initial begin
                $display("QAR-Core: external data memory expected (provide data.hex via DevKit)");
            end
        end
    endgenerate

    // CSR read helper
    function [31:0] csr_read;
        input [11:0] addr;
        begin
            case (addr)
                CSR_ADDR_MSTATUS: csr_read = csr_mstatus;
                CSR_ADDR_MTVEC:   csr_read = csr_mtvec;
                CSR_ADDR_MEPC:    csr_read = csr_mepc;
                CSR_ADDR_MCAUSE:  csr_read = csr_mcause;
                default:          csr_read = 32'b0;
            endcase
        end
    endfunction

    // Control flags
    reg         csr_write_en;
    reg [11:0]  csr_write_addr;
    reg [31:0]  csr_write_data;
    reg         trap_request;
    reg [31:0]  trap_cause;

    wire [31:0] pc_plus4 = pc + 32'd4;

    // Memory request defaults
    always @(*) begin
        mem_valid = data_pending;
        mem_we    = data_pending && !data_is_load;
        mem_addr  = data_addr_reg;
        mem_wdata = data_wdata_reg;
    end

    // Combinational decode
    reg [31:0] next_pc;
    reg        stall_fetch;
    reg        start_mem;
    reg        start_mem_is_load;
    reg [31:0] start_mem_addr;
    reg [31:0] start_mem_wdata;
    reg [4:0]  start_mem_rd;

    reg        csr_result_valid;
    reg [31:0] csr_result_value;

    reg        branch_taken;
    reg [31:0] branch_target;

    reg        jal_taken;
    reg        jalr_taken;

    reg        load_commit_valid;
    reg [4:0]  load_commit_rd;

    reg        illegal_instr;

    always @(*) begin
        // Defaults
        rf_we        = 1'b0;
        rf_waddr     = rd;
        rf_wdata     = alu_result;
        rf_raddr1    = rs1;
        rf_raddr2    = rs2;
        alu_op_a     = rf_rdata1;
        alu_op_b     = rf_rdata2;
        alu_op_sel   = ALU_ADD;
        next_pc      = pc;
        stall_fetch  = 1'b0;
        start_mem    = 1'b0;
        start_mem_is_load = 1'b0;
        start_mem_addr    = 32'b0;
        start_mem_wdata   = 32'b0;
        start_mem_rd      = rd;
        csr_write_en      = 1'b0;
        csr_write_addr    = 12'b0;
        csr_write_data    = 32'b0;
        csr_result_valid  = 1'b0;
        csr_result_value  = 32'b0;
        trap_request      = 1'b0;
        trap_cause        = 32'd0;
        branch_taken      = 1'b0;
        branch_target     = 32'b0;
        jal_taken         = 1'b0;
        jalr_taken        = 1'b0;
        load_commit_valid = 1'b0;
        load_commit_rd    = data_rd_pending;
        illegal_instr     = 1'b0;

        if (data_pending && mem_ready_in && data_is_load)
            load_commit_valid = 1'b1;

        if (data_pending) begin
            stall_fetch = ~mem_ready_in;
        end

        if (load_commit_valid) begin
            rf_we    = 1'b1;
            rf_waddr = data_rd_pending;
            rf_wdata = mem_rdata_in;
        end

        case (opcode)
            OPCODE_OP_IMM: begin
                rf_we    = 1'b1;
                rf_waddr = rd;
                alu_op_a = rf_rdata1;
                alu_op_sel = ALU_ADD;
                alu_op_b = imm_i;
            end

            OPCODE_OP: begin
                rf_we    = 1'b1;
                rf_waddr = rd;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            alu_op_sel = ALU_ADD;
                        end else if (funct7 == 7'b0100000) begin
                            alu_op_sel = ALU_SUB;
                        end else begin
                            illegal_instr = 1'b1;
                        end
                    end
                    3'b111: alu_op_sel = ALU_AND;
                    3'b110: alu_op_sel = ALU_OR;
                    3'b100: alu_op_sel = ALU_XOR;
                    3'b001: alu_op_sel = ALU_SLL;
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            alu_op_sel = ALU_SRL;
                        end else begin
                            illegal_instr = 1'b1;
                        end
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            OPCODE_LOAD: begin
                if (!data_pending && funct3 == 3'b010) begin
                    start_mem         = 1'b1;
                    start_mem_is_load = 1'b1;
                    start_mem_addr    = rf_rdata1 + imm_i;
                    start_mem_rd      = rd;
                end
            end

            OPCODE_STORE: begin
                if (!data_pending && funct3 == 3'b010) begin
                    start_mem         = 1'b1;
                    start_mem_is_load = 1'b0;
                    start_mem_addr    = rf_rdata1 + imm_s;
                    start_mem_wdata   = rf_rdata2;
                end
            end

            OPCODE_BRANCH: begin
                case (funct3)
                    3'b000: begin // BEQ
                        if (rf_rdata1 == rf_rdata2) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    3'b001: begin // BNE
                        if (rf_rdata1 != rf_rdata2) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    3'b100: begin // BLT
                        if ($signed(rf_rdata1) < $signed(rf_rdata2)) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    3'b101: begin // BGE
                        if ($signed(rf_rdata1) >= $signed(rf_rdata2)) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    3'b110: begin // BLTU
                        if (rf_rdata1 < rf_rdata2) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    3'b111: begin // BGEU
                        if (rf_rdata1 >= rf_rdata2) begin
                            branch_taken  = 1'b1;
                            branch_target = pc + imm_b;
                        end
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            OPCODE_JAL: begin
                rf_we      = 1'b1;
                rf_waddr   = rd;
                rf_wdata   = pc_plus4;
                jal_taken  = 1'b1;
                branch_target = pc + imm_j;
            end

            OPCODE_JALR: begin
                if (funct3 == 3'b000) begin
                    rf_we      = 1'b1;
                    rf_waddr   = rd;
                    rf_wdata   = pc_plus4;
                    jalr_taken = 1'b1;
                    branch_target = { jalr_sum[31:1], 1'b0 };
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            OPCODE_SYSTEM: begin
                if (funct3 == 3'b001) begin
                    // CSRRW
                    csr_result_valid = (rd != 0);
                    csr_result_value = csr_read(instr[31:20]);
                    csr_write_en     = 1'b1;
                    csr_write_addr   = instr[31:20];
                    csr_write_data   = rf_rdata1;
                    if (rd != 0) begin
                        rf_we    = 1'b1;
                        rf_waddr = rd;
                        rf_wdata = csr_result_value;
                    end else begin
                        rf_we = 1'b0;
                    end
                end else if (funct3 == 3'b000 && instr[31:20] == 12'b0) begin
                    // ECALL
                    trap_request = 1'b1;
                    trap_cause   = 32'd11;
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            default: begin
                illegal_instr = (instr != 32'b0);
            end
        endcase

        if (illegal_instr) begin
            trap_request = 1'b1;
            trap_cause   = 32'd2; // illegal instruction
        end

        if (branch_taken)
            next_pc = branch_target;
        else if (jal_taken)
            next_pc = branch_target;
        else if (jalr_taken)
            next_pc = branch_target;
        else if (!trap_request)
            next_pc = pc_plus4;

        if (trap_request) begin
            next_pc     = csr_mtvec;
            stall_fetch = 1'b0;
        end

        if (!data_pending && start_mem)
            stall_fetch = 1'b1;
    end

    // Sequential state updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc           <= 32'b0;
            instr        <= imem[0];
            data_pending <= 1'b0;
            data_is_load <= 1'b0;
            data_addr_reg<= 32'b0;
            data_wdata_reg<= 32'b0;
            data_rd_pending <= 5'b0;
            csr_mstatus  <= 32'b0;
            csr_mtvec    <= 32'h00000100;
            csr_mepc     <= 32'b0;
            csr_mcause   <= 32'b0;
        end else begin
            if (!stall_fetch) begin
                pc    <= next_pc;
                instr <= imem[next_pc[IMEM_ADDR_MSB:2]];
            end

            if (!data_pending && start_mem) begin
                data_pending    <= 1'b1;
                data_is_load    <= start_mem_is_load;
                data_addr_reg   <= start_mem_addr;
                data_wdata_reg  <= start_mem_wdata;
                data_rd_pending <= start_mem_rd;
            end else if (data_pending && mem_ready_in) begin
                data_pending <= 1'b0;
            end

            if (csr_write_en) begin
                case (csr_write_addr)
                    CSR_ADDR_MSTATUS: csr_mstatus <= csr_write_data;
                    CSR_ADDR_MTVEC:   csr_mtvec   <= csr_write_data;
                    CSR_ADDR_MEPC:    csr_mepc    <= csr_write_data;
                    CSR_ADDR_MCAUSE:  csr_mcause  <= csr_write_data;
                    default: ;
                endcase
            end

            if (trap_request) begin
                csr_mepc   <= pc;
                csr_mcause <= trap_cause;
                // Simple MRET-less trap: just jump to mtvec
            end
        end
    end

endmodule

`default_nettype wire
