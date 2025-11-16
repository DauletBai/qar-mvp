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
        $display("=== QAR-Core v0.1 EXECUTION TEST ===");

        mem_rdata = 32'b0;

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Let the core run for some cycles (enough for 3 instructions)
        #200;

        // Read x3 from register file via hierarchical reference
        // NOTE: rf_inst is the instance name inside qar_core
        $display("Register x3 = %0d (expected 8)", uut.rf_inst.regs[3]);

        $display("Execution test completed.");
        $finish;
    end

endmodule
