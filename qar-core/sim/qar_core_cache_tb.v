`timescale 1ns / 1ps

module qar_core_cache_tb();

    localparam IMEM_WORDS      = 64;
    localparam DMEM_WORDS      = 64;
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

    qar_core #(
        .IMEM_DEPTH(IMEM_WORDS),
        .DMEM_DEPTH(DMEM_WORDS),
        .USE_INTERNAL_IMEM(0),
        .USE_INTERNAL_DMEM(0),
        .ICACHE_ENTRIES(8)
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
        .i2c_sda_oe(i2c_sda_oe),
        .adc_ch0(12'd0),
        .adc_ch1(12'd0),
        .adc_ch2(12'd0),
        .adc_ch3(12'd0)
    );

    assign i2c_sda_loop = i2c_sda_oe ? i2c_sda_out : 1'b1;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    integer imem_req_count;

    initial begin
        $display("=== QAR-Core cache regression === (ICACHE entries = %0d)", uut.ICACHE_ENTRIES);
        $readmemh("program_cache.hex", imem);
        $readmemh("data_cache.hex", dmem);
        imem_ready = 0;
        mem_ready  = 0;
        imem_req_count = 0;
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
        if (!rst_n)
            imem_req_count <= 0;
        else if (imem_valid && imem_ready)
            imem_req_count <= imem_req_count + 1;

        if (mem_valid && mem_we)
            dmem[mem_addr[DMEM_ADDR_WIDTH+1:2]] <= mem_wdata;
    end

    initial begin
        #20000;
        $display("Register x1 = %0d (expected > 0)", uut.rf_inst.regs[1]);
        if (uut.rf_inst.regs[1] == 32'd0) begin
            $display("ERROR: cache-loop program did not execute");
            $finish;
        end

        $display("IMEM request count = %0d (cache valids %0d %0d %0d %0d)", imem_req_count, uut.icache_valid[0], uut.icache_valid[1], uut.icache_valid[2], uut.icache_valid[3]);

        $display("Cache regression completed.");
        $finish;
    end

endmodule
