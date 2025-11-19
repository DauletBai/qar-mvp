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
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [31:0] cmd_reg;
    reg        ack_error_flag;
    reg        rx_overflow_flag;
    reg        tx_overflow_flag;
    reg [2:0]  last_fault_code;
    reg [2:0]  last_fault_cmd;
    reg [7:0]  last_fault_byte;

    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;
    wire rx_fifo_empty = (rx_head == rx_tail);

    reg [2:0]  state;
    reg        scl_state;
    reg        sda_state;
    reg        sda_drive;
    reg [3:0]  bit_index;
    reg [7:0]  shift_reg;
    reg [15:0] div_counter;

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_START = 3'd1;
    localparam STATE_WRITE = 3'd2;
    localparam STATE_ACK   = 3'd3;
    localparam STATE_READ  = 3'd4;
    localparam STATE_STOP  = 3'd5;

    assign scl    = scl_state;
    assign sda_out = sda_state;
    assign sda_oe = sda_drive;

    wire ctrl_enable   = ctrl[0];
    wire ctrl_loopback = ctrl[4];

    assign irq = |(irq_en[5:0] & irq_status[5:0]);

    wire busy_flag    = (state != STATE_IDLE);
    wire rx_ready_flag = (rx_head != rx_tail);
    wire tx_empty_flag = (tx_head == tx_tail);

    wire [31:0] status_value = {26'b0, tx_overflow_flag, rx_overflow_flag, ack_error_flag, tx_empty_flag, rx_ready_flag, busy_flag};
    wire [31:0] fault_status_value = {8'b0, last_fault_byte, 4'b0, last_fault_cmd, last_fault_code, ack_error_flag, rx_overflow_flag, tx_overflow_flag, 3'b0};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl        <= 32'h1;
            clkdiv      <= 32'd100;
            irq_en      <= 32'h0;
            irq_status  <= 32'h0;
            cmd_reg     <= 32'h0;
            ack_error_flag <= 1'b0;
            rx_overflow_flag <= 1'b0;
            tx_overflow_flag <= 1'b0;
            last_fault_code <= 3'd0;
            last_fault_cmd  <= 3'd0;
            last_fault_byte <= 8'd0;
            tx_head     <= 0;
            tx_tail     <= 0;
            rx_head     <= 0;
            rx_tail     <= 0;
            state       <= STATE_IDLE;
            scl_state   <= 1'b1;
            sda_state   <= 1'b1;
            sda_drive   <= 1'b0;
            bit_index   <= 4'd0;
            shift_reg   <= 8'h0;
            div_counter <= 16'd0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    6'h0: ctrl <= wdata;
                    6'h1: clkdiv <= wdata;
                    6'h2: begin
                        if (wdata[3])
                            ack_error_flag <= 1'b0;
                        if (wdata[4])
                            rx_overflow_flag <= 1'b0;
                        if (wdata[5])
                            tx_overflow_flag <= 1'b0;
                    end
                    6'h3: irq_en <= wdata;
                    6'h4: begin
                        irq_status <= irq_status & ~wdata;
                        if (wdata[2]) begin
                            ack_error_flag <= 1'b0;
                            rx_overflow_flag <= 1'b0;
                            tx_overflow_flag <= 1'b0;
                        end
                        if (wdata[3])
                            tx_overflow_flag <= 1'b0;
                        if (wdata[4])
                            rx_overflow_flag <= 1'b0;
                        if (wdata[5])
                            ack_error_flag <= 1'b0;
                    end
                    6'h5: begin
                        if (!tx_fifo_full) begin
                            tx_fifo[tx_head[FIFO_ADDR_BITS-1:0]] <= wdata[7:0];
                            tx_head <= tx_head + 1;
                            irq_status[1] <= 1'b0;
                        end else begin
                            tx_overflow_flag <= 1'b1;
                            irq_status[2] <= 1'b1;
                            irq_status[3] <= 1'b1;
                            last_fault_code <= 3'd1;
                            last_fault_cmd <= 3'd2;
                            last_fault_byte <= wdata[7:0];
                        end
                    end
                    6'h7: cmd_reg <= wdata;
                    default: ;
                endcase
            end

            if (bus_read && addr_word == 6'h6 && !rx_fifo_empty) begin
                rx_tail <= rx_tail + 1;
                if ((rx_head - (rx_tail + 1)) == 0)
                    irq_status[0] <= 1'b0;
            end
            case (state)
                STATE_IDLE: begin
                    sda_drive <= 1'b0;
                    sda_state <= 1'b1;
                    scl_state <= 1'b1;
                    div_counter <= 16'd0;
                    if (ctrl_enable) begin
                        if (cmd_reg[0]) begin
                            cmd_reg[0] <= 1'b0;
                            sda_drive <= 1'b1;
                            sda_state <= 1'b0;
                            last_fault_cmd <= 3'd1;
                            state <= STATE_START;
                        end else if (cmd_reg[2] && !tx_fifo_empty) begin
                            cmd_reg[2] <= 1'b0;
                            shift_reg <= tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]];
                            tx_tail <= tx_tail + 1;
                            bit_index <= 4'd7;
                            sda_drive <= 1'b1;
                            sda_state <= tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]][7];
                            scl_state <= 1'b0;
                            last_fault_cmd <= 3'd2;
                            state <= STATE_WRITE;
                        end else if (cmd_reg[3]) begin
                            cmd_reg[3] <= 1'b0;
                            bit_index <= 4'd7;
                            sda_drive <= 1'b0;
                            scl_state <= 1'b0;
                            last_fault_cmd <= 3'd3;
                            state <= STATE_READ;
                        end else if (cmd_reg[1]) begin
                            cmd_reg[1] <= 1'b0;
                            sda_drive <= 1'b1;
                            sda_state <= 1'b0;
                            last_fault_cmd <= 3'd4;
                            state <= STATE_STOP;
                        end
                    end
                end
                STATE_START: begin
                    if (div_counter >= clkdiv[15:0]) begin
                        div_counter <= 16'd0;
                        sda_state <= 1'b0;
                        scl_state <= 1'b0;
                        state <= STATE_IDLE;
                    end else begin
                        div_counter <= div_counter + 1;
                    end
                end
                STATE_WRITE: begin
                    if (div_counter >= clkdiv[15:0]) begin
                        div_counter <= 16'd0;
                        scl_state <= ~scl_state;
                        if (scl_state) begin
                            if (bit_index == 4'd0) begin
                                sda_drive <= 1'b0;
                                state <= STATE_ACK;
                            end else begin
                                bit_index <= bit_index - 1;
                                sda_state <= shift_reg[bit_index-1];
                            end
                        end
                    end else begin
                        div_counter <= div_counter + 1;
                    end
                end
                STATE_ACK: begin
                    if (div_counter >= clkdiv[15:0]) begin
                        div_counter <= 16'd0;
                        scl_state <= ~scl_state;
                        if (scl_state) begin
                            if (!(ctrl_loopback ? 1'b0 : sda_in)) begin
                                ack_error_flag <= 1'b0;
                            end else begin
                                ack_error_flag <= 1'b1;
                                irq_status[2] <= 1'b1;
                                irq_status[5] <= 1'b1;
                                last_fault_code <= 3'd3;
                                last_fault_byte <= shift_reg;
                            end
                        end else begin
                            state <= STATE_IDLE;
                            if ((tx_head - tx_tail) == 0)
                                irq_status[1] <= 1'b1;
                        end
                    end else begin
                        div_counter <= div_counter + 1;
                    end
                end
                STATE_READ: begin
                    if (div_counter >= clkdiv[15:0]) begin
                        div_counter <= 16'd0;
                        scl_state <= ~scl_state;
                        if (scl_state) begin
                            shift_reg[bit_index] <= ctrl_loopback ? sda_state : sda_in;
                            if (bit_index == 4'd0) begin
                                if (!rx_fifo_full) begin
                                    rx_fifo[rx_head[FIFO_ADDR_BITS-1:0]] <= shift_reg;
                                    rx_head <= rx_head + 1;
                                    irq_status[0] <= 1'b1;
                                end else begin
                                    rx_overflow_flag <= 1'b1;
                                    irq_status[2] <= 1'b1;
                                    irq_status[4] <= 1'b1;
                                    last_fault_code <= 3'd2;
                                    last_fault_byte <= shift_reg;
                                end
                                state <= STATE_IDLE;
                            end else begin
                                bit_index <= bit_index - 1;
                            end
                        end
                    end else begin
                        div_counter <= div_counter + 1;
                    end
                end
                STATE_STOP: begin
                    if (div_counter >= clkdiv[15:0]) begin
                        div_counter <= 16'd0;
                        scl_state <= 1'b1;
                        sda_state <= 1'b1;
                        state <= STATE_IDLE;
                    end else begin
                        div_counter <= div_counter + 1;
                    end
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end

    always @(*) begin
        rdata = 32'h0;
        if (bus_read) begin
            case (addr_word)
                6'h0: rdata = ctrl;
                6'h1: rdata = clkdiv;
                6'h2: rdata = status_value;
                6'h3: rdata = irq_en;
                6'h4: rdata = irq_status;
                6'h5: rdata = 32'b0;
                6'h6: rdata = {24'b0, rx_fifo[rx_tail[FIFO_ADDR_BITS-1:0]]};
                6'h7: rdata = cmd_reg;
                6'h8: rdata = fault_status_value;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
