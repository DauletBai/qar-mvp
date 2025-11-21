`default_nettype none

module spi_formal_tb;
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

    wire spi_miso = 1'b1;
    wire [3:0] spi_cs_n;
    wire spi_sck;
    wire spi_mosi;
    wire irq;
    wire [31:0] rdata;

    qar_spi uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_write(bus_write),
        .bus_read(bus_read),
        .addr_word(addr_word),
        .wdata(wdata),
        .rdata(rdata),
        .irq(irq),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

    reg [31:0] m_ctrl;
    reg [31:0] m_clkdiv;
    reg [31:0] m_cs_select;
    reg [31:0] m_irq_en;
    reg [31:0] m_irq_status;
    reg        got_init;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_ctrl       <= 32'h0;
            m_clkdiv     <= 32'h0;
            m_cs_select  <= 32'h0;
            m_irq_en     <= 32'h0;
            m_irq_status <= 32'h0;
            got_init     <= 1'b0;
        end else begin
            if (bus_write && addr_word == 6'h0 && wdata[0] == 1'b0)
                got_init <= 1'b1;
            if (bus_write) begin
                case (addr_word)
                    6'h0: m_ctrl <= wdata & 32'hFFFFFFFE; // force disabled
                    6'h2: m_clkdiv <= wdata;
                    6'h5: m_cs_select <= wdata;
                    6'h6: m_irq_en <= wdata;
                    6'h7: m_irq_status <= m_irq_status & ~wdata;
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
            assert(uut.cs_select == m_cs_select);
            assert(uut.irq_en == m_irq_en);
            assert(uut.irq_status == m_irq_status);
            assert(irq == irq_expected);
            if (bus_read) begin
                case (addr_word)
                    6'h0: assert(rdata == m_ctrl);
                    6'h2: assert(rdata == m_clkdiv);
                    6'h5: assert(rdata == m_cs_select);
                    6'h6: assert(rdata == m_irq_en);
                    6'h7: assert(rdata == m_irq_status);
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
