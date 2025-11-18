`timescale 1ns / 1ps

module qar_core_adc_tb();

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
    wire        uart_de;
    wire        uart_re;

    localparam [11:0] ADC_CH0_VAL = 12'h145;
    localparam [11:0] ADC_CH1_VAL = 12'h2A7;
    localparam [11:0] ADC_CH2_VAL = 12'h3E1;
    localparam [11:0] ADC_CH3_VAL = 12'h055;

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
        .uart_rx(uart_tx),
        .uart_de(uart_de),
        .uart_re(uart_re),
        .spi_sck(),
        .spi_mosi(),
        .spi_miso(1'b1),
        .spi_cs_n(),
        .i2c_scl(),
        .i2c_sda_out(),
        .i2c_sda_in(1'b1),
        .i2c_sda_oe(),
        .adc_ch0(ADC_CH0_VAL),
        .adc_ch1(ADC_CH1_VAL),
        .adc_ch2(ADC_CH2_VAL),
        .adc_ch3(ADC_CH3_VAL)
    );

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        $display("=== QAR-Core ADC Demo ===");
        $readmemh("program_adc.hex", imem);
        $readmemh("data_adc.hex", dmem);
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
        #400000;
        $display("DMEM[0] = 0x%08h (expect ch0 sample)", dmem[0]);
        $display("DMEM[1] = 0x%08h (expect ch1 sample)", dmem[1]);
        $display("DMEM[2] = 0x%08h (expect ch2 sample)", dmem[2]);

        if (dmem[0] !== 32'h0000_0145) begin
            $display("ERROR: ADC channel0 mismatch");
            $finish;
        end
        if (dmem[1] !== 32'h0001_02A7) begin
            $display("ERROR: ADC channel1 mismatch");
            $finish;
        end
        if (dmem[2] !== 32'h0002_03E1) begin
            $display("ERROR: ADC channel2 mismatch");
            $finish;
        end
        $display("ADC demo completed.");
        $finish;
    end

endmodule
