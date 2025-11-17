`timescale 1ns / 1ps

module qar_core_can_tb();

    localparam IMEM_WORDS = 64;
    localparam DMEM_WORDS = 64;
    localparam IMEM_ADDR_WIDTH = 6;
    localparam DMEM_ADDR_WIDTH = 6;

    reg clk = 0;
    reg rst_n = 0;

    wire        imem_valid;
    wire [31:0] imem_addr;
    reg         imem_ready;
    reg  [31:0] imem_rdata;

    wire        mem_valid;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    reg         mem_ready;
    reg  [31:0] mem_rdata;

    wire        irq_timer_ack;
    wire        irq_external_ack;
    wire [31:0] gpio_out;
    wire [31:0] gpio_dir;
    wire [31:0] gpio_in = 32'b0;
    wire        uart_tx;
    reg         uart_rx = 1'b1;
    wire        uart_de;
    wire        uart_re;
    wire        can_irq_dummy;

    qar_core #(
        .IMEM_DEPTH(IMEM_WORDS),
        .DMEM_DEPTH(DMEM_WORDS),
        .USE_INTERNAL_IMEM(0),
        .USE_INTERNAL_DMEM(0)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_valid(imem_valid),
        .imem_addr(imem_addr),
        .imem_ready(imem_ready),
        .imem_rdata(imem_rdata),
        .mem_valid(mem_valid),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata),
        .irq_timer(1'b0),
        .irq_external(1'b0),
        .irq_timer_ack(irq_timer_ack),
        .irq_external_ack(irq_external_ack),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .uart_de(uart_de),
        .uart_re(uart_re)
    );

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        $display("=== QAR-Core CAN Loopback Demo ===");
        $readmemh("program_can.hex", imem);
        $readmemh("data_can.hex", dmem);
        imem_ready = 0;
        mem_ready  = 0;
        rst_n = 0;
        #40;
        rst_n = 1;
    end

    always #5 clk = ~clk;

    always @(*) begin
        imem_ready = imem_valid;
        if (imem_valid)
            imem_rdata = imem[imem_addr[IMEM_ADDR_WIDTH+1:2]];
    end

    always @(*) begin
        mem_ready = mem_valid;
        if (mem_valid && !mem_we)
            mem_rdata = dmem[mem_addr[DMEM_ADDR_WIDTH+1:2]];
    end

    always @(posedge clk) begin
        if (mem_valid && mem_we)
            dmem[mem_addr[DMEM_ADDR_WIDTH+1:2]] <= mem_wdata;
    end

    initial begin
        #200000;
        $display("DMEM[0] = 0x%08h (expected 0xDEADBEEF)", dmem[0]);
        if (dmem[0] !== 32'hDEAD_BEEF) begin
            $display("ERROR: CAN loopback did not store expected data");
            $finish;
        end
        $display("CAN demo completed.");
        $finish;
    end

endmodule
