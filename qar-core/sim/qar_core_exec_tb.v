`timescale 1ns / 1ps

module qar_core_exec_tb();

    localparam DMEM_WORDS = 256;

    reg clk   = 0;
    reg rst_n = 0;

    wire        mem_valid;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    reg         mem_ready;
    reg  [31:0] mem_rdata;

    // Instantiate core
    qar_core #(
        .IMEM_DEPTH(64),
        .DMEM_DEPTH(DMEM_WORDS),
        .USE_INTERNAL_MEM(0)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    // Simple single-cycle data memory
    reg [31:0] dmem [0:DMEM_WORDS-1];
    integer idx;

    initial begin
        $display("=== QAR-Core v0.4 EXECUTION TEST ===");
        $readmemh("data.hex", dmem);
        mem_ready = 0;
        rst_n = 0;
        #40;
        rst_n = 1;
    end

    always #5 clk = ~clk;

    always @(*) begin
        mem_ready = mem_valid;
        if (mem_valid && !mem_we)
            mem_rdata = dmem[mem_addr[9:2]];
    end

    always @(posedge clk) begin
        if (mem_valid && mem_we)
            dmem[mem_addr[9:2]] <= mem_wdata;
    end

    // Finish checks
    initial begin
        #2000;
        $display("Register x10 = %0d (expected 14)", uut.rf_inst.regs[10]);
        if (uut.rf_inst.regs[10] !== 32'd14) begin
            $display("ERROR: x10 != 14");
            $finish;
        end

        $display("Data memory[16] = %0d (expected 14)", dmem[16]);
        if (dmem[16] !== 32'd14) begin
            $display("ERROR: dmem[16] != 14");
            $finish;
        end

        $display("Data memory[17] = 0x%08h (expected 0x00000123)", dmem[17]);
        if (dmem[17] !== 32'h0000_0123) begin
            $display("ERROR: dmem[17] marker mismatch");
            $finish;
        end

        $display("Execution test completed.");
        $finish;
    end

endmodule
