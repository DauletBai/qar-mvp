`default_nettype none

module can_formal_tb;
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
        assume(addr_word <= 6'h11);
    end

    wire [31:0] rdata;
    wire irq;

    qar_can uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_write(bus_write),
        .bus_read(bus_read),
        .addr_word(addr_word),
        .wdata(wdata),
        .rdata(rdata),
        .irq(irq)
    );

    reg [31:0] m_ctrl;
    reg [31:0] m_bittime;
    reg [31:0] m_err_counter;
    reg [31:0] m_irq_en;
    reg [31:0] m_irq_status;
    reg [31:0] m_filter_id;
    reg [31:0] m_filter_mask;
    reg [31:0] m_tx_id;
    reg [31:0] m_tx_dlc;
    reg [31:0] m_tx_data0;
    reg [31:0] m_tx_data1;
    reg        got_init;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_ctrl        <= 32'h0;
            m_bittime     <= 32'h0;
            m_err_counter <= 32'h0;
            m_irq_en      <= 32'h0;
            m_irq_status  <= 32'h0;
            m_filter_id   <= 32'h0;
            m_filter_mask <= 32'h0;
            m_tx_id       <= 32'h0;
            m_tx_dlc      <= 32'h0;
            m_tx_data0    <= 32'h0;
            m_tx_data1    <= 32'h0;
            got_init      <= 1'b0;
        end else begin
            if (bus_write && addr_word == 6'h0 && wdata[0] == 1'b0)
                got_init <= 1'b1;
            if (bus_write) begin
                case (addr_word)
                    6'h0: m_ctrl <= wdata & 32'hFFFFFFFE;
                    6'h2: m_bittime <= wdata;
                    6'h3: m_err_counter <= wdata;
                    6'h4: m_irq_en <= wdata;
                    6'h5: m_irq_status <= m_irq_status & ~wdata;
                    6'h6: m_filter_id <= wdata;
                    6'h7: m_filter_mask <= wdata;
                    6'h8: m_tx_id <= wdata;
                    6'h9: m_tx_dlc <= wdata;
                    6'hA: m_tx_data0 <= wdata;
                    6'hB: m_tx_data1 <= wdata;
                    default: ;
                endcase
            end
        end
    end

    wire irq_expected = |(m_irq_en[2:0] & m_irq_status[2:0]);

    always @(posedge clk) begin
        if (rst_n && got_init) begin
            assert(uut.ctrl[0] == 1'b0);
            assert(uut.ctrl == m_ctrl);
            assert(uut.bittime == m_bittime);
            assert(uut.err_counter == m_err_counter);
            assert(uut.irq_en == m_irq_en);
            assert(uut.irq_status == m_irq_status);
            assert(uut.filter_id == m_filter_id);
            assert(uut.filter_mask == m_filter_mask);
            assert(uut.tx_id == m_tx_id);
            assert(uut.tx_dlc == m_tx_dlc);
            assert(uut.tx_data0 == m_tx_data0);
            assert(uut.tx_data1 == m_tx_data1);
            assert(irq == irq_expected);
            if (bus_read) begin
                case (addr_word)
                    6'h0: assert(rdata == m_ctrl);
                    6'h2: assert(rdata == m_bittime);
                    6'h3: assert(rdata == m_err_counter);
                    6'h4: assert(rdata == m_irq_en);
                    6'h5: assert(rdata == m_irq_status);
                    6'h6: assert(rdata == m_filter_id);
                    6'h7: assert(rdata == m_filter_mask);
                    6'h8: assert(rdata == m_tx_id);
                    6'h9: assert(rdata == m_tx_dlc);
                    6'hA: assert(rdata == m_tx_data0);
                    6'hB: assert(rdata == m_tx_data1);
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
