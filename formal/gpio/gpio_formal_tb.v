`default_nettype none

module gpio_formal_tb;
    localparam WIDTH = 4;

    reg clk = 0;
    always #1 clk = !clk;

    reg rst_n = 0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg write_en_any;
    (* anyseq *) reg read_en_any;
    (* anyseq *) reg [4:0] addr_any;
    (* anyseq *) reg [31:0] wdata_any;

    wire write_en = write_en_any;
    wire read_en = read_en_any & ~write_en_any;
    wire [4:0] addr_word = addr_any;
    wire [31:0] wdata = wdata_any;

    always @(*) begin
        assume(addr_word <= 5'd11);
    end

    wire [WIDTH-1:0] gpio_in = {WIDTH{1'b0}};
    wire alt_pwm0 = 1'b0;
    wire alt_pwm1 = 1'b0;

    wire [31:0] rdata;
    wire [WIDTH-1:0] gpio_out;
    wire [WIDTH-1:0] gpio_dir;
    wire irq;

    qar_gpio #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .addr_word(addr_word),
        .wdata(wdata),
        .rdata(rdata),
        .gpio_in(gpio_in),
        .alt_pwm0(alt_pwm0),
        .alt_pwm1(alt_pwm1),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .irq(irq)
    );

    reg [WIDTH-1:0] model_dir;
    reg [WIDTH-1:0] model_out;
    reg [WIDTH-1:0] model_irq_en;
    reg [WIDTH-1:0] model_irq_status;
    reg [WIDTH-1:0] model_irq_rise;
    reg [WIDTH-1:0] model_irq_fall;
    reg [WIDTH-1:0] model_alt_sel;
    reg [WIDTH-1:0] model_db_en;
    reg [15:0]      model_db_cycles;

    always @(posedge clk) begin
        if (!rst_n) begin
            model_dir        <= {WIDTH{1'b0}};
            model_out        <= {WIDTH{1'b0}};
            model_irq_en     <= {WIDTH{1'b0}};
            model_irq_status <= {WIDTH{1'b0}};
            model_irq_rise   <= {WIDTH{1'b1}};
            model_irq_fall   <= {WIDTH{1'b0}};
            model_alt_sel    <= {WIDTH{1'b0}};
            model_db_en      <= {WIDTH{1'b0}};
            model_db_cycles  <= 16'd32;
        end else begin
            if (write_en) begin
                case (addr_word)
                    5'd0:  model_dir        <= wdata[WIDTH-1:0];
                    5'd1:  model_out        <= wdata[WIDTH-1:0];
                    5'd3:  model_out        <= model_out | wdata[WIDTH-1:0];
                    5'd4:  model_out        <= model_out & ~wdata[WIDTH-1:0];
                    5'd5:  model_irq_en     <= wdata[WIDTH-1:0];
                    5'd6:  model_irq_status <= model_irq_status & ~wdata[WIDTH-1:0];
                    5'd7:  model_alt_sel    <= wdata[WIDTH-1:0];
                    5'd8:  model_irq_rise   <= wdata[WIDTH-1:0];
                    5'd9:  model_irq_fall   <= wdata[WIDTH-1:0];
                    5'd10: model_db_en      <= wdata[WIDTH-1:0];
                    5'd11: model_db_cycles  <= wdata[15:0];
                    default: ;
                endcase
            end
        end
    end

    reg [WIDTH-1:0] model_pwm_values;
    reg [WIDTH-1:0] model_pwm_mask;
    always @(*) begin
        model_pwm_values = {WIDTH{1'b0}};
        model_pwm_mask   = {WIDTH{1'b0}};
        if (WIDTH > 0) begin
            model_pwm_values[0] = model_alt_sel[0] ? alt_pwm0 : 1'b0;
            model_pwm_mask[0]   = model_alt_sel[0];
        end
        if (WIDTH > 1) begin
            model_pwm_values[1] = model_alt_sel[1] ? alt_pwm1 : 1'b0;
            model_pwm_mask[1]   = model_alt_sel[1];
        end
    end
    wire [WIDTH-1:0] model_hw_out = (model_out & ~model_pwm_mask) | model_pwm_values;

    always @(posedge clk) begin
        if (!rst_n) begin
            assert(gpio_dir == {WIDTH{1'b0}});
            assert(gpio_out == {WIDTH{1'b0}});
        end else begin
            assert(gpio_dir == model_dir);
            assert(gpio_out == model_hw_out);
            if (read_en) begin
                case (addr_word)
                    5'd0:  assert(rdata[WIDTH-1:0] == model_dir);
                    5'd1:  assert(rdata[WIDTH-1:0] == model_out);
                    5'd2:  assert(rdata[WIDTH-1:0] == (model_dir & model_hw_out));
                    5'd5:  assert(rdata[WIDTH-1:0] == model_irq_en);
                    5'd6:  assert(rdata[WIDTH-1:0] == model_irq_status);
                    5'd7:  assert(rdata[WIDTH-1:0] == model_alt_sel);
                    5'd8:  assert(rdata[WIDTH-1:0] == model_irq_rise);
                    5'd9:  assert(rdata[WIDTH-1:0] == model_irq_fall);
                    5'd10: assert(rdata[WIDTH-1:0] == model_db_en);
                    5'd11: assert(rdata[15:0] == model_db_cycles);
                    default: ;
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cover(write_en && addr_word == 5'd3);
            cover(read_en && addr_word == 5'd7);
        end
    end

endmodule

`default_nettype wire
