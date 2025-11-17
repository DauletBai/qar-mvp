`default_nettype none

module qar_uart #(
    parameter FIFO_DEPTH = 4,
    parameter CLOCK_HZ   = 50_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       bus_write,
    input  wire       bus_read,
    input  wire [3:0] addr_word,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg        tx,
    input  wire       rx,
    output wire       irq
);

    localparam FIFO_ADDR_BITS = $clog2(FIFO_DEPTH);

    reg [31:0] ctrl;
    reg [31:0] baud_div;
    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [31:0] status;
    reg [31:0] irq_en;
    reg [31:0] irq_status;

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;
    wire rx_fifo_empty = (rx_head == rx_tail);

    assign irq = |(irq_en & irq_status);

    // Simple transmit state
    reg [9:0] tx_shift;
    reg [3:0] tx_bitcount;
    reg [31:0] tx_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl       <= 32'b0;
            baud_div   <= CLOCK_HZ / 115200;
            status     <= 32'b0;
            irq_en     <= 32'b0;
            irq_status <= 32'b0;
            tx_head    <= 0;
            tx_tail    <= 0;
            rx_head    <= 0;
            rx_tail    <= 0;
            tx         <= 1'b1;
            tx_shift   <= 10'b1111111111;
            tx_bitcount<= 4'd0;
            tx_counter <= 0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    4'h0: if (!tx_fifo_full) begin
                        tx_fifo[tx_head[FIFO_ADDR_BITS-1:0]] <= wdata[7:0];
                        tx_head <= tx_head + 1;
                    end
                    4'h2: ctrl <= wdata;
                    4'h3: baud_div <= wdata;
                    4'h4: irq_en <= wdata;
                    4'h5: irq_status <= irq_status & ~wdata;
                endcase
            end

            if (bus_read) begin
                if (addr_word == 4'h0 && !rx_fifo_empty) begin
                    rx_tail <= rx_tail + 1;
                end
            end

            status[1] <= !tx_fifo_full;
            status[0] <= !rx_fifo_empty;

            // Transmitter
            if (tx_bitcount == 0) begin
                if (!tx_fifo_empty) begin
                    tx_shift   <= {1'b1, tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]], 1'b0};
                    tx_bitcount<= 4'd10;
                    tx_counter <= 32'b0;
                    tx_tail    <= tx_tail + 1;
                end
            end else begin
                if (tx_counter >= baud_div) begin
                    tx_counter <= 0;
                    tx         <= tx_shift[0];
                    tx_shift   <= {1'b1, tx_shift[9:1]};
                    tx_bitcount<= tx_bitcount - 1;
                    if (tx_bitcount == 1)
                        irq_status[1] <= 1'b1; // TX empty
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end

            // RX sampling omitted (placeholder)
            status[2] <= 1'b0;
        end
    end

    always @(*) begin
        rdata = 32'b0;
        if (bus_read) begin
            case (addr_word)
                4'h0: rdata = {{24{1'b0}}, rx_fifo[rx_tail[FIFO_ADDR_BITS-1:0]]};
                4'h1: rdata = status;
                4'h2: rdata = ctrl;
                4'h3: rdata = baud_div;
                4'h4: rdata = irq_en;
                4'h5: rdata = irq_status;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
