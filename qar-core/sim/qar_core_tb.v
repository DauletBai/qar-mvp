`timescale 1ns / 1ps

module qar_core_tb();

    reg clk = 0;
    reg rst_n = 0;

    wire        mem_valid;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    reg         mem_ready;
    reg  [31:0] mem_rdata;

    qar_core #(
        .IMEM_DEPTH(64),
        .DMEM_DEPTH(256),
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

    reg [31:0] dmem [0:255];
    integer i;

    initial begin
        $display("=== QAR-Core v0.4 simulation start ===");
        $readmemh("data.hex", dmem);
        rst_n = 0;
        #50;
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

    initial begin
        #500;
        $display("Simulation done.");
        $finish;
    end

endmodule
