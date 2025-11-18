`default_nettype none

module qar_adc #(
    parameter integer CHANNELS = 4,
    parameter integer WIDTH    = 12,
    parameter integer CONV_LATENCY = 8
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     bus_write,
    input  wire                     bus_read,
    input  wire [4:0]               addr_word,
    input  wire [31:0]              wdata,
    output reg  [31:0]              rdata,
    input  wire [WIDTH-1:0]         ch0,
    input  wire [WIDTH-1:0]         ch1,
    input  wire [WIDTH-1:0]         ch2,
    input  wire [WIDTH-1:0]         ch3,
    output wire                     irq
);

    localparam integer CH_BITS = 2;

    reg        ctrl_enable;
    reg        ctrl_continuous;
    reg [CH_BITS-1:0] ctrl_channel;
    reg        manual_start_pending;

    reg [CHANNELS-1:0] seq_mask;
    reg [15:0]         sample_div;
    reg [15:0]         sample_counter;
    reg [CH_BITS-1:0]  seq_channel;

    reg        busy;
    reg [CH_BITS-1:0] active_channel;
    reg [WIDTH-1:0]   sample_hold;
    reg [7:0]         conv_counter;

    reg        data_valid;
    reg [WIDTH-1:0] result_value;
    reg [CH_BITS-1:0] result_channel;
    reg        data_overrun;

    reg [31:0] irq_en;
    reg [31:0] irq_status;

    wire [15:0] effective_sample_div = (sample_div == 16'd0) ? 16'd1 : sample_div;
    wire continuous_ready = ctrl_enable && ctrl_continuous && (seq_mask != 0);

    assign irq = |(irq_en & irq_status);

    function [WIDTH-1:0] channel_value;
        input [CH_BITS-1:0] idx;
        begin
            case (idx)
                2'd0: channel_value = ch0;
                2'd1: channel_value = ch1;
                2'd2: channel_value = ch2;
                default: channel_value = ch3;
            endcase
        end
    endfunction

    function [CH_BITS-1:0] first_channel;
        input [CHANNELS-1:0] mask;
        begin
            if (mask[0]) first_channel = 2'd0;
            else if (mask[1]) first_channel = 2'd1;
            else if (mask[2]) first_channel = 2'd2;
            else first_channel = 2'd3;
        end
    endfunction

    function [CH_BITS-1:0] next_channel;
        input [CHANNELS-1:0] mask;
        input [CH_BITS-1:0]  curr;
        begin
            case (curr)
                2'd0: begin
                    if (mask[1]) next_channel = 2'd1;
                    else if (mask[2]) next_channel = 2'd2;
                    else if (mask[3]) next_channel = 2'd3;
                    else next_channel = 2'd0;
                end
                2'd1: begin
                    if (mask[2]) next_channel = 2'd2;
                    else if (mask[3]) next_channel = 2'd3;
                    else if (mask[0]) next_channel = 2'd0;
                    else next_channel = 2'd1;
                end
                2'd2: begin
                    if (mask[3]) next_channel = 2'd3;
                    else if (mask[0]) next_channel = 2'd0;
                    else if (mask[1]) next_channel = 2'd1;
                    else next_channel = 2'd2;
                end
                default: begin
                    if (mask[0]) next_channel = 2'd0;
                    else if (mask[1]) next_channel = 2'd1;
                    else if (mask[2]) next_channel = 2'd2;
                    else next_channel = 2'd3;
                end
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_enable          <= 1'b0;
            ctrl_continuous      <= 1'b0;
            ctrl_channel         <= {CH_BITS{1'b0}};
            manual_start_pending <= 1'b0;
            seq_mask             <= 4'b0001;
            sample_div           <= 16'd16;
            sample_counter       <= 16'd0;
            seq_channel          <= 2'd0;
            busy                 <= 1'b0;
            active_channel       <= 2'd0;
            sample_hold          <= {WIDTH{1'b0}};
            conv_counter         <= 8'd0;
            data_valid           <= 1'b0;
            result_value         <= {WIDTH{1'b0}};
            result_channel       <= {CH_BITS{1'b0}};
            data_overrun         <= 1'b0;
            irq_en               <= 32'b0;
            irq_status           <= 32'b0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    5'h0: begin
                        ctrl_enable     <= wdata[0];
                        ctrl_continuous <= wdata[1];
                        ctrl_channel    <= wdata[5:4];
                        if (wdata[2])
                            manual_start_pending <= 1'b1;
                    end
                    5'h3: irq_en <= wdata;
                    5'h4: begin
                        irq_status <= irq_status & ~wdata;
                        if (wdata[1])
                            data_overrun <= 1'b0;
                        if (wdata[0])
                            data_valid <= 1'b0;
                    end
                    5'h5: begin
                        seq_mask <= wdata[CHANNELS-1:0];
                        seq_channel <= first_channel(wdata[CHANNELS-1:0]);
                    end
                    5'h6: sample_div <= wdata[15:0];
                    default: ;
                endcase
            end

            if (bus_read && addr_word == 5'h2) begin
                data_valid <= 1'b0;
                irq_status[0] <= 1'b0;
            end

            if (!ctrl_continuous)
                sample_counter <= 16'd0;

            if (!busy) begin
                if (manual_start_pending && ctrl_enable) begin
                    manual_start_pending <= 1'b0;
                    busy           <= 1'b1;
                    active_channel <= ctrl_channel;
                    sample_hold    <= channel_value(ctrl_channel);
                    conv_counter   <= 8'd0;
                    data_valid     <= 1'b0;
                end else if (continuous_ready) begin
                    if (seq_mask == 0) begin
                        sample_counter <= 16'd0;
                    end else if (sample_counter >= effective_sample_div) begin
                        sample_counter <= 16'd0;
                        busy           <= 1'b1;
                        active_channel <= seq_channel;
                        sample_hold    <= channel_value(seq_channel);
                        conv_counter   <= 8'd0;
                        data_valid     <= 1'b0;
                        seq_channel    <= next_channel(seq_mask, seq_channel);
                    end else begin
                        sample_counter <= sample_counter + 1;
                    end
                end else begin
                    sample_counter <= 16'd0;
                end
            end else begin
                if (conv_counter >= (CONV_LATENCY - 1)) begin
                    busy         <= 1'b0;
                    result_value <= sample_hold;
                    result_channel <= active_channel;
                    if (data_valid) begin
                        data_overrun <= 1'b1;
                        irq_status[1] <= 1'b1;
                    end
                    data_valid   <= 1'b1;
                    irq_status[0] <= 1'b1;
                    conv_counter <= 8'd0;
                end else begin
                    conv_counter <= conv_counter + 1;
                end
            end
        end
    end

    always @(*) begin
        rdata = 32'b0;
        if (bus_read) begin
            case (addr_word)
                5'h0: rdata = {26'b0, ctrl_channel, ctrl_continuous, ctrl_enable};
                5'h1: rdata = {28'b0, data_overrun, continuous_ready, data_valid, busy};
                5'h2: rdata = {12'b0, result_channel, 4'b0, result_value};
                5'h3: rdata = irq_en;
                5'h4: rdata = irq_status;
                5'h5: rdata = {28'b0, seq_mask};
                5'h6: rdata = {16'b0, sample_div};
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
