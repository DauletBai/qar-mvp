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
    output reg  [WIDTH-1:0] gpio_out,
    output reg  [WIDTH-1:0] gpio_dir
);

    localparam ADDR_DIR     = 5'd0;
    localparam ADDR_OUT     = 5'd1;
    localparam ADDR_IN      = 5'd2;
    localparam ADDR_OUT_SET = 5'd3;
    localparam ADDR_OUT_CLR = 5'd4;

    wire [WIDTH-1:0] effective_in = (gpio_dir & gpio_out) | (~gpio_dir & gpio_in);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_dir <= {WIDTH{1'b0}};
            gpio_out <= {WIDTH{1'b0}};
        end else if (write_en) begin
            case (addr_word)
                ADDR_DIR:     gpio_dir <= wdata[WIDTH-1:0];
                ADDR_OUT:     gpio_out <= wdata[WIDTH-1:0];
                ADDR_OUT_SET: gpio_out <= gpio_out | wdata[WIDTH-1:0];
                ADDR_OUT_CLR: gpio_out <= gpio_out & ~wdata[WIDTH-1:0];
                default: ;
            endcase
        end
    end

    always @(*) begin
        if (!read_en) begin
            rdata = 32'b0;
        end else begin
            case (addr_word)
                ADDR_DIR: rdata = {{(32-WIDTH){1'b0}}, gpio_dir};
                ADDR_OUT: rdata = {{(32-WIDTH){1'b0}}, gpio_out};
                ADDR_IN:  rdata = {{(32-WIDTH){1'b0}}, effective_in};
                default:  rdata = 32'b0;
            endcase
        end
    end

endmodule

`default_nettype wire
