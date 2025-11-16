`timescale 1ns / 1ps

module qar_core_random_tb();

    localparam DMEM_WORDS = 256;

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
        .DMEM_DEPTH(DMEM_WORDS),
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
        rst_n = 0;
        mem_ready = 0;
        clk = 0;
        #40;
        rst_n = 1;
    end

    always #5 clk = ~clk;

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
            #(10000);
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

    // Memory model with randomized wait states
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
                    dmem[pend_addr[9:2]] <= pend_wdata;
                else
                    mem_rdata <= dmem[pend_addr[9:2]];
                pending <= 1'b0;
            end
        end
    end

endmodule
