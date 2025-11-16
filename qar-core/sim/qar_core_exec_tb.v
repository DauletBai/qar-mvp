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
        $display("=== QAR-Core v0.2 EXECUTION TEST ===");

        mem_rdata = 32'b0;

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Let the core run for enough cycles to process the micro-program
        #400;

        // Check sum result
        $display("Register x10 = %0d (expected 10)", uut.rf_inst.regs[10]);
        if (uut.rf_inst.regs[10] !== 32'd10) begin
            $display("ERROR: x10 != 10");
            $finish;
        end

        // Check stored result in data memory (address 16 -> word index 4)
        $display("Data memory[4] = %0d (expected 10)", uut.dmem[4]);
        if (uut.dmem[4] !== 32'd10) begin
            $display("ERROR: data memory[4] != 10");
            $finish;
        end

        $display("Execution test completed.");
        $finish;
    end

endmodule
