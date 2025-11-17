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
    wire        gpio_irq;
    wire        uart_tx;
    reg         uart_rx = 1'b1;
    wire        uart_de;
    wire        uart_re;
    wire        spi_sck;
    wire        spi_mosi;
    wire        spi_miso = 1'b1;
    wire [3:0]  spi_cs_n;
    wire        i2c_scl;
    wire        i2c_sda_out;
    wire        i2c_sda_oe;
    wire        i2c_sda_loop;
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
        .gpio_irq(gpio_irq),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .uart_de(uart_de),
        .uart_re(uart_re),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .i2c_scl(i2c_scl),
        .i2c_sda_out(i2c_sda_out),
        .i2c_sda_in(i2c_sda_loop),
        .i2c_sda_oe(i2c_sda_oe)
    );

    assign i2c_sda_loop = i2c_sda_oe ? i2c_sda_out : 1'b1;

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
        $display("DMEM[0] = 0x%08h (expected 0x00000123)", dmem[0]);
        $display("DMEM[1] = 0x%08h (expected 0xDEADBEEF)", dmem[1]);
        $display("DMEM[2] = 0x%08h (expected 0x00000000)", dmem[2]);
        $display("DMEM[3] = 0x%08h (expected 0x00000321)", dmem[3]);
        $display("DMEM[4] = 0x%08h (expected 0xCAFEBABE)", dmem[4]);
        $display("DMEM[5] = 0x%08h (expected 0x01020304)", dmem[5]);

        if (dmem[0] !== 32'h0000_0123) begin
            $display("ERROR: first RX ID mismatch");
            $finish;
        end
        if (dmem[1] !== 32'hDEAD_BEEF) begin
            $display("ERROR: first RX payload word 0 mismatch");
            $finish;
        end
        if (dmem[2] !== 32'h0000_0000) begin
            $display("ERROR: first RX payload word 1 mismatch");
            $finish;
        end
        if (dmem[3] !== 32'h0000_0321) begin
            $display("ERROR: second RX ID mismatch");
            $finish;
        end
        if (dmem[4] !== 32'hCAFE_BABE) begin
            $display("ERROR: second RX payload word 0 mismatch");
            $finish;
        end
        if (dmem[5] !== 32'h0102_0304) begin
            $display("ERROR: second RX payload word 1 mismatch");
            $finish;
        end
        $display("CAN demo completed.");
        $finish;
    end

endmodule
