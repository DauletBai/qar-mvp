`timescale 1ns / 1ps

module regfile_tb();

    reg clk = 0;
    reg we  = 0;
    reg [4:0] waddr = 0;
    reg [31:0] wdata = 0;

    reg [4:0] raddr1 = 0;
    reg [4:0] raddr2 = 0;

    wire [31:0] rdata1;
    wire [31:0] rdata2;

    // Instantiate
    regfile uut (
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== QAR Register File Test ===");

        // Write x5 = 123
        we = 1; waddr = 5; wdata = 123;
        #10;

        // Read x5
        we = 0; raddr1 = 5;
        #10;
        $display("Read x5 = %d (expected 123)", rdata1);

        // Check x0 is immutable
        we = 1; waddr = 0; wdata = 999;
        #10;

        raddr1 = 0;
        #10;
        $display("Read x0 = %d (expected 0)", rdata1);

        $display("Test completed.");
        $finish;
    end

endmodule
