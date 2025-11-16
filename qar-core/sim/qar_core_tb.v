`timescale 1ns / 1ps

module qar_core_tb();

    reg clk = 0;
    reg rst_n = 0;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    reg  [31:0] mem_rdata;

    // Instantiate CPU
    qar_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_rdata(mem_rdata)
    );

    // Clock generator
    always #5 clk = ~clk;  // 100 MHz

    initial begin
        $display("=== QAR-Core v0.2 simulation start ===");

        rst_n = 0;
        #50;
        rst_n = 1;

        // simple test: memory returns fixed value
        mem_rdata = 32'h0000_0000;

        #200;
        $display("Simulation done.");
        $finish;
    end

endmodule
