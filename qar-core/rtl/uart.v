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
    localparam MAX_FRAME_BITS = 12;

    function [MAX_FRAME_BITS-1:0] build_tx_frame;
        input [7:0] data_in;
        input       parity_enable_in;
        input       parity_odd_in;
        input       two_stop_in;
        reg [MAX_FRAME_BITS-1:0] frame_tmp;
        reg parity_bit_val;
        integer idx;
        begin
            frame_tmp = {MAX_FRAME_BITS{1'b1}};
            frame_tmp[0] = 1'b0;
            frame_tmp[8:1] = data_in;
            idx = 9;
            if (parity_enable_in) begin
                parity_bit_val = ^data_in;
                if (parity_odd_in)
                    parity_bit_val = ~parity_bit_val;
                frame_tmp[idx] = parity_bit_val;
                idx = idx + 1;
            end
            frame_tmp[idx] = 1'b1;
            idx = idx + 1;
            if (two_stop_in)
                frame_tmp[idx] = 1'b1;
            build_tx_frame = frame_tmp;
        end
    endfunction

    function [4:0] calc_frame_bits;
        input parity_enable_in;
        input two_stop_in;
        begin
            calc_frame_bits = 5'd9;
            if (parity_enable_in)
                calc_frame_bits = calc_frame_bits + 5'd1;
            if (two_stop_in)
                calc_frame_bits = calc_frame_bits + 5'd2;
            else
                calc_frame_bits = calc_frame_bits + 5'd1;
        end
    endfunction

    function parity_match;
        input [7:0] data_in;
        input       parity_enable_in;
        input       parity_odd_in;
        input       sampled_parity;
        reg expected;
        begin
            if (!parity_enable_in) begin
                parity_match = 1'b1;
            end else begin
                expected = ^data_in;
                if (parity_odd_in)
                    expected = ~expected;
                parity_match = (sampled_parity == expected);
            end
        end
    endfunction

    reg [31:0] ctrl;
    reg [31:0] baud_div;
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [31:0] rs485_ctrl;
    reg [31:0] status;
    reg [31:0] idle_cfg;
    reg [31:0] lin_ctrl;
    reg [31:0] lin_cmd;

    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;
    wire rx_fifo_empty = (rx_head == rx_tail);

    assign irq = |(irq_en & irq_status);

    reg [MAX_FRAME_BITS-1:0] tx_shift;
    reg [4:0]  tx_bits_remaining;
    reg [31:0] tx_counter;

    reg [31:0] rx_counter;
    reg [31:0] idle_counter;
    reg        idle_irq_pending;
    reg        rx_busy;
    reg        rx_sync1, rx_sync2;
    reg [4:0]  rx_bit_index;
    reg [4:0]  rx_total_bits;
    reg [7:0]  rx_data_latch;
    reg        rx_parity_latch;
    reg        rx_parity_enable_latch;
    reg        rx_parity_odd_latch;
    reg        rx_two_stop_latch;
    reg        rx_stop_error;
    reg        rx_start_error;
    reg        lin_break_pending;
    reg        lin_break_active;
    reg [31:0] lin_break_counter;
    reg [31:0] lin_break_tick;
    reg [31:0] lin_rx_low_counter;
    reg [31:0] lin_rx_tick;

    wire ctrl_enable     = ctrl[0];
    wire ctrl_parity_en  = ctrl[1];
    wire ctrl_parity_odd = ctrl[2];
    wire ctrl_two_stop   = ctrl[3];
    wire ctrl_lin_mode   = ctrl[5];
    wire [15:0] lin_break_length = (lin_ctrl[15:0] == 16'd0) ? 16'd13 : lin_ctrl[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl        <= 32'h0000_0001;
            baud_div    <= CLOCK_HZ / 115200;
            irq_en      <= 32'b0;
            irq_status  <= 32'b0;
            rs485_ctrl  <= 32'h0000_0001;
            status      <= 32'b0;
            idle_cfg    <= 32'b0;
            lin_ctrl    <= 32'd13;
            lin_cmd     <= 32'b0;
            tx_head     <= 0;
            tx_tail     <= 0;
            rx_head     <= 0;
            rx_tail     <= 0;
            tx          <= 1'b1;
            tx_shift    <= {MAX_FRAME_BITS{1'b1}};
            tx_bits_remaining <= 0;
            tx_counter  <= 0;
            rx_counter  <= 0;
            idle_counter <= 32'b0;
            idle_irq_pending <= 1'b0;
            rx_busy     <= 1'b0;
            rx_sync1    <= 1'b1;
            rx_sync2    <= 1'b1;
            rx_bit_index<= 0;
            rx_total_bits <= 0;
            rx_data_latch <= 8'b0;
            rx_parity_latch <= 1'b0;
            rx_parity_enable_latch <= 1'b0;
            rx_parity_odd_latch <= 1'b0;
            rx_two_stop_latch <= 1'b0;
            rx_stop_error <= 1'b0;
            rx_start_error <= 1'b0;
            lin_break_pending <= 1'b0;
            lin_break_active  <= 1'b0;
            lin_break_counter <= 32'b0;
            lin_break_tick    <= 32'b0;
            lin_rx_low_counter<= 32'b0;
            lin_rx_tick       <= 32'b0;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;

            if (bus_write) begin
                case (addr_word)
                    4'h0: if (!tx_fifo_full) begin
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
                            status[5] <= 1'b0;
                        end
                        if (wdata[3]) begin
                            status[6] <= 1'b0;
                            idle_irq_pending <= 1'b0;
                            idle_counter <= 32'b0;
                        end
                    end
                    4'h6: rs485_ctrl <= wdata;
                    4'h7: idle_cfg <= wdata;
                    4'h8: lin_ctrl <= wdata;
                    4'h9: begin
                        lin_cmd <= wdata;
                        if (wdata[0]) begin
                            lin_break_pending <= 1'b1;
                            status[7] <= 1'b1;
                            irq_status[4] <= 1'b1;
                        end
                        if (wdata[1]) begin
                            status[7] <= 1'b0;
                            irq_status[4] <= 1'b0;
                        end
                    end
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
            status[4] <= (tx_bits_remaining != 0) || lin_break_active;

            if (ctrl_lin_mode && !lin_break_active && lin_break_pending && ctrl_enable &&
                tx_bits_remaining == 0 && tx_fifo_empty) begin
                lin_break_active <= 1'b1;
                lin_break_pending <= 1'b0;
                lin_break_counter <= 32'b0;
            end

            if (!ctrl_enable) begin
                tx_bits_remaining <= 0;
                tx <= 1'b1;
            end else if (lin_break_active) begin
                tx <= 1'b0;
                tx_bits_remaining <= 0;
                if (lin_break_tick >= baud_div) begin
                    lin_break_tick <= 32'b0;
                    if (lin_break_counter >= lin_break_length) begin
                        lin_break_active <= 1'b0;
                        lin_break_counter <= 32'b0;
                        tx <= 1'b1;
                        status[7] <= 1'b1;
                        irq_status[4] <= 1'b1;
                    end else begin
                        lin_break_counter <= lin_break_counter + 1;
                    end
                end else begin
                    lin_break_tick <= lin_break_tick + 1;
                end
            end else if (tx_bits_remaining == 0) begin
                if (!tx_fifo_empty) begin
                    tx_shift <= build_tx_frame(
                        tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]],
                        ctrl_parity_en,
                        ctrl_parity_odd,
                        ctrl_two_stop);
                    tx_bits_remaining <= calc_frame_bits(ctrl_parity_en, ctrl_two_stop);
                    tx_counter <= 0;
                    tx_tail <= tx_tail + 1;
                end
            end else begin
                if (tx_counter >= baud_div) begin
                    tx_counter <= 0;
                    tx <= tx_shift[0];
                    tx_shift <= {1'b1, tx_shift[MAX_FRAME_BITS-1:1]};
                    tx_bits_remaining <= tx_bits_remaining - 1;
                    if (tx_bits_remaining == 1 && tx_fifo_empty)
                        irq_status[1] <= 1'b1;
                end else begin
                    tx_counter <= tx_counter + 1;
                end
            end

            if (!ctrl_enable) begin
                rx_busy <= 1'b0;
                rx_bit_index <= 0;
                idle_counter <= 32'b0;
                idle_irq_pending <= 1'b0;
            end else if (!rx_busy) begin
                if (rx_sync2 == 1'b0) begin
                    rx_busy <= 1'b1;
                    rx_counter <= baud_div >> 1;
                    rx_bit_index <= 0;
                    rx_total_bits <= calc_frame_bits(ctrl_parity_en, ctrl_two_stop);
                    rx_parity_enable_latch <= ctrl_parity_en;
                    rx_parity_odd_latch <= ctrl_parity_odd;
                    rx_two_stop_latch <= ctrl_two_stop;
                    rx_data_latch <= 8'b0;
                    rx_parity_latch <= 1'b0;
                    rx_stop_error <= 1'b0;
                    rx_start_error <= 1'b0;
                    idle_counter <= 32'b0;
                    idle_irq_pending <= 1'b0;
                end else if (idle_cfg != 0) begin
                    if (!idle_irq_pending) begin
                        idle_counter <= idle_counter + 1;
                        if (idle_counter >= idle_cfg) begin
                            idle_irq_pending <= 1'b1;
                            irq_status[3] <= 1'b1;
                            status[6] <= 1'b1;
                        end
                    end
                end else begin
                    idle_counter <= 32'b0;
                end
            end else begin
                if (rx_counter >= baud_div) begin
                    rx_counter <= 0;
                    case (rx_bit_index)
                        0: begin
                            if (rx_sync2 != 1'b0)
                                rx_start_error <= 1'b1;
                        end
                        1: rx_data_latch[0] <= rx_sync2;
                        2: rx_data_latch[1] <= rx_sync2;
                        3: rx_data_latch[2] <= rx_sync2;
                        4: rx_data_latch[3] <= rx_sync2;
                        5: rx_data_latch[4] <= rx_sync2;
                        6: rx_data_latch[5] <= rx_sync2;
                        7: rx_data_latch[6] <= rx_sync2;
                        8: rx_data_latch[7] <= rx_sync2;
                        default: begin
                            if (rx_parity_enable_latch && rx_bit_index == 5'd9) begin
                                rx_parity_latch <= rx_sync2;
                            end else begin
                                if (rx_sync2 != 1'b1)
                                    rx_stop_error <= 1'b1;
                            end
                        end
                    endcase
                    rx_bit_index <= rx_bit_index + 1;
                    if (rx_bit_index == rx_total_bits - 1) begin
                        rx_busy <= 1'b0;
                        if (rx_start_error || rx_stop_error) begin
                            status[2] <= 1'b1;
                            irq_status[2] <= 1'b1;
                        end else if (!parity_match(rx_data_latch, rx_parity_enable_latch, rx_parity_odd_latch, rx_parity_latch)) begin
                            status[5] <= 1'b1;
                            irq_status[2] <= 1'b1;
                        end else if (!rx_fifo_full) begin
                            rx_fifo[rx_head[FIFO_ADDR_BITS-1:0]] <= rx_data_latch;
                            rx_head <= rx_head + 1;
                            irq_status[0] <= 1'b1;
                        end else begin
                            status[3] <= 1'b1;
                            irq_status[2] <= 1'b1;
                        end
                    end
                end else begin
                    rx_counter <= rx_counter + 1;
                end
            end

            if (ctrl_lin_mode && ctrl_enable) begin
                if (rx_sync2 == 1'b0) begin
                    if (lin_rx_tick >= baud_div) begin
                        lin_rx_tick <= 32'b0;
                        if (lin_rx_low_counter < 32'hFFFF)
                            lin_rx_low_counter <= lin_rx_low_counter + 1;
                        if (lin_rx_low_counter >= lin_break_length && !status[7]) begin
                            status[7] <= 1'b1;
                            irq_status[4] <= 1'b1;
                        end
                    end else begin
                        lin_rx_tick <= lin_rx_tick + 1;
                    end
                end else begin
                    lin_rx_low_counter <= 32'b0;
                    lin_rx_tick <= 32'b0;
                end
            end else begin
                lin_rx_low_counter <= 32'b0;
                lin_rx_tick <= 32'b0;
            end
        end
    end

    reg drive_de_raw;
    reg drive_re_raw;

    always @(*) begin
        if (rs485_ctrl[0]) begin
            drive_de_raw = (tx_bits_remaining != 0) || !tx_fifo_empty;
            drive_re_raw = ~drive_de_raw;
        end else begin
            drive_de_raw = rs485_ctrl[3];
            drive_re_raw = rs485_ctrl[4];
        end
        rs485_de = rs485_ctrl[1] ? ~drive_de_raw : drive_de_raw;
        rs485_re = rs485_ctrl[2] ? ~drive_re_raw : drive_re_raw;
    end

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
                4'h7: rdata = idle_cfg;
                4'h8: rdata = lin_ctrl;
                4'h9: rdata = lin_cmd;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
