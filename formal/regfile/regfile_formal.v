`default_nettype none

module regfile_formal;
    reg clk = 0;
    always #5 clk = ~clk;

    reg we = 0;
    reg [4:0] waddr = 0;
    reg [31:0] wdata = 0;
    reg [4:0] raddr1 = 0;
    reg [4:0] raddr2 = 0;

    wire [31:0] rdata1;
    wire [31:0] rdata2;

    regfile dut (
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    reg past_valid = 0;
    reg [31:0] model [0:31];
    integer idx;

    initial begin
        for (idx = 0; idx < 32; idx = idx + 1)
            model[idx] = 32'b0;
    end

    function [31:0] rf_read;
        input [4:0] addr;
        begin
            if (addr == 0)
                rf_read = 32'b0;
            else
                rf_read = model[addr];
        end
    endfunction

    always @(posedge clk) begin
        past_valid <= 1'b1;

        we     <= $anyseq;
        waddr  <= $anyseq;
        wdata  <= $anyseq;
        raddr1 <= $anyseq;
        raddr2 <= $anyseq;

        assert(model[0] == 32'b0);

        if (past_valid) begin
            assert(rdata1 == rf_read(raddr1));
            assert(rdata2 == rf_read(raddr2));
        end

        if (we && waddr != 0)
            model[waddr] <= wdata;
    end

endmodule

`default_nettype wire
