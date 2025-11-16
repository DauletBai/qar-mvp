// =============================================
// QAR-Core v0.1 - Register File
// 32 registers (x0..x31), RV32I compatible
// - Two read ports
// - One write port
// - x0 is always zero
// =============================================

module regfile (
    input  wire        clk,
    input  wire        we,            // write enable
    input  wire [4:0]  waddr,         // write address
    input  wire [31:0] wdata,         // write data
    input  wire [4:0]  raddr1,        // read address 1
    input  wire [4:0]  raddr2,        // read address 2
    output wire [31:0] rdata1,        // read data 1
    output wire [31:0] rdata2         // read data 2
);

    // Register array
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    // Combinational read
    assign rdata1 = (raddr1 == 0) ? 32'b0 : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 32'b0 : regs[raddr2];

    // Synchronous write
    always @(posedge clk) begin
        if (we && waddr != 0)
            regs[waddr] <= wdata;
    end

endmodule
