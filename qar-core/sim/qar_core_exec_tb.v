`timescale 1ns / 1ps

module qar_core_exec_tb();

    reg clk   = 0;
    reg rst_n = 0;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    reg  [31:0] mem_rdata;

    // Instantiate core
    qar_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_rdata(mem_rdata)
    );

    // Simple clock generator
    always #5 clk = ~clk;

    initial begin
        $display("=== QAR-Core v0.3 EXECUTION TEST ===");

        mem_rdata = 32'b0;

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Let the core run for enough cycles to process the micro-program
        #500;

        // Check sum result (1 + 3 + 4 + 6 = 14)
        $display("Register x10 = %0d (expected 14)", uut.rf_inst.regs[10]);
        if (uut.rf_inst.regs[10] !== 32'd14) begin
            $display("ERROR: x10 != 14");
            $finish;
        end

        // Check stored results in data memory (address 64 -> index 16, 68 -> 17)
        $display("Data memory[16] = %0d (expected 14)", uut.dmem[16]);
        if (uut.dmem[16] !== 32'd14) begin
            $display("ERROR: data memory[16] != 14");
            $finish;
        end

        $display("Data memory[17] = 0x%08h (expected 0x00000123)", uut.dmem[17]);
        if (uut.dmem[17] !== 32'h0000_0123) begin
            $display("ERROR: data memory[17] marker mismatch");
            $finish;
        end

        $display("Execution test completed.");
        $finish;
    end

endmodule
