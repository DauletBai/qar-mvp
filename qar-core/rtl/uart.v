`default_nettype none

module qar_uart #(
    parameter FIFO_DEPTH = 8,
    parameter CLOCK_HZ   = 50_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bus_write,
    input  wire        bus_read,
    input  wire [3:0]  addr_word,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         tx,
    input  wire        rx,
    output reg         rs485_de,
    output reg         rs485_re,
    output wire        irq
);

    localparam FIFO_ADDR_BITS = $clog2(FIFO_DEPTH);

    // Control and status registers
    reg [31:0] ctrl;
    reg [31:0] baud_div;
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [31:0] rs485_ctrl;
    reg [31:0] status;

    // FIFOs
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;
    wire rx_fifo_empty = (rx_head == rx_tail);

    assign irq = |(irq_en & irq_status);

    // TX state
    reg [9:0] tx_shift;
    reg [3:0] tx_bits_remaining;
    reg [31:0] tx_counter;

    // RX state
    reg [9:0] rx_shift;
    reg [3:0] rx_bits_remaining;
    reg [31:0] rx_counter;
    reg        rx_busy;
    reg        rx_sync1, rx_sync2;

    wire uart_enable = ctrl[0];

    // Register write operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl        <= 32'h0000_0001;
            baud_div    <= CLOCK_HZ / 115200;
            irq_en      <= 32'b0;
            irq_status  <= 32'b0;
            rs485_ctrl  <= 32'h0000_0001; // auto-direction enabled
            tx_head     <= 0;
            tx_tail     <= 0;
            rx_head     <= 0;
            rx_tail     <= 0;
            status      <= 32'b0;
            tx          <= 1'b1;
            tx_shift    <= 10'h3FF;
            tx_bits_remaining <= 0;
            tx_counter  <= 0;
            rx_shift    <= 10'b0;
            rx_bits_remaining <= 0;
            rx_counter  <= 0;
            rx_busy     <= 1'b0;
            rx_sync1    <= 1'b1;
            rx_sync2    <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;

            if (bus_write) begin
                case (addr_word)
                    4'h0: if (!tx_fifo_full)
                        begin
                            tx_fifo[tx_head[FIFO_ADDR_BITS-1:0]] <= wdata[7:0];
                            tx_head <= tx_head + 1;
                            irq_status[1] <= 1'b0;
                        end
                    4'h2: ctrl <= wdata;
                    4'h3: baud_div <= wdata;
                    4'h4: irq_en <= wdata;
                    4'h5: begin
                        irq_status <= irq_status & ~wdata;
                        if (wdata[2]) begin
                            status[2] <= 1'b0;
                            status[3] <= 1'b0;
                        end
                    end
                    4'h6: rs485_ctrl <= wdata;
                endcase
            end

            if (bus_read) begin
                if (addr_word == 4'h0 && !rx_fifo_empty) begin
                    rx_tail <= rx_tail + 1;
                    if ((rx_head - (rx_tail + 1)) == 0)
                        irq_status[0] <= 1'b0;
                end
            end

            status[0] <= !rx_fifo_empty;
            status[1] <= !tx_fifo_full;
            status[4] <= (tx_bits_remaining != 0);

            // Transmit state machine
            if (!uart_enable) begin
                tx_bits_remaining <= 0;
                tx <= 1'b1;
            end else if (tx_bits_remaining == 0) begin
                if (!tx_fifo_empty) begin
                    tx_shift        <= {1'b1, tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]], 1'b0};
                    tx_bits_remaining <= 10;
                    tx_counter      <= 0;
                    tx_tail         <= tx_tail + 1;
                end
            end else begin
                if (tx_counter >= baud_div) begin
                    tx_counter      <= 0;
                    tx              <= tx_shift[0];
                    tx_shift        <= {1'b1, tx_shift[9:1]};
                    tx_bits_remaining <= tx_bits_remaining - 1;
                    if (tx_bits_remaining == 1 && tx_fifo_empty)
                        irq_status[1] <= 1'b1; // TX buffer empty
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end

            // Receive state machine
            if (!uart_enable) begin
                rx_busy <= 1'b0;
                rx_bits_remaining <= 0;
            end else begin
                if (!rx_busy) begin
                    if (rx_sync2 == 1'b0) begin
                        rx_busy          <= 1'b1;
                        rx_counter       <= baud_div >> 1;
                        rx_bits_remaining<= 10;
                        rx_shift         <= 10'b0;
                    end
                end else begin
                    if (rx_counter >= baud_div) begin
                        rx_counter <= 0;
                        rx_shift   <= {rx_sync2, rx_shift[9:1]};
                        rx_bits_remaining <= rx_bits_remaining - 1;
                        if (rx_bits_remaining == 1) begin
                            rx_busy <= 1'b0;
                            if (!rx_fifo_full) begin
                                rx_fifo[rx_head[FIFO_ADDR_BITS-1:0]] <= rx_shift[8:1];
                                rx_head <= rx_head + 1;
                                irq_status[0] <= 1'b1;
                            end else begin
                                status[3] <= 1'b1; // overrun
                                irq_status[2] <= 1'b1;
                            end
                        end
                    end else begin
                        rx_counter <= rx_counter + 1;
                    end
                end
            end

            if (rx_sync2 == 1'b1 && rx_busy && rx_bits_remaining == 0) begin
                status[2] <= 1'b1; // framing error
                irq_status[2] <= 1'b1;
            end
        end
    end

    // RS-485 control (DE/RE)
    reg drive_de_raw;
    reg drive_re_raw;

    always @(*) begin
        if (rs485_ctrl[0]) begin // auto-direction
            drive_de_raw = (tx_bits_remaining != 0) || !tx_fifo_empty;
            drive_re_raw = ~drive_de_raw;
        end else begin
            drive_de_raw = rs485_ctrl[3];
            drive_re_raw = rs485_ctrl[4];
        end
        rs485_de = rs485_ctrl[1] ? ~drive_de_raw : drive_de_raw;
        rs485_re = rs485_ctrl[2] ? ~drive_re_raw : drive_re_raw;
    end

    // Bus read mux
    always @(*) begin
        rdata = 32'b0;
        if (bus_read) begin
            case (addr_word)
                4'h0: rdata = rx_fifo[rx_tail[FIFO_ADDR_BITS-1:0]];
                4'h1: rdata = status;
                4'h2: rdata = ctrl;
                4'h3: rdata = baud_div;
                4'h4: rdata = irq_en;
                4'h5: rdata = irq_status;
                4'h6: rdata = rs485_ctrl;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
