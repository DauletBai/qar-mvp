`default_nettype none

module qar_can #(
    parameter CLK_HZ = 50_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bus_write,
    input  wire        bus_read,
    input  wire [5:0]  addr_word,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        irq
);

    reg [31:0] ctrl;
    reg [31:0] status;
    reg [31:0] bittime;
    reg [31:0] err_counter;
    reg [31:0] irq_en;
    reg [31:0] irq_status;
    reg [31:0] filter_id;
    reg [31:0] filter_mask;
    reg [31:0] tx_id;
    reg [31:0] tx_dlc;
    reg [31:0] tx_data0;
    reg [31:0] tx_data1;
    reg [31:0] rx_fifo_id [0:3];
    reg [31:0] rx_fifo_dlc[0:3];
    reg [31:0] rx_fifo_data0[0:3];
    reg [31:0] rx_fifo_data1[0:3];
    reg [2:0]  rx_head;
    reg [2:0]  rx_tail;
    wire [2:0] rx_entries = rx_head - rx_tail;

    assign irq = |(irq_en & irq_status);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl        <= 32'h1;
            status      <= 32'h2;
            bittime     <= 32'h0000_0013;
            err_counter <= 32'h0;
            irq_en      <= 32'h0;
            irq_status  <= 32'h0;
            filter_id   <= 32'h0;
            filter_mask <= 32'h0;
            tx_id       <= 32'h0;
            tx_dlc      <= 32'h0;
            tx_data0    <= 32'h0;
            tx_data1    <= 32'h0;
            rx_head     <= 0;
            rx_tail     <= 0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    6'h0: ctrl <= wdata;
                    6'h2: bittime <= wdata;
                    6'h3: err_counter <= wdata;
                    6'h4: irq_en <= wdata;
                    6'h5: begin
                        irq_status <= irq_status & ~wdata;
                        if (wdata[0])
                            status[0] <= 1'b0;
                        if (wdata[1])
                            status[1] <= 1'b1;
                    end
                    6'h6: filter_id <= wdata;
                    6'h7: filter_mask <= wdata;
                    6'h8: tx_id <= wdata;
                    6'h9: tx_dlc <= wdata;
                    6'hA: tx_data0 <= wdata;
                    6'hB: tx_data1 <= wdata;
                    6'hC: begin
                        if (ctrl[0]) begin
                            status[1] <= 1'b0;
                            if (ctrl[1] && ((tx_id & filter_mask) == (filter_id & filter_mask))) begin
                                if (rx_entries < 4) begin
                                    rx_fifo_id[rx_head[1:0]]    <= tx_id;
                                    rx_fifo_dlc[rx_head[1:0]]   <= tx_dlc;
                                    rx_fifo_data0[rx_head[1:0]] <= tx_data0;
                                    rx_fifo_data1[rx_head[1:0]] <= tx_data1;
                                    rx_head <= rx_head + 1;
                                    status[0] <= 1'b1;
                                    irq_status[0] <= 1'b1;
                                end else begin
                                    err_counter <= err_counter + 1;
                                    status[2] <= 1'b1;
                                    irq_status[2] <= 1'b1;
                                end
                            end
                            status[1] <= 1'b1;
                            irq_status[1] <= 1'b1;
                        end
                    end
                    6'h11: begin
                        if (wdata[1]) begin
                            rx_tail <= rx_head;
                            status[0] <= 1'b0;
                        end else if (wdata[0] && rx_entries != 0) begin
                            rx_tail <= rx_tail + 1;
                            if (rx_entries == 1)
                                status[0] <= 1'b0;
                        end
                        if (wdata[2]) begin
                            status[2] <= 1'b0;
                            irq_status[2] <= 1'b0;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        if (!bus_read) begin
            rdata = 32'b0;
        end else begin
            case (addr_word)
                6'h0: rdata = ctrl;
                6'h1: rdata = status;
                6'h2: rdata = bittime;
                6'h3: rdata = err_counter;
                6'h4: rdata = irq_en;
                6'h5: rdata = irq_status;
                6'h6: rdata = filter_id;
                6'h7: rdata = filter_mask;
                6'h8: rdata = tx_id;
                6'h9: rdata = tx_dlc;
                6'hA: rdata = tx_data0;
                6'hB: rdata = tx_data1;
                6'hD: rdata = rx_fifo_id[rx_tail[1:0]];
                6'hE: rdata = rx_fifo_dlc[rx_tail[1:0]];
                6'hF: rdata = rx_fifo_data0[rx_tail[1:0]];
                6'h10:rdata = rx_fifo_data1[rx_tail[1:0]];
                6'h11:rdata = {28'b0, status[2], 1'b0, rx_entries};
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
