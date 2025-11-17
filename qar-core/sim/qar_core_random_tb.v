`timescale 1ns / 1ps

module qar_core_random_tb();

    localparam IMEM_WORDS      = 128;
    localparam DMEM_WORDS      = 256;
    localparam IMEM_ADDR_WIDTH = 7;
    localparam DMEM_ADDR_WIDTH = 8;

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
    integer iteration;
    integer idx;
    integer expected;

    reg        pending;
    reg [1:0] wait_count;
    reg        pend_we;
    reg [31:0] pend_addr;
    reg [31:0] pend_wdata;

    initial begin
        $display("=== QAR-Core randomized load/store regression ===");
        $readmemh("program.hex", imem);
        rst_n = 0;
        mem_ready = 0;
        clk = 0;
        #40;
        rst_n = 1;
    end

    always #5 clk = ~clk;

    always @(*) begin
        imem_ready = imem_valid;
        if (imem_valid)
            imem_rdata = imem[imem_addr[IMEM_ADDR_WIDTH+1:2]];
    end

    task randomize_dmem;
        begin
            expected = 0;
            for (idx = 0; idx < 6; idx = idx + 1) begin
                dmem[idx] = $random;
                if ($signed(dmem[idx]) >= 0)
                    expected = expected + $signed(dmem[idx]);
            end
            for (idx = 6; idx < DMEM_WORDS; idx = idx + 1)
                dmem[idx] = 32'b0;
        end
    endtask

    initial begin
        for (iteration = 0; iteration < 5; iteration = iteration + 1) begin
            randomize_dmem();
            rst_n = 0;
            #20;
            rst_n = 1;
            pending    = 0;
            wait_count = 0;
            #(20000);
            if (uut.rf_inst.regs[10] !== expected) begin
                $display("ERROR(iter %0d): accumulator mismatch (got %0d expected %0d)", iteration, uut.rf_inst.regs[10], expected);
                $finish;
            end
            if (dmem[16] !== expected) begin
                $display("ERROR(iter %0d): stored sum mismatch (dmem[16] = %0d, expected %0d)", iteration, dmem[16], expected);
                $finish;
            end
        end
        $display("Randomized regression complete.");
        $finish;
    end

    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (!pending && mem_valid) begin
            pending    = 1'b1;
            pend_we    = mem_we;
            pend_addr  = mem_addr;
            pend_wdata = mem_wdata;
            wait_count = $random & 2'b11;
        end else if (pending) begin
            if (wait_count != 0)
                wait_count <= wait_count - 1'b1;
            else begin
                mem_ready <= 1'b1;
                if (pend_we)
                    dmem[pend_addr[DMEM_ADDR_WIDTH+1:2]] <= pend_wdata;
                else
                    mem_rdata <= dmem[pend_addr[DMEM_ADDR_WIDTH+1:2]];
                pending <= 1'b0;
            end
        end
    end

endmodule
