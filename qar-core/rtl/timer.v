`default_nettype none

module qar_timer #(
    parameter CLK_HZ = 50_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bus_write,
    input  wire        bus_read,
    input  wire [5:0]  addr_word,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        irq,
    output wire        pwm0,
    output wire        pwm1
);

    reg [31:0] ctrl;
    reg [31:0] prescale;
    reg [31:0] counter;
    reg [31:0] status;
    reg [31:0] irq_en;
    reg [31:0] cmp0;
    reg [31:0] cmp0_period;
    reg [31:0] cmp1;
    reg [31:0] cmp1_period;
    reg [31:0] wdt_load;
    reg [31:0] wdt_counter;
    reg        wdt_enable;
    reg [31:0] pwm0_period;
    reg [31:0] pwm0_duty;
    reg [31:0] pwm1_period;
    reg [31:0] pwm1_duty;
    reg [31:0] capture_ctrl;
    reg [31:0] capture0_value;
    reg [31:0] capture1_value;
    reg [31:0] pwm0_counter;
    reg [31:0] pwm1_counter;
    reg        pwm0_out;
    reg        pwm1_out;

    reg [31:0] prescale_cnt;

    wire counter_enable     = ctrl[0];
    wire cmp0_auto_reload   = ctrl[1];
    wire cmp1_auto_reload   = ctrl[2];

    assign irq = |(status & irq_en);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl         <= 32'h0;
            prescale     <= 32'h0;
            counter      <= 32'h0;
            status       <= 32'h0;
            irq_en       <= 32'h0;
            cmp0         <= 32'h0;
            cmp0_period  <= 32'h0;
            cmp1         <= 32'h0;
            cmp1_period  <= 32'h0;
            wdt_load     <= 32'h0;
            wdt_counter  <= 32'h0;
            wdt_enable   <= 1'b0;
            pwm0_period  <= 32'h0;
            pwm0_duty    <= 32'h0;
            pwm1_period  <= 32'h0;
            pwm1_duty    <= 32'h0;
            capture_ctrl <= 32'h0;
            capture0_value <= 32'h0;
            capture1_value <= 32'h0;
            pwm0_counter <= 32'h0;
            pwm1_counter <= 32'h0;
            pwm0_out     <= 1'b0;
            pwm1_out     <= 1'b0;
            prescale_cnt <= 32'h0;
        end else begin
            // Register writes
            if (bus_write) begin
                case (addr_word)
                    6'h0: ctrl <= wdata;
                    6'h1: prescale <= wdata;
                    6'h2: counter <= wdata;
                    6'h3: status <= status & ~wdata;
                    6'h4: irq_en <= wdata;
                    6'h5: cmp0 <= wdata;
                    6'h6: cmp0_period <= wdata;
                    6'h7: cmp1 <= wdata;
                    6'h8: cmp1_period <= wdata;
                    6'h9: begin
                        wdt_load <= wdata;
                        if (wdt_enable) begin
                            wdt_counter <= wdata;
                            status[2] <= 1'b0;
                        end
                    end
                    6'hA: begin
                        if (!wdt_enable && wdata[0]) begin
                            wdt_counter <= wdt_load;
                            status[2] <= 1'b0;
                        end
                        wdt_enable <= wdata[0];
                        if (wdata[1]) begin
                            wdt_counter <= wdt_load;
                            status[2] <= 1'b0;
                        end
                    end
                    6'hC: begin
                        pwm0_period  <= wdata;
                        pwm0_counter <= 32'h0;
                    end
                    6'hD: pwm0_duty <= wdata;
                    6'hE: begin
                        pwm1_period  <= wdata;
                        pwm1_counter <= 32'h0;
                    end
                    6'hF: pwm1_duty <= wdata;
                    6'h11: begin
                        capture_ctrl <= wdata;
                        if (wdata[0]) begin
                            capture0_value <= counter;
                            status[3] <= 1'b1;
                        end
                        if (wdata[1]) begin
                            capture1_value <= counter;
                            status[4] <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            // Counter tick
            if (counter_enable) begin
                if (prescale_cnt >= prescale) begin
                    prescale_cnt <= 32'h0;
                    counter <= counter + 1;

                    if (wdt_enable && wdt_counter != 32'h0) begin
                        wdt_counter <= wdt_counter - 1;
                        if (wdt_counter == 32'h1) begin
                            status[2] <= 1'b1;
                        end
                    end

                    if (cmp0 != 32'h0 && counter == cmp0) begin
                        status[0] <= 1'b1;
                        if (cmp0_auto_reload && cmp0_period != 32'h0)
                            cmp0 <= cmp0 + cmp0_period;
                    end
                    if (cmp1 != 32'h0 && counter == cmp1) begin
                        status[1] <= 1'b1;
                        if (cmp1_auto_reload && cmp1_period != 32'h0)
                            cmp1 <= cmp1 + cmp1_period;
                    end

                    if (pwm0_period != 32'h0) begin
                        if (pwm0_counter + 1 >= pwm0_period)
                            pwm0_counter <= 32'h0;
                        else
                            pwm0_counter <= pwm0_counter + 1;
                    end else begin
                        pwm0_counter <= 32'h0;
                    end

                    if (pwm1_period != 32'h0) begin
                        if (pwm1_counter + 1 >= pwm1_period)
                            pwm1_counter <= 32'h0;
                        else
                            pwm1_counter <= pwm1_counter + 1;
                    end else begin
                        pwm1_counter <= 32'h0;
                    end

                    pwm0_out <= (pwm0_period != 32'h0) && (pwm0_counter < pwm0_duty);
                    pwm1_out <= (pwm1_period != 32'h0) && (pwm1_counter < pwm1_duty);
                end else begin
                    prescale_cnt <= prescale_cnt + 1;
                end
            end else begin
                prescale_cnt <= 32'h0;
                pwm0_counter <= 32'h0;
                pwm1_counter <= 32'h0;
                pwm0_out <= (pwm0_period != 32'h0) && (pwm0_duty != 32'h0);
                pwm1_out <= (pwm1_period != 32'h0) && (pwm1_duty != 32'h0);
            end
        end
    end

    always @(*) begin
        if (!bus_read) begin
            rdata = 32'h0;
        end else begin
            case (addr_word)
                6'h0: rdata = ctrl;
                6'h1: rdata = prescale;
                6'h2: rdata = counter;
                6'h3: rdata = status;
                6'h4: rdata = irq_en;
                6'h5: rdata = cmp0;
                6'h6: rdata = cmp0_period;
                6'h7: rdata = cmp1;
                6'h8: rdata = cmp1_period;
                6'h9: rdata = wdt_load;
                6'hA: rdata = {31'b0, wdt_enable};
                6'hB: rdata = wdt_counter;
                6'hC: rdata = pwm0_period;
                6'hD: rdata = pwm0_duty;
                6'hE: rdata = pwm1_period;
                6'hF: rdata = pwm1_duty;
                6'h10: rdata = {30'b0, pwm1_out, pwm0_out};
                6'h11: rdata = capture_ctrl;
                6'h12: rdata = capture0_value;
                6'h13: rdata = capture1_value;
                default: rdata = 32'h0;
            endcase
        end
    end

    assign pwm0 = pwm0_out;
    assign pwm1 = pwm1_out;

endmodule

`default_nettype wire
