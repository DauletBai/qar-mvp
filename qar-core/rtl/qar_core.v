// QAR-Core v0.1 — минимальный каркас
// Цель: простейшее ядро для MVP (RV32I-подмножество)

module qar_core (
    input  wire        clk,
    input  wire        rst_n,

    // Простая шина к памяти (пока абстрактная)
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire        mem_we,
    input  wire [31:0] mem_rdata
);

    // Здесь позже будут:
    // - регистровый файл
    // - ALU
    // - декодер команд
    // - счётчик команд (PC)
    // - простая FSM управления

endmodule
