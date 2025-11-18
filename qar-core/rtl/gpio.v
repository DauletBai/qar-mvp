`default_nettype none

module qar_gpio #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             write_en,
    input  wire             read_en,
    input  wire [4:0]       addr_word, // word offset
    input  wire [31:0]      wdata,
    output reg  [31:0]      rdata,
    input  wire [WIDTH-1:0] gpio_in,
    input  wire             alt_pwm0,
    input  wire             alt_pwm1,
    output wire [WIDTH-1:0] gpio_out,
    output reg  [WIDTH-1:0] gpio_dir,
    output wire             irq
);

    localparam ADDR_DIR     = 5'd0;
    localparam ADDR_OUT     = 5'd1;
    localparam ADDR_IN      = 5'd2;
    localparam ADDR_OUT_SET = 5'd3;
    localparam ADDR_OUT_CLR = 5'd4;
    localparam ADDR_IRQ_EN      = 5'd5;
    localparam ADDR_IRQ_STATUS  = 5'd6;
    localparam ADDR_ALT_PWM     = 5'd7;
    localparam ADDR_IRQ_RISE    = 5'd8;
    localparam ADDR_IRQ_FALL    = 5'd9;
    localparam ADDR_DB_EN       = 5'd10;
    localparam ADDR_DB_CYCLES   = 5'd11;

    reg  [WIDTH-1:0] gpio_out_reg;
    reg  [WIDTH-1:0] alt_pwm_sel;
    reg  [WIDTH-1:0] pwm_override_values;
    reg  [WIDTH-1:0] pwm_override_mask;

    always @(*) begin
        pwm_override_values = {WIDTH{1'b0}};
        pwm_override_mask   = {WIDTH{1'b0}};
        if (WIDTH > 0) begin
            pwm_override_values[0] = alt_pwm_sel[0] ? alt_pwm0 : 1'b0;
            pwm_override_mask[0]   = alt_pwm_sel[0];
        end
        if (WIDTH > 1) begin
            pwm_override_values[1] = alt_pwm_sel[1] ? alt_pwm1 : 1'b0;
            pwm_override_mask[1]   = alt_pwm_sel[1];
        end
    end

    wire [WIDTH-1:0] gpio_hw_out = (gpio_out_reg & ~pwm_override_mask) | pwm_override_values;

    reg  [WIDTH-1:0] irq_enable;
    reg  [WIDTH-1:0] irq_status;
    reg  [WIDTH-1:0] irq_rise_mask;
    reg  [WIDTH-1:0] irq_fall_mask;
    reg  [WIDTH-1:0] last_input;
    reg  [WIDTH-1:0] debounce_enable;
    reg  [15:0]      debounce_cycles;
    reg  [WIDTH-1:0] debounced_input;
    reg  [15:0]      debounce_counter [0:WIDTH-1];

    assign irq = |(irq_enable & irq_status);

    integer i;
    wire [WIDTH-1:0] input_only = (~gpio_dir) & gpio_in;
    wire [15:0] debounce_threshold = (debounce_cycles == 16'd0) ? 16'd1 : debounce_cycles;
    wire [WIDTH-1:0] filtered_input_only = (~gpio_dir) & debounced_input;
    wire [WIDTH-1:0] rising_edges = (~last_input) & filtered_input_only;
    wire [WIDTH-1:0] falling_edges = last_input & (~filtered_input_only);
    wire [WIDTH-1:0] irq_events = (rising_edges & irq_rise_mask) | (falling_edges & irq_fall_mask);
    wire [WIDTH-1:0] clear_irq_mask =
        (write_en && addr_word == ADDR_IRQ_STATUS) ? wdata[WIDTH-1:0] : {WIDTH{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_dir    <= {WIDTH{1'b0}};
            gpio_out_reg<= {WIDTH{1'b0}};
            alt_pwm_sel <= {WIDTH{1'b0}};
            irq_enable  <= {WIDTH{1'b0}};
            irq_status  <= {WIDTH{1'b0}};
            irq_rise_mask <= {WIDTH{1'b1}};
            irq_fall_mask <= {WIDTH{1'b0}};
            last_input  <= {WIDTH{1'b0}};
            debounce_enable <= {WIDTH{1'b0}};
            debounce_cycles <= 16'd32;
            debounced_input <= {WIDTH{1'b0}};
            for (i = 0; i < WIDTH; i = i + 1)
                debounce_counter[i] <= 16'd0;
        end else begin
            if (write_en) begin
                case (addr_word)
                    ADDR_DIR:     gpio_dir <= wdata[WIDTH-1:0];
                    ADDR_OUT:     gpio_out_reg <= wdata[WIDTH-1:0];
                    ADDR_OUT_SET: gpio_out_reg <= gpio_out_reg | wdata[WIDTH-1:0];
                    ADDR_OUT_CLR: gpio_out_reg <= gpio_out_reg & ~wdata[WIDTH-1:0];
                    ADDR_IRQ_EN:  irq_enable <= wdata[WIDTH-1:0];
                    ADDR_IRQ_STATUS: ; // handled via clear mask logic below
                    ADDR_ALT_PWM: alt_pwm_sel <= wdata[WIDTH-1:0];
                    ADDR_IRQ_RISE: irq_rise_mask <= wdata[WIDTH-1:0];
                    ADDR_IRQ_FALL: irq_fall_mask <= wdata[WIDTH-1:0];
                    ADDR_DB_EN:    debounce_enable <= wdata[WIDTH-1:0];
                    ADDR_DB_CYCLES: debounce_cycles <= wdata[15:0];
                    default: ;
                endcase
            end
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (gpio_dir[i]) begin
                    debounced_input[i] <= gpio_hw_out[i];
                    debounce_counter[i] <= 16'd0;
                end else if (!debounce_enable[i]) begin
                    debounced_input[i] <= input_only[i];
                    debounce_counter[i] <= 16'd0;
                end else begin
                    if (input_only[i] == debounced_input[i]) begin
                        debounce_counter[i] <= 16'd0;
                    end else if (debounce_counter[i] >= debounce_threshold) begin
                        debounced_input[i] <= input_only[i];
                        debounce_counter[i] <= 16'd0;
                    end else begin
                        debounce_counter[i] <= debounce_counter[i] + 16'd1;
                    end
                end
            end
            irq_status <= (irq_status & ~clear_irq_mask) | irq_events;
            last_input <= filtered_input_only;
        end
    end

    always @(*) begin
        if (!read_en) begin
            rdata = 32'b0;
        end else begin
            case (addr_word)
                ADDR_DIR: rdata = {{(32-WIDTH){1'b0}}, gpio_dir};
                ADDR_OUT: rdata = {{(32-WIDTH){1'b0}}, gpio_out_reg};
                ADDR_IN:  rdata = {{(32-WIDTH){1'b0}}, ((gpio_dir & gpio_hw_out) | filtered_input_only)};
                ADDR_IRQ_EN: rdata = {{(32-WIDTH){1'b0}}, irq_enable};
                ADDR_IRQ_STATUS: rdata = {{(32-WIDTH){1'b0}}, irq_status};
                ADDR_ALT_PWM: rdata = {{(32-WIDTH){1'b0}}, alt_pwm_sel};
                ADDR_IRQ_RISE: rdata = {{(32-WIDTH){1'b0}}, irq_rise_mask};
                ADDR_IRQ_FALL: rdata = {{(32-WIDTH){1'b0}}, irq_fall_mask};
                ADDR_DB_EN:    rdata = {{(32-WIDTH){1'b0}}, debounce_enable};
                ADDR_DB_CYCLES:rdata = {16'b0, debounce_cycles};
                default:  rdata = 32'b0;
            endcase
        end
    end

    assign gpio_out = gpio_hw_out;

endmodule

`default_nettype wire
