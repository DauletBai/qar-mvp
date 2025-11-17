`timescale 1ns / 1ps

module qar_core_uart_tb();

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
    wire        gpio_irq;
    wire        uart_tx;
    wire        uart_rx_loop;
    wire        uart_de;
    wire        uart_re;

    assign uart_rx_loop = uart_tx;

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
        .gpio_irq(gpio_irq),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx_loop),
        .uart_de(uart_de),
        .uart_re(uart_re)
    );

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        $display("=== QAR-Core UART RS-485 Demo ===");
        $readmemh("program_uart.hex", imem);
        $readmemh("data_uart.hex", dmem);
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
        #300000;
        $display("DMEM[0] = 0x%08h (expected 0x00000033)", dmem[0]);
        $display("DMEM[1] = 0x%08h (expected 0x00000055)", dmem[1]);
        $display("DMEM[2] = 0x%08h (expected 0x0000000A)", dmem[2]);

        if (dmem[0] !== 32'h0000_0033) begin
            $display("ERROR: first UART byte mismatch");
            $finish;
        end
        if (dmem[1] !== 32'h0000_0055) begin
            $display("ERROR: second UART byte mismatch");
            $finish;
        end
        if (dmem[2] !== 32'h0000_000A) begin
            $display("ERROR: idle IRQ snapshot mismatch");
            $finish;
        end
        $display("UART RS-485 demo completed.");
        $finish;
    end

endmodule
