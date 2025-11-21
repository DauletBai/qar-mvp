`default_nettype none

module i2c_formal_tb;
    reg clk = 0;
    always #1 clk = ~clk;

    reg rst_n = 0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg bus_write_any;
    (* anyseq *) reg bus_read_any;
    (* anyseq *) reg [5:0] addr_any;
    (* anyseq *) reg [31:0] wdata_any;

    wire bus_write = bus_write_any;
    wire bus_read  = bus_read_any & ~bus_write_any;
    wire [5:0] addr_word = addr_any;
    wire [31:0] wdata = wdata_any;

    always @(*) begin
        assume(addr_word <= 6'h8);
    end

    wire scl;
    wire sda_out;
    wire sda_oe;
    wire irq;
    wire [31:0] rdata;

    qar_i2c uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_write(bus_write),
        .bus_read(bus_read),
        .addr_word(addr_word),
        .wdata(wdata),
        .rdata(rdata),
        .irq(irq),
        .scl(scl),
        .sda_out(sda_out),
        .sda_in(1'b1),
        .sda_oe(sda_oe)
    );

    reg [31:0] m_ctrl;
    reg [31:0] m_clkdiv;
    reg [31:0] m_irq_en;
    reg [31:0] m_irq_status;
    reg        got_init;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_ctrl       <= 32'h0;
            m_clkdiv     <= 32'h0;
            m_irq_en     <= 32'h0;
            m_irq_status <= 32'h0;
            got_init     <= 1'b0;
        end else begin
            if (bus_write && addr_word == 6'h0 && wdata[0] == 1'b0)
                got_init <= 1'b1;
            if (bus_write) begin
                case (addr_word)
                    6'h0: m_ctrl <= wdata & 32'hFFFFFFFE;
                    6'h1: m_clkdiv <= wdata;
                    6'h3: m_irq_en <= wdata;
                    6'h4: m_irq_status <= m_irq_status & ~wdata;
                    default: ;
                endcase
            end
        end
    end

    wire irq_expected = |(m_irq_en[5:0] & m_irq_status[5:0]);

    always @(posedge clk) begin
        if (rst_n && got_init) begin
            assert(uut.ctrl[0] == 1'b0);
            assert(uut.ctrl == m_ctrl);
            assert(uut.clkdiv == m_clkdiv);
            assert(uut.irq_en == m_irq_en);
            assert(uut.irq_status == m_irq_status);
            assert(irq == irq_expected);
            if (bus_read) begin
                case (addr_word)
                    6'h0: assert(rdata == m_ctrl);
                    6'h1: assert(rdata == m_clkdiv);
                    6'h3: assert(rdata == m_irq_en);
                    6'h4: assert(rdata == m_irq_status);
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n)
            cover(bus_write && addr_word == 6'h0 && wdata[0] == 1'b0);
    end
endmodule

`default_nettype wire
