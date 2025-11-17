`default_nettype none

module qar_i2c #(
    parameter FIFO_DEPTH = 4
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bus_write,
    input  wire        bus_read,
    input  wire [5:0]  addr_word,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        irq,
    output wire        scl,
    output wire        sda_out,
    input  wire        sda_in,
    output wire        sda_oe
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam FIFO_ADDR_BITS = clog2(FIFO_DEPTH);

    reg [31:0] ctrl;
    reg [31:0] clkdiv;
    reg [31:0] status;
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [31:0] cmd_reg;

    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;
    wire rx_fifo_empty = (rx_head == rx_tail);

    reg        busy;
    reg        scl_state;
    reg        sda_state;
    reg        sda_drive;
    reg [3:0]  bit_index;
    reg [7:0]  shift_reg;
    reg [15:0] div_counter;
    reg        awaiting_ack;
    reg        read_cycle;

    assign scl    = scl_state ? 1'b1 : 1'b0;
    assign sda_out = sda_state;
    assign sda_oe = sda_drive;

    wire ctrl_enable = ctrl[0];

    assign irq = |(irq_en & irq_status);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl        <= 32'h1;
            clkdiv      <= 32'd100;
            status      <= 32'h0;
            irq_en      <= 32'h0;
            irq_status  <= 32'h0;
            cmd_reg     <= 32'h0;
            tx_head     <= 0;
            tx_tail     <= 0;
            rx_head     <= 0;
            rx_tail     <= 0;
            busy        <= 1'b0;
            scl_state   <= 1'b1;
            sda_state   <= 1'b1;
            sda_drive   <= 1'b0;
            bit_index   <= 4'd0;
            shift_reg   <= 8'h0;
            div_counter <= 16'd0;
            awaiting_ack<= 1'b0;
            read_cycle  <= 1'b0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    6'h0: ctrl <= wdata;
                    6'h1: status <= status & ~wdata;
                    6'h2: clkdiv <= wdata;
                    6'h3: begin
                        if (!tx_fifo_full) begin
                            tx_fifo[tx_head[FIFO_ADDR_BITS-1:0]] <= wdata[7:0];
                            tx_head <= tx_head + 1;
                        end
                    end
                    6'h4: cmd_reg <= wdata;
                    6'h5: irq_en <= wdata;
                    6'h6: irq_status <= irq_status & ~wdata;
                    default: ;
                endcase
            end

            if (bus_read && addr_word == 6'h3 && !rx_fifo_empty) begin
                rx_tail <= rx_tail + 1;
                if ((rx_head - (rx_tail + 1)) == 0)
                    irq_status[0] <= 1'b0;
            end

            if (ctrl_enable && !busy) begin
                if (cmd_reg[0]) begin // START
                    busy      <= 1'b1;
                    sda_drive <= 1'b1;
                    sda_state <= 1'b0;
                    scl_state <= 1'b1;
                    cmd_reg[0] <= 1'b0;
                end else if (cmd_reg[2] && !tx_fifo_empty) begin // WRITE
                    shift_reg <= tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]];
                    tx_tail   <= tx_tail + 1;
                    bit_index <= 4'd7;
                    read_cycle<= 1'b0;
                    awaiting_ack <= 1'b0;
                    sda_drive <= 1'b1;
                    scl_state <= 1'b0;
                    busy <= 1'b1;
                end else if (cmd_reg[1]) begin // STOP
                    busy <= 1'b1;
                    sda_drive <= 1'b1;
                    sda_state <= 1'b0;
                    scl_state <= 1'b1;
                    cmd_reg[1] <= 1'b0;
                end else if (cmd_reg[3]) begin // READ
                    bit_index <= 4'd7;
                    read_cycle <= 1'b1;
                    awaiting_ack <= 1'b0;
                    sda_drive <= 1'b0;
                    scl_state <= 1'b0;
                    busy <= 1'b1;
                end
            end

            if (busy) begin
                if (div_counter >= clkdiv[15:0]) begin
                    div_counter <= 16'd0;
                    scl_state <= ~scl_state;
                    if (scl_state) begin
                        if (!awaiting_ack && bit_index == 4'd15) begin
                            busy <= 1'b0;
                            sda_drive <= 1'b0;
                            scl_state <= 1'b1;
                            if (read_cycle && !rx_fifo_full) begin
                                rx_fifo[rx_head[FIFO_ADDR_BITS-1:0]] <= shift_reg;
                                rx_head <= rx_head + 1;
                                irq_status[0] <= 1'b1;
                            end
                        end else begin
                            if (!awaiting_ack)
                                bit_index <= bit_index - 1;
                            awaiting_ack <= (bit_index == 4'd0);
                        end
                    end else begin
                        if (!read_cycle) begin
                            sda_drive <= 1'b1;
                            sda_state <= shift_reg[bit_index];
                        end else begin
                            sda_drive <= 1'b0;
                            if (!scl_state)
                                shift_reg[bit_index] <= sda_in;
                        end
                    end
                end else begin
                    div_counter <= div_counter + 1;
                end
            end else begin
                div_counter <= 16'd0;
            end
        end
    end

    always @(*) begin
        rdata = 32'h0;
        if (bus_read) begin
            case (addr_word)
                6'h0: rdata = ctrl;
                6'h1: rdata = status;
                6'h2: rdata = clkdiv;
                6'h3: rdata = {24'b0, rx_fifo[rx_tail[FIFO_ADDR_BITS-1:0]]};
                6'h4: rdata = cmd_reg;
                6'h5: rdata = irq_en;
                6'h6: rdata = irq_status;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
