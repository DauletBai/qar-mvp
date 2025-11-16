`timescale 1ns / 1ps

module alu_tb();

    reg  [31:0] op_a;
    reg  [31:0] op_b;
    reg  [3:0]  alu_op;
    wire [31:0] result;

    // Localparams to mirror ALU operation codes
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;

    alu uut (
        .op_a(op_a),
        .op_b(op_b),
        .alu_op(alu_op),
        .result(result)
    );

    initial begin
        $display("=== QAR ALU Test ===");

        // ADD: 10 + 5 = 15
        op_a = 10; op_b = 5; alu_op = ALU_ADD;
        #10;
        $display("ADD: 10 + 5 = %0d (expected 15)", result);

        // SUB: 10 - 5 = 5
        op_a = 10; op_b = 5; alu_op = ALU_SUB;
        #10;
        $display("SUB: 10 - 5 = %0d (expected 5)", result);

        // AND
        op_a = 32'h0F0F_F0F0; op_b = 32'h00FF_00FF; alu_op = ALU_AND;
        #10;
        $display("AND: result = 0x%08h (expected 0x000F_00F0)", result);

        // OR
        op_a = 32'h0F00_F000; op_b = 32'h00FF_00FF; alu_op = ALU_OR;
        #10;
        $display("OR:  result = 0x%08h (expected 0x0FFF_F0FF)", result);

        // XOR
        op_a = 32'hAAAA_5555; op_b = 32'hFFFF_0000; alu_op = ALU_XOR;
        #10;
        $display("XOR: result = 0x%08h (expected 0x5555_5555)", result);

        // SLL
        op_a = 32'h0000_0001; op_b = 5; alu_op = ALU_SLL;
        #10;
        $display("SLL: 1 << 5 = %0d (expected 32)", result);

        // SRL
        op_a = 32'h0000_0100; op_b = 2; alu_op = ALU_SRL;
        #10;
        $display("SRL: 256 >> 2 = %0d (expected 64)", result);

        $display("ALU test completed.");
        $finish;
    end

endmodule
