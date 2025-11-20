`default_nettype none

module timer_formal_tb;
    reg clk = 0;
    always #1 clk = !clk;

    reg rst_n = 0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg write_en_any;
    (* anyseq *) reg read_en_any;
    (* anyseq *) reg [5:0] addr_any;
    (* anyseq *) reg [31:0] wdata_any;

    wire bus_write = write_en_any;
    wire bus_read  = read_en_any & ~write_en_any;
    wire [5:0] addr_word = addr_any;
    wire [31:0] wdata = wdata_any;

    // Constrain accesses to defined registers.
    always @(*) begin
        assume(addr_word <= 6'h13);
        if (bus_write && addr_word == 6'h0)
            assume(wdata[0] == 1'b0); // keep counter disabled for tractable model
        if (bus_write && addr_word == 6'hA)
            assume(wdata[0] == 1'b0); // keep watchdog disabled
    end

    wire [31:0] rdata;
    wire irq;
    wire pwm0;
    wire pwm1;

    qar_timer uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_write(bus_write),
        .bus_read(bus_read),
        .addr_word(addr_word),
        .wdata(wdata),
        .rdata(rdata),
        .irq(irq),
        .pwm0(pwm0),
        .pwm1(pwm1)
    );

    // Model registers when timer is halted.
    reg [31:0] m_ctrl;
    reg [31:0] m_prescale;
    reg [31:0] m_counter;
    reg [31:0] m_status;
    reg [31:0] m_irq_en;
    reg [31:0] m_cmp0;
    reg [31:0] m_cmp0_period;
    reg [31:0] m_cmp1;
    reg [31:0] m_cmp1_period;
    reg [31:0] m_wdt_load;
    reg        m_wdt_enable;
    reg [31:0] m_wdt_counter;
    reg [31:0] m_pwm0_period;
    reg [31:0] m_pwm0_duty;
    reg [31:0] m_pwm1_period;
    reg [31:0] m_pwm1_duty;
    reg [31:0] m_capture_ctrl;
    reg [31:0] m_capture0_value;
    reg [31:0] m_capture1_value;

    wire irq_expected = |(m_status & m_irq_en);
    wire pwm0_expected = (m_pwm0_period != 32'h0) && (m_pwm0_duty != 32'h0);
    wire pwm1_expected = (m_pwm1_period != 32'h0) && (m_pwm1_duty != 32'h0);

    always @(posedge clk) begin
        if (!rst_n) begin
            m_ctrl          <= 32'h0;
            m_prescale      <= 32'h0;
            m_counter       <= 32'h0;
            m_status        <= 32'h0;
            m_irq_en        <= 32'h0;
            m_cmp0          <= 32'h0;
            m_cmp0_period   <= 32'h0;
            m_cmp1          <= 32'h0;
            m_cmp1_period   <= 32'h0;
            m_wdt_load      <= 32'h0;
            m_wdt_enable    <= 1'b0;
            m_wdt_counter   <= 32'h0;
            m_pwm0_period   <= 32'h0;
            m_pwm0_duty     <= 32'h0;
            m_pwm1_period   <= 32'h0;
            m_pwm1_duty     <= 32'h0;
            m_capture_ctrl  <= 32'h0;
            m_capture0_value<= 32'h0;
            m_capture1_value<= 32'h0;
        end else begin
            if (bus_write) begin
                case (addr_word)
                    6'h0: m_ctrl <= wdata & 32'hFFFFFFFE; // bit0 forced low
                    6'h1: m_prescale <= wdata;
                    6'h2: m_counter <= wdata;
                    6'h3: m_status <= m_status & ~wdata;
                    6'h4: m_irq_en <= wdata;
                    6'h5: m_cmp0 <= wdata;
                    6'h6: m_cmp0_period <= wdata;
                    6'h7: m_cmp1 <= wdata;
                    6'h8: m_cmp1_period <= wdata;
                    6'h9: begin
                        m_wdt_load <= wdata;
                        if (m_wdt_enable)
                            m_wdt_counter <= wdata;
                    end
                    6'hA: begin
                        m_wdt_enable <= 1'b0; // constrained
                        if (wdata[1])
                            m_wdt_counter <= m_wdt_load;
                    end
                    6'hC: m_pwm0_period <= wdata;
                    6'hD: m_pwm0_duty <= wdata;
                    6'hE: m_pwm1_period <= wdata;
                    6'hF: m_pwm1_duty <= wdata;
                    6'h11: begin
                        m_capture_ctrl <= wdata;
                        if (wdata[0]) begin
                            m_capture0_value <= m_counter;
                            m_status[3]      <= 1'b1;
                        end
                        if (wdata[1]) begin
                            m_capture1_value <= m_counter;
                            m_status[4]      <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            assert(uut.ctrl[0] == 1'b0);
        end else begin
            assert(uut.ctrl == m_ctrl);
            assert(uut.prescale == m_prescale);
            assert(uut.counter == m_counter);
            assert(uut.status == m_status);
            assert(uut.irq_en == m_irq_en);
            assert(uut.cmp0 == m_cmp0);
            assert(uut.cmp0_period == m_cmp0_period);
            assert(uut.cmp1 == m_cmp1);
            assert(uut.cmp1_period == m_cmp1_period);
            assert(uut.wdt_load == m_wdt_load);
            assert(uut.wdt_enable == m_wdt_enable);
            assert(uut.wdt_counter == m_wdt_counter);
            assert(uut.pwm0_period == m_pwm0_period);
            assert(uut.pwm0_duty == m_pwm0_duty);
            assert(uut.pwm1_period == m_pwm1_period);
            assert(uut.pwm1_duty == m_pwm1_duty);
            assert(uut.capture_ctrl == m_capture_ctrl);
            assert(uut.capture0_value == m_capture0_value);
            assert(uut.capture1_value == m_capture1_value);
            assert(irq == irq_expected);
            assert(pwm0 == pwm0_expected);
            assert(pwm1 == pwm1_expected);
            if (bus_read) begin
                case (addr_word)
                    6'h0:  assert(rdata == m_ctrl);
                    6'h1:  assert(rdata == m_prescale);
                    6'h2:  assert(rdata == m_counter);
                    6'h3:  assert(rdata == m_status);
                    6'h4:  assert(rdata == m_irq_en);
                    6'h5:  assert(rdata == m_cmp0);
                    6'h6:  assert(rdata == m_cmp0_period);
                    6'h7:  assert(rdata == m_cmp1);
                    6'h8:  assert(rdata == m_cmp1_period);
                    6'h9:  assert(rdata == m_wdt_load);
                    6'hA:  assert(rdata[0] == m_wdt_enable);
                    6'hB:  assert(rdata == m_wdt_counter);
                    6'hC:  assert(rdata == m_pwm0_period);
                    6'hD:  assert(rdata == m_pwm0_duty);
                    6'hE:  assert(rdata == m_pwm1_period);
                    6'hF:  assert(rdata == m_pwm1_duty);
                    6'h10: assert(rdata[1:0] == {pwm1_expected, pwm0_expected});
                    6'h11: assert(rdata == m_capture_ctrl);
                    6'h12: assert(rdata == m_capture0_value);
                    6'h13: assert(rdata == m_capture1_value);
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cover(bus_write && addr_word == 6'hC);
            cover(bus_read && addr_word == 6'h12);
        end
    end

endmodule

`default_nettype wire
