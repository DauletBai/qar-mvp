// =============================================
// QAR-Core v0.1 - Arithmetic Logic Unit (ALU)
// Supported operations (RV32I subset):
//  - ADD, SUB
//  - AND, OR, XOR
//  - SLL (shift left logical)
//  - SRL (shift right logical)
// =============================================
`default_nettype none

module alu (
    input  wire [31:0] op_a,
    input  wire [31:0] op_b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] result
);

    // ALU operation encodings
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;

    always @(*) begin
        case (alu_op)
            ALU_ADD: result = op_a + op_b;
            ALU_SUB: result = op_a - op_b;
            ALU_AND: result = op_a & op_b;
            ALU_OR:  result = op_a | op_b;
            ALU_XOR: result = op_a ^ op_b;
            ALU_SLL: result = op_a << op_b[4:0];
            ALU_SRL: result = op_a >> op_b[4:0];
            default: result = 32'b0;
        endcase
    end

endmodule

`default_nettype wire
