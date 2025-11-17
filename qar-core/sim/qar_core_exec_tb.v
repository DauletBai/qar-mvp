`timescale 1ns / 1ps

module qar_core_exec_tb();

    localparam IMEM_WORDS      = 128;
    localparam DMEM_WORDS      = 256;
    localparam IMEM_ADDR_WIDTH = 7;
    localparam DMEM_ADDR_WIDTH = 8;

    reg clk   = 0;
    reg rst_n = 0;
    reg irq_external = 0;

    localparam integer TIMER_RESULT_WORD = 18; // 72 / 4
    localparam integer EXT_RESULT_WORD   = 19; // 76 / 4
    localparam integer ECALL_RESULT_WORD = 20; // 80 / 4
    localparam integer NEST_LOG0_WORD   = 21; // 84 / 4
    localparam integer NEST_LOG1_WORD   = 22; // 88 / 4
    localparam integer NEST_LOG2_WORD   = 23; // 92 / 4

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
    reg         irq_timer_ack_q = 0;
    reg         irq_external_ack_q = 0;
    integer     timer_ack_count = 0;
    integer     external_ack_count = 0;

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
        .irq_external(irq_external),
        .irq_timer_ack(irq_timer_ack),
        .irq_external_ack(irq_external_ack),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];

    initial begin
        $display("=== QAR-Core v0.6 EXECUTION TEST ===");
        $readmemh("program.hex", imem);
        $readmemh("data.hex", dmem);
        imem_ready = 0;
        mem_ready  = 0;
        rst_n = 0;
        #40;
        rst_n = 1;
    end

    always #5 clk = ~clk;

    initial begin
        irq_external = 0;
        #4000;
        irq_external = 1;
        @(posedge irq_external_ack);
        irq_external = 0;
    end

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
        irq_timer_ack_q <= irq_timer_ack;
        irq_external_ack_q <= irq_external_ack;
        if (irq_timer_ack && !irq_timer_ack_q)
            timer_ack_count = timer_ack_count + 1;
        if (irq_external_ack && !irq_external_ack_q)
            external_ack_count = external_ack_count + 1;
    end

    initial begin
        #500000;
        $display("Register x10 = %0d (expected 2)", uut.rf_inst.regs[10]);
        if (uut.rf_inst.regs[10] !== 32'd2) begin
            $display("ERROR: timer interrupt count mismatch");
            $finish;
        end

        $display("Register x11 = %0d (expected 1)", uut.rf_inst.regs[11]);
        if (uut.rf_inst.regs[11] !== 32'd1) begin
            $display("ERROR: external interrupt count mismatch");
            $finish;
        end

        $display("Data memory[%0d] = %0d (expected 2)", TIMER_RESULT_WORD, dmem[TIMER_RESULT_WORD]);
        if (dmem[TIMER_RESULT_WORD] !== 32'd2) begin
            $display("ERROR: timer result word mismatch");
            $finish;
        end

        $display("Data memory[%0d] = %0d (expected 1)", EXT_RESULT_WORD, dmem[EXT_RESULT_WORD]);
        if (dmem[EXT_RESULT_WORD] !== 32'd1) begin
            $display("ERROR: external result word mismatch");
            $finish;
        end

        $display("Nested log words = %0d, %0d, %0d (expected 1,2,3)",
                 dmem[NEST_LOG0_WORD], dmem[NEST_LOG1_WORD], dmem[NEST_LOG2_WORD]);
        if (dmem[NEST_LOG0_WORD] !== 32'd1 || dmem[NEST_LOG1_WORD] !== 32'd2 || dmem[NEST_LOG2_WORD] !== 32'd3) begin
            $display("ERROR: nested interrupt log mismatch");
            $finish;
        end

        $display("Data memory[%0d] = 0x%08h (expected 0x000001EE)", ECALL_RESULT_WORD, dmem[ECALL_RESULT_WORD]);
        if (dmem[ECALL_RESULT_WORD] !== 32'h0000_01EE) begin
            $display("ERROR: ECALL marker mismatch");
            $display("MCause at end = 0x%08h", uut.csr_mcause);
            $display("Ack counts (timer/ext) = %0d/%0d", timer_ack_count, external_ack_count);
            $display("PC snapshot IF=%h ID=%h EX=%h", uut.if_pc, uut.id_pc, uut.ex_pc);
            $finish;
        end

        $display("Timer ack count = %0d (expected 2)", timer_ack_count);
        if (timer_ack_count !== 2) begin
            $display("ERROR: timer ack count mismatch");
            $finish;
        end

        $display("External ack count = %0d (expected 1)", external_ack_count);
        if (external_ack_count !== 1) begin
            $display("ERROR: external ack count mismatch");
            $finish;
        end

        $display("Execution test completed.");
        $finish;
    end

endmodule
