`timescale 1ns / 1ps

module qar_core_random_tb();

    reg clk = 0;
    reg rst_n = 0;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire        mem_we;
    reg  [31:0] mem_rdata;

    qar_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_we(mem_we),
        .mem_rdata(mem_rdata)
    );

    always #5 clk = ~clk;

    integer iteration;
    integer idx;
    integer expected;

    initial begin
        $display("=== QAR-Core randomized load/store regression ===");
        mem_rdata = 32'b0;

        for (iteration = 0; iteration < 5; iteration = iteration + 1) begin
            // Reset core and randomize the first six data words
            rst_n = 0;
            #20;
            expected = 0;
            for (idx = 0; idx < 6; idx = idx + 1) begin
                uut.dmem[idx] = $random;
                if ($signed(uut.dmem[idx]) >= 0)
                    expected = expected + $signed(uut.dmem[idx]);
            end
            rst_n = 1;

            // Allow program to run to completion
            #600;

            if (uut.rf_inst.regs[10] !== expected) begin
                $display("ERROR(iter %0d): accumulator mismatch (got %0d expected %0d)", iteration, uut.rf_inst.regs[10], expected);
                $finish;
            end
            if (uut.dmem[16] !== expected) begin
                $display("ERROR(iter %0d): stored sum mismatch (dmem[16] = %0d, expected %0d)", iteration, uut.dmem[16], expected);
                $finish;
            end
            if (uut.dmem[17] !== 32'h0000_0123) begin
                $display("ERROR(iter %0d): return marker changed (dmem[17] = 0x%08h)", iteration, uut.dmem[17]);
                $finish;
            end
        end

        $display("Randomized regression complete.");
        $finish;
    end

endmodule
