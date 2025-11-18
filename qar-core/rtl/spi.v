`default_nettype none

module qar_spi #(
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
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire [3:0]  spi_cs_n
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
    reg [31:0] cs_select;
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [3:0]  cs_active;
    reg [3:0]  cs_auto_count;
    reg        tx_overflow_flag;
    reg        rx_overflow_flag;
    reg        cs_error_flag;

    reg [FIFO_ADDR_BITS:0] tx_head, tx_tail;
    reg [7:0]  tx_fifo [0:FIFO_DEPTH-1];
    reg [FIFO_ADDR_BITS:0] rx_head, rx_tail;
    reg [7:0]  rx_fifo [0:FIFO_DEPTH-1];

    wire tx_fifo_full  = (tx_head - tx_tail) == FIFO_DEPTH;
    wire tx_fifo_empty = (tx_head == tx_tail);
    wire rx_fifo_empty = (rx_head == rx_tail);
    wire rx_fifo_full  = (rx_head - rx_tail) == FIFO_DEPTH;

    reg        busy;
    reg [7:0]  tx_shift;
    reg [7:0]  active_tx_byte;
    reg [7:0]  rx_shift;
    reg [2:0]  bit_index;
    reg [15:0] div_counter;
    reg        sck_phase;

    wire       ctrl_enable   = ctrl[0];
    wire       ctrl_cpol     = ctrl[1];
    wire       ctrl_cpha     = ctrl[2];
    wire       ctrl_lsb      = ctrl[3];
    wire       ctrl_loopback = ctrl[4];

    wire [15:0] effective_div = (clkdiv[15:0] == 16'd0) ? 16'd1 : clkdiv[15:0];

    assign spi_sck  = ctrl_cpol ^ (busy ? sck_phase : 1'b0);
    assign spi_mosi = busy ? (ctrl_lsb ? tx_shift[0] : tx_shift[7]) : 1'b0;
    assign spi_cs_n = ~(busy ? cs_active : 4'b0000) | 4'b1111;

    wire tx_ready = !tx_fifo_full;
    wire rx_ready = !rx_fifo_empty;
    wire fault_flag = tx_overflow_flag | rx_overflow_flag | cs_error_flag;

    wire [31:0] status_value = {25'b0, cs_error_flag, rx_overflow_flag, tx_overflow_flag, fault_flag, busy, rx_ready, tx_ready};

    assign irq = |(irq_en[5:0] & irq_status[5:0]);

    wire sample_bit_comb = ctrl_loopback ? (ctrl_lsb ? tx_shift[0] : tx_shift[7]) : spi_miso;
    wire [7:0] rx_shift_combined = ctrl_lsb ?
        {sample_bit_comb, rx_shift[7:1]} :
        {rx_shift[6:0], sample_bit_comb};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl       <= 32'h1;
            clkdiv     <= 32'd1;
            cs_select  <= 32'h1;
            cs_auto_count <= 4'd1;
            irq_en     <= 32'h0;
            irq_status <= 32'h0;
            cs_active  <= 4'b0000;
            tx_overflow_flag <= 1'b0;
            rx_overflow_flag <= 1'b0;
            cs_error_flag <= 1'b0;
            tx_head    <= 0;
            tx_tail    <= 0;
            rx_head    <= 0;
            rx_tail    <= 0;
            busy       <= 1'b0;
            tx_shift   <= 8'h0;
            rx_shift   <= 8'h0;
            bit_index  <= 3'd0;
            div_counter<= 16'd0;
            sck_phase  <= 1'b0;
        end else begin
            // Write handling
            if (bus_write) begin
                case (addr_word)
                    6'h0: ctrl <= wdata;
                    6'h2: clkdiv <= wdata;
                    6'h5: begin
                        cs_select <= wdata;
                        cs_auto_count <= 4'd1;
                    end
                    6'h6: irq_en <= wdata;
                    6'h7: begin
                        irq_status <= irq_status & ~wdata;
                        if (wdata[2]) begin
                            tx_overflow_flag <= 1'b0;
                            rx_overflow_flag <= 1'b0;
                            cs_error_flag <= 1'b0;
                        end
                        if (wdata[3])
                            tx_overflow_flag <= 1'b0;
                        if (wdata[4])
                            rx_overflow_flag <= 1'b0;
                        if (wdata[5])
                            cs_error_flag <= 1'b0;
                    end
                    6'h3: begin
                        if (!tx_fifo_full) begin
                            tx_fifo[tx_head[FIFO_ADDR_BITS-1:0]] <= wdata[7:0];
                            tx_head <= tx_head + 1;
                            irq_status[1] <= 1'b0;
                        end else begin
                            tx_overflow_flag <= 1'b1;
                            irq_status[2] <= 1'b1;
                            irq_status[3] <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            // RX pop on read
            if (bus_read && addr_word == 6'h4 && !rx_fifo_empty) begin
                rx_tail <= rx_tail + 1;
                if ((rx_head - (rx_tail + 1)) == 0)
                    irq_status[0] <= 1'b0;
            end

            // Start transfer
            if (!busy && ctrl_enable && !tx_fifo_empty) begin
                if (cs_select[3:0] == 4'b0000) begin
                    cs_error_flag <= 1'b1;
                    irq_status[2] <= 1'b1;
                    irq_status[5] <= 1'b1;
                end else begin
                    busy      <= 1'b1;
                    cs_active <= cs_select[3:0];
                    cs_auto_count <= ctrl[8+:4];
                    tx_shift  <= tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]];
                    active_tx_byte <= tx_fifo[tx_tail[FIFO_ADDR_BITS-1:0]];
                    rx_shift  <= 8'h0;
                    tx_tail   <= tx_tail + 1;
                    bit_index <= 3'd7;
                    div_counter <= 16'd0;
                    sck_phase <= 1'b0;
                    if ((tx_head - (tx_tail + 1)) == 0)
                        irq_status[1] <= 1'b1;
                end
            end

            // Shifting logic
            if (busy) begin
                if (div_counter >= effective_div) begin
                    div_counter <= 16'd0;
                    sck_phase   <= ~sck_phase;
                    if ((sck_phase ^ ctrl_cpha) == 1'b1) begin
                        rx_shift <= rx_shift_combined;
                        if (bit_index == 3'd0) begin
                            busy <= 1'b0;
                            if (cs_auto_count <= 1)
                                cs_active <= 4'b0000;
                            else
                                cs_auto_count <= cs_auto_count - 1;
                            if (!rx_fifo_full) begin
                                rx_fifo[rx_head[FIFO_ADDR_BITS-1:0]] <= ctrl_loopback ? active_tx_byte : rx_shift_combined;
                                rx_head <= rx_head + 1;
                                irq_status[0] <= 1'b1;
                            end else begin
                                rx_overflow_flag <= 1'b1;
                                irq_status[2] <= 1'b1;
                                irq_status[4] <= 1'b1;
                            end
                        end else begin
                            bit_index <= bit_index - 1;
                        end
                    end else begin
                        if (ctrl_lsb)
                            tx_shift <= {1'b0, tx_shift[7:1]};
                        else
                            tx_shift <= {tx_shift[6:0], 1'b0};
                    end
                end else begin
                    div_counter <= div_counter + 1;
                end
            end else begin
                div_counter <= 16'd0;
                sck_phase   <= 1'b0;
            end
        end
    end

    always @(*) begin
        rdata = 32'h0;
        if (bus_read) begin
            case (addr_word)
                6'h0: rdata = ctrl;
                6'h1: rdata = status_value;
                6'h2: rdata = clkdiv;
                6'h3: rdata = {24'b0, tx_head - tx_tail};
                6'h4: rdata = rx_fifo[rx_tail[FIFO_ADDR_BITS-1:0]];
                6'h5: rdata = cs_select;
                6'h6: rdata = irq_en;
                6'h7: rdata = irq_status;
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
