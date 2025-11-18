// =============================================
// QAR-Core v0.6 - Three-Stage Pipeline Core
// - RV32I subset with arithmetic/logic, load/store, branches, CSR ops
// - Streaming instruction/data interfaces with basic hazard + forwarding
// - CSR/timer subsystem with ECALL/MRET and external interrupts
// =============================================
`default_nettype none

module qar_core #(
    parameter IMEM_DEPTH        = 64,
    parameter DMEM_DEPTH        = 256,
    parameter USE_INTERNAL_IMEM = 0,
    parameter USE_INTERNAL_DMEM = 0,
    parameter IMEM_DATA_WIDTH   = 32,
    parameter DMEM_DATA_WIDTH   = 32,
    parameter ICACHE_ENTRIES    = 0
) (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory interface
    output wire        imem_valid,
    output wire [31:0] imem_addr,
    input  wire        imem_ready,
    input  wire [IMEM_DATA_WIDTH-1:0] imem_rdata,

    // Data memory interface
    output wire        mem_valid,
    output wire        mem_we,
    output wire [31:0] mem_addr,
    output wire [DMEM_DATA_WIDTH-1:0] mem_wdata,
    input  wire        mem_ready,
    input  wire [DMEM_DATA_WIDTH-1:0] mem_rdata,

    // External interrupt sources
    input  wire        irq_timer,
    input  wire        irq_external,
    output reg         irq_timer_ack,
    output reg         irq_external_ack,

    // GPIO interface
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_dir,
    output wire        gpio_irq,

    // UART interface
    output wire        uart_tx,
    input  wire        uart_rx,
    output wire        uart_de,
    output wire        uart_re,
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire [3:0]  spi_cs_n,
    output wire        i2c_scl,
    output wire        i2c_sda_out,
    input  wire        i2c_sda_in,
    output wire        i2c_sda_oe
);

    // ------------------------------------------------------------
    // Utility: clog2 replacement for Verilog-2001 compatibility
    // ------------------------------------------------------------
    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam IMEM_ADDR_WIDTH = clog2(IMEM_DEPTH);
    localparam IMEM_ADDR_MSB   = IMEM_ADDR_WIDTH + 1;
    localparam DMEM_ADDR_WIDTH = clog2(DMEM_DEPTH);
    localparam DMEM_ADDR_MSB   = DMEM_ADDR_WIDTH + 1;

    initial begin
        if (IMEM_DATA_WIDTH != 32) begin
            $fatal("IMEM_DATA_WIDTH values other than 32 are not supported in this prototype");
        end
        if (DMEM_DATA_WIDTH != 32) begin
            $fatal("DMEM_DATA_WIDTH values other than 32 are not supported in this prototype");
        end
        if (ICACHE_ENTRIES == 1) begin
            $fatal("ICACHE_ENTRIES must be 0 (disabled) or a power-of-two >= 2");
        end
    end

    localparam PREFETCH_DEPTH = 2;
    localparam ICACHE_ENABLED      = (ICACHE_ENTRIES > 0) ? 1 : 0;
    localparam ICACHE_INDEX_BITS   = (ICACHE_ENTRIES > 0) ? clog2(ICACHE_ENTRIES) : 1;
    localparam ICACHE_TAG_BITS     = 32 - 2 - ICACHE_INDEX_BITS;
    localparam REAL_ICACHE_ENTRIES = (ICACHE_ENTRIES > 0) ? ICACHE_ENTRIES : 1;
    localparam GPIO_BASE_ADDR      = 32'h4000_0000;
    localparam GPIO_ADDR_MASK      = 32'hFFFF_FF00;
    localparam UART0_BASE_ADDR     = 32'h4000_1000;
    localparam UART_ADDR_MASK      = 32'hFFFF_FF00;
    localparam SPI0_BASE_ADDR      = 32'h4000_4000;
    localparam SPI_ADDR_MASK       = 32'hFFFF_FF00;
    localparam CAN0_BASE_ADDR      = 32'h4000_3000;
    localparam CAN_ADDR_MASK       = 32'hFFFF_FF00;
    localparam TIMER0_BASE_ADDR    = 32'h4000_5000;
    localparam TIMER_ADDR_MASK     = 32'hFFFF_FF00;
    localparam I2C0_BASE_ADDR      = 32'h4000_4400;
    localparam I2C_ADDR_MASK       = 32'hFFFF_FF00;

    // ------------------------------------------------------------
    // Fetch / Decode / Execute pipeline state
    // ------------------------------------------------------------
    reg [31:0] pc_fetch;
    reg        fetch_req_pending;
    reg [31:0] fetch_req_addr;

    reg        if_valid;
    reg [31:0] if_instr;
    reg [31:0] if_pc;
    reg        prefetch_slot_valid;
    reg [31:0] prefetch_slot_instr;
    reg [31:0] prefetch_slot_pc;
    integer icache_init_idx;
    reg        start_gpio;
    reg        start_gpio_is_load;
    reg [31:0] start_gpio_addr;
    reg [31:0] start_gpio_wdata;
    reg        start_uart0;
    reg        start_uart0_is_load;
    reg [31:0] start_uart0_addr;
    reg [31:0] start_uart0_wdata;
    reg        start_spi0;
    reg        start_spi0_is_load;
    reg [31:0] start_spi0_addr;
    reg [31:0] start_spi0_wdata;
    reg        start_i2c0;
    reg        start_i2c0_is_load;
    reg [31:0] start_i2c0_addr;
    reg [31:0] start_i2c0_wdata;
    reg        start_can0;
    reg        start_can0_is_load;
    reg [31:0] start_can0_addr;
    reg [31:0] start_can0_wdata;
    reg        start_timer0;
    reg        start_timer0_is_load;
    reg [31:0] start_timer0_addr;
    reg [31:0] start_timer0_wdata;
    reg [31:0] icache_data [0:REAL_ICACHE_ENTRIES-1];
    reg [ICACHE_TAG_BITS-1:0] icache_tag [0:REAL_ICACHE_ENTRIES-1];
    reg                       icache_valid [0:REAL_ICACHE_ENTRIES-1];
    wire        gpio_write_en    = start_gpio && !start_gpio_is_load;
    wire        gpio_read_en     = start_gpio && start_gpio_is_load;
    wire [4:0]  gpio_addr_word   = start_gpio_addr[6:2];
    wire [31:0] gpio_read_data;
    wire        uart0_write_en = start_uart0 && !start_uart0_is_load;
    wire        uart0_read_en  = start_uart0 && start_uart0_is_load;
    wire [3:0]  uart0_addr_word = start_uart0_addr[5:2];
    wire [31:0] uart0_read_data;
    wire        uart0_irq;
    wire        spi0_write_en = start_spi0 && !start_spi0_is_load;
    wire        spi0_read_en  = start_spi0 && start_spi0_is_load;
    wire [5:0]  spi0_addr_word = start_spi0_addr[7:2];
    wire [31:0] spi0_read_data;
    wire        spi0_irq;
    wire        can0_write_en = start_can0 && !start_can0_is_load;
    wire        can0_read_en  = start_can0 && start_can0_is_load;
    wire [5:0]  can0_addr_word = start_can0_addr[7:2];
    wire [31:0] can0_read_data;
    wire        can0_irq;
    wire        i2c0_write_en = start_i2c0 && !start_i2c0_is_load;
    wire        i2c0_read_en  = start_i2c0 && start_i2c0_is_load;
    wire [5:0]  i2c0_addr_word = start_i2c0_addr[7:2];
    wire [31:0] i2c0_read_data;
    wire        i2c0_irq;
    wire        timer0_write_en = start_timer0 && !start_timer0_is_load;
    wire        timer0_read_en  = start_timer0 && start_timer0_is_load;
    wire [5:0]  timer0_addr_word = start_timer0_addr[7:2];
    wire [31:0] timer0_read_data;
    wire        timer0_irq;
    wire        timer_pwm0;
    wire        timer_pwm1;

    always @(*) begin
        if ((ICACHE_ENABLED != 0) &&
            icache_valid[next_cache_index] &&
            (icache_tag[next_cache_index] == next_cache_tag)) begin
            icache_lookup_hit  = 1'b1;
            icache_lookup_word = icache_data[next_cache_index];
        end else begin
            icache_lookup_hit  = 1'b0;
            icache_lookup_word = 32'b0;
        end
    end
    reg [ICACHE_INDEX_BITS-1:0] icache_fill_index;
    reg [ICACHE_TAG_BITS-1:0]   icache_fill_tag;
    reg                         fetch_req_cacheable;

    reg        id_valid;
    reg [31:0] id_instr;
    reg [31:0] id_pc;

    reg        ex_valid;
    reg [31:0] ex_instr;
    reg [31:0] ex_pc;
    reg [31:0] ex_rs1_val;
    reg [31:0] ex_rs2_val;

    wire       imem_ready_in;
    wire [IMEM_DATA_WIDTH-1:0] imem_rdata_in;
    wire [31:0] imem_instr_word = imem_rdata_in[31:0];
    wire [31:0] next_fetch_addr = pc_fetch;
    wire [ICACHE_INDEX_BITS-1:0] next_cache_index = (ICACHE_ENABLED != 0) ?
        next_fetch_addr[ICACHE_INDEX_BITS+1:2] : {ICACHE_INDEX_BITS{1'b0}};
    wire [ICACHE_TAG_BITS-1:0]   next_cache_tag   = next_fetch_addr[ICACHE_INDEX_BITS+ICACHE_TAG_BITS+1:ICACHE_INDEX_BITS+2];
    reg                          icache_lookup_hit;
    reg  [31:0]                  icache_lookup_word;

    generate
        if (USE_INTERNAL_IMEM) begin : gen_internal_imem
            reg [31:0] imem_array [0:IMEM_DEPTH-1];
            integer ii;
            initial begin
                for (ii = 0; ii < IMEM_DEPTH; ii = ii + 1)
                    imem_array[ii] = 32'b0;
                $display("QAR-Core: loading internal instruction memory from program.hex ...");
                $readmemh("program.hex", imem_array);
            end
            assign imem_ready_in = fetch_req_pending;
            assign imem_rdata_in = imem_array[fetch_req_addr[IMEM_ADDR_MSB:2]];
        end else begin : gen_external_imem
            assign imem_ready_in = imem_ready;
            assign imem_rdata_in = imem_rdata;
        end
    endgenerate

    assign imem_valid = fetch_req_pending;
    assign imem_addr  = fetch_req_addr;

    // ------------------------------------------------------------
    // Data memory interface wires (internal RAM optional)
    // ------------------------------------------------------------
    reg                  mem_req_valid;
    reg                  mem_req_we;
    reg  [31:0]          mem_req_addr;
    reg  [DMEM_DATA_WIDTH-1:0] mem_req_wdata;

    reg                  dmem_pending;
    reg                  dmem_is_load;
    reg  [4:0]           dmem_rd;

    wire                 mem_ready_in;
    wire [DMEM_DATA_WIDTH-1:0] mem_rdata_in;
    wire [31:0]          mem_rdata_word = mem_rdata_in[31:0];

    generate
        if (USE_INTERNAL_DMEM) begin : gen_internal_dmem
            reg [31:0] dmem_array [0:DMEM_DEPTH-1];
            integer di;
            initial begin
                for (di = 0; di < DMEM_DEPTH; di = di + 1)
                    dmem_array[di] = 32'b0;
                $display("QAR-Core: loading internal data memory from data.hex ...");
                $readmemh("data.hex", dmem_array);
            end
            assign mem_ready_in = mem_req_valid;
            assign mem_rdata_in = dmem_array[mem_req_addr[DMEM_ADDR_MSB:2]];
            always @(posedge clk) begin
                if (mem_req_valid && mem_req_we)
                    dmem_array[mem_req_addr[DMEM_ADDR_MSB:2]] <= mem_req_wdata;
            end
        end else begin : gen_external_dmem
            assign mem_ready_in = mem_ready;
            assign mem_rdata_in = mem_rdata;
        end
    endgenerate

    assign mem_valid  = mem_req_valid;
    assign mem_we     = mem_req_we;
    assign mem_addr   = mem_req_addr;
    assign mem_wdata  = mem_req_wdata;

    // ------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;
    reg  [4:0]  rf_raddr1;
    reg  [4:0]  rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

    regfile rf_inst (
        .clk   (clk),
        .we    (rf_we),
        .waddr (rf_waddr),
        .wdata (rf_wdata),
        .raddr1(rf_raddr1),
        .raddr2(rf_raddr2),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2)
    );

    qar_gpio #(
        .WIDTH(32)
    ) gpio_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .write_en (gpio_write_en),
        .read_en  (gpio_read_en),
        .addr_word(gpio_addr_word),
        .wdata    (start_gpio_wdata),
        .rdata    (gpio_read_data),
        .gpio_in  (gpio_in),
        .alt_pwm0 (timer_pwm0),
        .alt_pwm1 (timer_pwm1),
        .gpio_out (gpio_out),
        .gpio_dir (gpio_dir),
        .irq      (gpio_irq)
    );

    qar_uart uart0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_write (uart0_write_en),
        .bus_read  (uart0_read_en),
        .addr_word (uart0_addr_word),
        .wdata     (start_uart0_wdata),
        .rdata     (uart0_read_data),
        .tx        (uart_tx),
        .rx        (uart_rx),
        .rs485_de  (uart_de),
        .rs485_re  (uart_re),
        .irq       (uart0_irq)
    );

    qar_spi spi0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_write (spi0_write_en),
        .bus_read  (spi0_read_en),
        .addr_word (spi0_addr_word),
        .wdata     (start_spi0_wdata),
        .rdata     (spi0_read_data),
        .irq       (spi0_irq),
        .spi_sck   (spi_sck),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .spi_cs_n  (spi_cs_n)
    );

    qar_can can0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_write (can0_write_en),
        .bus_read  (can0_read_en),
        .addr_word (can0_addr_word),
        .wdata     (start_can0_wdata),
        .rdata     (can0_read_data),
        .irq       (can0_irq)
    );

    qar_timer timer0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_write (timer0_write_en),
        .bus_read  (timer0_read_en),
        .addr_word (timer0_addr_word),
        .wdata     (start_timer0_wdata),
        .rdata     (timer0_read_data),
        .irq       (timer0_irq),
        .pwm0      (timer_pwm0),
        .pwm1      (timer_pwm1)
    );

    qar_i2c i2c0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_write (i2c0_write_en),
        .bus_read  (i2c0_read_en),
        .addr_word (i2c0_addr_word),
        .wdata     (start_i2c0_wdata),
        .rdata     (i2c0_read_data),
        .irq       (i2c0_irq),
        .scl       (i2c_scl),
        .sda_out   (i2c_sda_out),
        .sda_in    (i2c_sda_in),
        .sda_oe    (i2c_sda_oe)
    );

    // ------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------
    reg  [31:0] alu_op_a;
    reg  [31:0] alu_op_b;
    reg  [3:0]  alu_op_sel;
    wire [31:0] alu_result;

    alu alu_inst (
        .op_a  (alu_op_a),
        .op_b  (alu_op_b),
        .alu_op(alu_op_sel),
        .result(alu_result)
    );

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;

    // ------------------------------------------------------------
    // CSR registers (extended set)
    // ------------------------------------------------------------
    reg [31:0] csr_mstatus;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;
    reg [31:0] csr_mie;
    reg [31:0] csr_mip;
    reg [31:0] csr_mtimecmp;
    reg [31:0] csr_mtime;
    reg        csr_irq_priority;

    localparam CSR_ADDR_MSTATUS  = 12'h300;
    localparam CSR_ADDR_MIE      = 12'h304;
    localparam CSR_ADDR_MTVEC    = 12'h305;
    localparam CSR_ADDR_MEPC     = 12'h341;
    localparam CSR_ADDR_MCAUSE   = 12'h342;
    localparam CSR_ADDR_MIP      = 12'h344;
    localparam CSR_ADDR_MTIME    = 12'h701;
    localparam CSR_ADDR_MTIMECMP = 12'h720;
    localparam CSR_ADDR_IRQ_PRIORITY = 12'hBC0;
    localparam CSR_ADDR_IRQ_ACK      = 12'hBC1;

    localparam MCAUSE_ECALL = 32'd11;
    localparam MCAUSE_ILLEGAL = 32'd2;
    localparam MCAUSE_TIMER_IRQ = 32'h8000_0007;
    localparam MCAUSE_EXT_IRQ   = 32'h8000_000B;

    // ------------------------------------------------------------
    // Decode helper wires
    // ------------------------------------------------------------
    wire [6:0]  id_opcode  = id_instr[6:0];
    wire [2:0]  id_funct3  = id_instr[14:12];
    wire [6:0]  id_funct7  = id_instr[31:25];
    wire [4:0]  id_rs1     = id_instr[19:15];
    wire [4:0]  id_rs2     = id_instr[24:20];
    wire [4:0]  id_rd      = id_instr[11:7];

    wire id_uses_rs1 = (id_opcode == 7'b0110011) || // OP
                       (id_opcode == 7'b0010011) || // OP-IMM
                       (id_opcode == 7'b0000011) || // LOAD
                       (id_opcode == 7'b0100011) || // STORE
                       (id_opcode == 7'b1100011) || // BRANCH
                       (id_opcode == 7'b1100111) || // JALR
                       (id_opcode == 7'b1110011 && id_funct3 != 3'b000); // CSR register forms

    wire id_uses_rs2 = (id_opcode == 7'b0110011) || // OP
                       (id_opcode == 7'b0100011) || // STORE
                       (id_opcode == 7'b1100011);   // BRANCH

    wire [31:0] id_rs1_raw = rf_rdata1;
    wire [31:0] id_rs2_raw = rf_rdata2;

    wire [6:0]  opcode  = ex_instr[6:0];
    wire [4:0]  rd      = ex_instr[11:7];
    wire [2:0]  funct3  = ex_instr[14:12];
    wire [4:0]  rs1     = ex_instr[19:15];
    wire [4:0]  rs2     = ex_instr[24:20];
    wire [6:0]  funct7  = ex_instr[31:25];

    wire [31:0] imm_i = {{20{ex_instr[31]}}, ex_instr[31:20]};
    wire [31:0] imm_s = {{20{ex_instr[31]}}, ex_instr[31:25], ex_instr[11:7]};
    wire [31:0] imm_b = {{19{ex_instr[31]}}, ex_instr[31], ex_instr[7], ex_instr[30:25], ex_instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{ex_instr[31]}}, ex_instr[31], ex_instr[19:12], ex_instr[20], ex_instr[30:21], 1'b0};
    wire [31:0] imm_u = {ex_instr[31:12], 12'b0};
    wire [31:0] jalr_sum = ex_rs1_val + imm_i;
    wire [31:0] addr_load_candidate  = ex_rs1_val + imm_i;
    wire [31:0] addr_store_candidate = ex_rs1_val + imm_s;
    wire        load_hits_gpio  = ((addr_load_candidate & GPIO_ADDR_MASK) == GPIO_BASE_ADDR);
    wire        store_hits_gpio = ((addr_store_candidate & GPIO_ADDR_MASK) == GPIO_BASE_ADDR);
    wire        load_hits_uart0  = ((addr_load_candidate & UART_ADDR_MASK) == UART0_BASE_ADDR);
    wire        store_hits_uart0 = ((addr_store_candidate & UART_ADDR_MASK) == UART0_BASE_ADDR);
    wire        load_hits_can0   = ((addr_load_candidate & CAN_ADDR_MASK) == CAN0_BASE_ADDR);
    wire        store_hits_can0  = ((addr_store_candidate & CAN_ADDR_MASK) == CAN0_BASE_ADDR);
    wire        load_hits_spi0   = ((addr_load_candidate & SPI_ADDR_MASK) == SPI0_BASE_ADDR);
    wire        store_hits_spi0  = ((addr_store_candidate & SPI_ADDR_MASK) == SPI0_BASE_ADDR);
    wire        load_hits_timer0 = ((addr_load_candidate & TIMER_ADDR_MASK) == TIMER0_BASE_ADDR);
    wire        store_hits_timer0= ((addr_store_candidate & TIMER_ADDR_MASK) == TIMER0_BASE_ADDR);
    wire        load_hits_i2c0   = ((addr_load_candidate & I2C_ADDR_MASK) == I2C0_BASE_ADDR);
    wire        store_hits_i2c0  = ((addr_store_candidate & I2C_ADDR_MASK) == I2C0_BASE_ADDR);

    wire [31:0] pc_plus4 = ex_pc + 32'd4;

    // ------------------------------------------------------------
    // Control + hazard wires
    // ------------------------------------------------------------
    reg        stall_ex;
    reg        branch_taken;
    reg [31:0] branch_target;
    reg        flush_pipe;

    reg        csr_write_en;
    reg [11:0] csr_write_addr;
    reg [31:0] csr_write_data;
    reg [31:0] csr_read_data;

    reg        trap_request;
    reg [31:0] trap_target;
    reg [31:0] trap_cause;
    reg [31:0] trap_mepc_value;

    reg        start_mem;
    reg        start_mem_is_load;
    reg [31:0] start_mem_addr;
    reg [31:0] start_mem_wdata;
    reg [4:0]  start_mem_rd;

    reg        load_commit;
    reg [4:0]  load_commit_rd;

    reg        illegal_instr;

    wire       ex_active = ex_valid;

    // Forwarding assistance
    wire       wb_en_forward = ex_active && !stall_ex && rf_we && (rf_waddr != 0);

    wire [31:0] forward_rs1 = (wb_en_forward && (rf_waddr == id_rs1) && id_uses_rs1) ? rf_wdata : id_rs1_raw;
    wire [31:0] forward_rs2 = (wb_en_forward && (rf_waddr == id_rs2) && id_uses_rs2) ? rf_wdata : id_rs2_raw;

    wire hazard_load_rs1 = dmem_pending && dmem_is_load && id_uses_rs1 && (id_rs1 != 0) && (id_rs1 == dmem_rd);
    wire hazard_load_rs2 = dmem_pending && dmem_is_load && id_uses_rs2 && (id_rs2 != 0) && (id_rs2 == dmem_rd);
    wire load_use_hazard = id_valid && (hazard_load_rs1 || hazard_load_rs2);

    // CSR read helper
    always @(*) begin
        case (ex_instr[31:20])
            CSR_ADDR_MSTATUS:  csr_read_data = csr_mstatus;
            CSR_ADDR_MTVEC:    csr_read_data = csr_mtvec;
            CSR_ADDR_MEPC:     csr_read_data = csr_mepc;
            CSR_ADDR_MCAUSE:   csr_read_data = csr_mcause;
            CSR_ADDR_MIE:      csr_read_data = csr_mie;
            CSR_ADDR_MIP:      csr_read_data = csr_mip;
            CSR_ADDR_MTIME:    csr_read_data = csr_mtime;
            CSR_ADDR_MTIMECMP: csr_read_data = csr_mtimecmp;
            CSR_ADDR_IRQ_PRIORITY: csr_read_data = {31'b0, csr_irq_priority};
            CSR_ADDR_IRQ_ACK:      csr_read_data = 32'b0;
            default:           csr_read_data = 32'b0;
        endcase
    end

    // ------------------------------------------------------------
    // Combinational decode / execute control
    // ------------------------------------------------------------
    always @(*) begin
        rf_we        = 1'b0;
        rf_waddr     = rd;
        rf_wdata     = alu_result;
        rf_raddr1    = id_valid ? id_rs1 : 5'd0;
        rf_raddr2    = id_valid ? id_rs2 : 5'd0;
        alu_op_a     = ex_rs1_val;
        alu_op_b     = ex_rs2_val;
        alu_op_sel   = ALU_ADD;
        branch_taken = 1'b0;
        branch_target= pc_plus4;
        flush_pipe   = 1'b0;
        stall_ex     = 1'b0;
        start_mem         = 1'b0;
        start_mem_is_load = 1'b0;
        start_mem_addr    = 32'b0;
        start_mem_wdata   = 32'b0;
        start_mem_rd      = rd;
        start_gpio         = 1'b0;
        start_gpio_is_load = 1'b0;
        start_gpio_addr    = 32'b0;
        start_gpio_wdata   = 32'b0;
        start_uart0         = 1'b0;
        start_uart0_is_load = 1'b0;
        start_uart0_addr    = 32'b0;
        start_uart0_wdata   = 32'b0;
        start_spi0          = 1'b0;
        start_spi0_is_load  = 1'b0;
        start_spi0_addr     = 32'b0;
        start_spi0_wdata    = 32'b0;
        start_i2c0          = 1'b0;
        start_i2c0_is_load  = 1'b0;
        start_i2c0_addr     = 32'b0;
        start_i2c0_wdata    = 32'b0;
        start_can0          = 1'b0;
        start_can0_is_load  = 1'b0;
        start_can0_addr     = 32'b0;
        start_can0_wdata    = 32'b0;
        start_timer0        = 1'b0;
        start_timer0_is_load= 1'b0;
        start_timer0_addr   = 32'b0;
        start_timer0_wdata  = 32'b0;
        load_commit       = 1'b0;
        load_commit_rd    = dmem_rd;
        csr_write_en      = 1'b0;
        csr_write_addr    = 12'b0;
        csr_write_data    = 32'b0;
        trap_request      = 1'b0;
        trap_target       = csr_mtvec;
        trap_cause        = 32'd0;
        trap_mepc_value   = ex_pc;
        illegal_instr     = 1'b0;

        if (dmem_pending && mem_ready_in && dmem_is_load) begin
            load_commit    = 1'b1;
            load_commit_rd = dmem_rd;
        end

        if (dmem_pending && !mem_ready_in)
            stall_ex = 1'b1;
        if (start_mem)
            stall_ex = 1'b1;

        if (ex_active) begin
            case (opcode)
                7'b0010011: begin // OP-IMM
                    rf_we    = 1'b1;
                    rf_waddr = rd;
                    alu_op_a = ex_rs1_val;
                    alu_op_sel = ALU_ADD;
                    alu_op_b = imm_i;
                end

                7'b0110011: begin // OP
                    rf_we    = 1'b1;
                    rf_waddr = rd;
                    case (funct3)
                        3'b000: begin
                            if (funct7 == 7'b0000000)
                                alu_op_sel = ALU_ADD;
                            else if (funct7 == 7'b0100000)
                                alu_op_sel = ALU_SUB;
                            else
                                illegal_instr = 1'b1;
                        end
                        3'b111: alu_op_sel = ALU_AND;
                        3'b110: alu_op_sel = ALU_OR;
                        3'b100: alu_op_sel = ALU_XOR;
                        3'b001: alu_op_sel = ALU_SLL;
                        3'b101: begin
                            if (funct7 == 7'b0000000)
                                alu_op_sel = ALU_SRL;
                            else
                                illegal_instr = 1'b1;
                        end
                        default: illegal_instr = 1'b1;
                    endcase
                end

                7'b0000011: begin // LOAD
                    if (funct3 == 3'b010) begin
                        if (load_hits_gpio) begin
                            start_gpio         = 1'b1;
                            start_gpio_is_load = 1'b1;
                            start_gpio_addr    = addr_load_candidate;
                            rf_we              = 1'b1;
                            rf_waddr           = rd;
                            rf_wdata           = gpio_read_data;
                        end else if (load_hits_uart0) begin
                            start_uart0         = 1'b1;
                            start_uart0_is_load = 1'b1;
                            start_uart0_addr    = addr_load_candidate;
                            rf_we               = 1'b1;
                            rf_waddr            = rd;
                            rf_wdata            = uart0_read_data;
                        end else if (load_hits_spi0) begin
                            start_spi0         = 1'b1;
                            start_spi0_is_load = 1'b1;
                            start_spi0_addr    = addr_load_candidate;
                            rf_we              = 1'b1;
                            rf_waddr           = rd;
                            rf_wdata           = spi0_read_data;
                        end else if (load_hits_i2c0) begin
                            start_i2c0         = 1'b1;
                            start_i2c0_is_load = 1'b1;
                            start_i2c0_addr    = addr_load_candidate;
                            rf_we              = 1'b1;
                            rf_waddr           = rd;
                            rf_wdata           = i2c0_read_data;
                        end else if (load_hits_can0) begin
                            start_can0         = 1'b1;
                            start_can0_is_load = 1'b1;
                            start_can0_addr    = addr_load_candidate;
                            rf_we              = 1'b1;
                            rf_waddr           = rd;
                            rf_wdata           = can0_read_data;
                        end else if (load_hits_timer0) begin
                            start_timer0         = 1'b1;
                            start_timer0_is_load = 1'b1;
                            start_timer0_addr    = addr_load_candidate;
                            rf_we                = 1'b1;
                            rf_waddr             = rd;
                            rf_wdata             = timer0_read_data;
                        end else if (!dmem_pending) begin
                            start_mem         = 1'b1;
                            start_mem_is_load = 1'b1;
                            start_mem_addr    = addr_load_candidate;
                            start_mem_rd      = rd;
                        end
                        if (!load_hits_gpio && !load_hits_uart0 && !load_hits_spi0 && !load_hits_i2c0 && !load_hits_can0 && !load_hits_timer0)
                            stall_ex = (dmem_pending && !mem_ready_in) || start_mem;
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                7'b0100011: begin // STORE
                    if (funct3 == 3'b010) begin
                        if (store_hits_gpio) begin
                            start_gpio         = 1'b1;
                            start_gpio_is_load = 1'b0;
                            start_gpio_addr    = addr_store_candidate;
                            start_gpio_wdata   = ex_rs2_val;
                        end else if (store_hits_uart0) begin
                            start_uart0         = 1'b1;
                            start_uart0_is_load = 1'b0;
                            start_uart0_addr    = addr_store_candidate;
                            start_uart0_wdata   = ex_rs2_val;
                        end else if (store_hits_spi0) begin
                            start_spi0         = 1'b1;
                            start_spi0_is_load = 1'b0;
                            start_spi0_addr    = addr_store_candidate;
                            start_spi0_wdata   = ex_rs2_val;
                        end else if (store_hits_i2c0) begin
                            start_i2c0         = 1'b1;
                            start_i2c0_is_load = 1'b0;
                            start_i2c0_addr    = addr_store_candidate;
                            start_i2c0_wdata   = ex_rs2_val;
                        end else if (store_hits_can0) begin
                            start_can0         = 1'b1;
                            start_can0_is_load = 1'b0;
                            start_can0_addr    = addr_store_candidate;
                            start_can0_wdata   = ex_rs2_val;
                        end else if (store_hits_timer0) begin
                            start_timer0         = 1'b1;
                            start_timer0_is_load = 1'b0;
                            start_timer0_addr    = addr_store_candidate;
                            start_timer0_wdata   = ex_rs2_val;
                        end else if (!dmem_pending) begin
                            start_mem         = 1'b1;
                            start_mem_is_load = 1'b0;
                            start_mem_addr    = addr_store_candidate;
                            start_mem_wdata   = ex_rs2_val;
                        end
                        if (!store_hits_gpio && !store_hits_uart0 && !store_hits_spi0 && !store_hits_i2c0 && !store_hits_can0 && !store_hits_timer0)
                            stall_ex = (dmem_pending && !mem_ready_in) || start_mem;
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                7'b1100011: begin // BRANCH
                    case (funct3)
                        3'b000: branch_taken = (ex_rs1_val == ex_rs2_val); // BEQ
                        3'b001: branch_taken = (ex_rs1_val != ex_rs2_val); // BNE
                        3'b100: branch_taken = ($signed(ex_rs1_val) < $signed(ex_rs2_val)); // BLT
                        3'b101: branch_taken = ($signed(ex_rs1_val) >= $signed(ex_rs2_val)); // BGE
                        3'b110: branch_taken = (ex_rs1_val < ex_rs2_val);   // BLTU
                        3'b111: branch_taken = (ex_rs1_val >= ex_rs2_val);  // BGEU
                        default: illegal_instr = 1'b1;
                    endcase
                    if (branch_taken) begin
                        branch_target = ex_pc + imm_b;
                        flush_pipe    = 1'b1;
                    end
                end

                7'b1101111: begin // JAL
                    rf_we        = 1'b1;
                    rf_waddr     = rd;
                    rf_wdata     = pc_plus4;
                    branch_taken = 1'b1;
                    branch_target= ex_pc + imm_j;
                    flush_pipe   = 1'b1;
                end

                7'b1100111: begin // JALR
                    if (funct3 == 3'b000) begin
                        rf_we        = 1'b1;
                        rf_waddr     = rd;
                        rf_wdata     = pc_plus4;
                        branch_taken = 1'b1;
                        branch_target= { jalr_sum[31:1], 1'b0 };
                        flush_pipe   = 1'b1;
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                7'b1110011: begin // SYSTEM
                    if (funct3 == 3'b001) begin
                        rf_we        = (rd != 0);
                        rf_waddr     = rd;
                        rf_wdata     = csr_read_data;
                        csr_write_en   = 1'b1;
                        csr_write_addr = ex_instr[31:20];
                        csr_write_data = ex_rs1_val;
                    end else if (funct3 == 3'b010) begin
                        rf_we        = (rd != 0);
                        rf_waddr     = rd;
                        rf_wdata     = csr_read_data;
                        csr_write_en   = (rs1 != 0);
                        csr_write_addr = ex_instr[31:20];
                        csr_write_data = csr_read_data | ex_rs1_val;
                    end else if (funct3 == 3'b011) begin
                        rf_we        = (rd != 0);
                        rf_waddr     = rd;
                        rf_wdata     = csr_read_data;
                        csr_write_en   = (rs1 != 0);
                        csr_write_addr = ex_instr[31:20];
                        csr_write_data = csr_read_data & ~ex_rs1_val;
                    end else if (funct3 == 3'b000 && ex_instr[31:20] == 12'b0) begin
                        trap_request    = 1'b1;
                        trap_target     = csr_mtvec;
                        trap_cause      = MCAUSE_ECALL;
                        trap_mepc_value = ex_pc;
                    end else if (funct3 == 3'b000 && ex_instr[31:20] == 12'h302) begin
                        branch_taken = 1'b1;
                        branch_target= csr_mepc;
                        flush_pipe   = 1'b1;
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                7'b0110111: begin // LUI
                    rf_we    = 1'b1;
                    rf_waddr = rd;
                    rf_wdata = imm_u;
                end

                7'b0010111: begin // AUIPC
                    rf_we    = 1'b1;
                    rf_waddr = rd;
                    rf_wdata = ex_pc + imm_u;
                end

                default: begin
                    if (ex_instr != 32'b0)
                        illegal_instr = 1'b1;
                end
            endcase
        end

        if (load_commit) begin
            rf_we    = 1'b1;
        rf_waddr = load_commit_rd;
        rf_wdata = mem_rdata_word;
        end

        if (illegal_instr && ex_active) begin
            trap_request    = 1'b1;
            trap_target     = csr_mtvec;
            trap_cause      = MCAUSE_ILLEGAL;
            trap_mepc_value = ex_pc;
        end

        if (!trap_request) begin
            if (take_timer_irq) begin
                trap_request    = 1'b1;
                trap_target     = csr_mtvec;
                trap_cause      = MCAUSE_TIMER_IRQ;
                if (ex_valid)
                    trap_mepc_value = ex_pc;
                else if (id_valid)
                    trap_mepc_value = id_pc;
                else if (if_valid)
                    trap_mepc_value = if_pc;
                else
                    trap_mepc_value = pc_fetch;
            end else if (take_ext_irq) begin
                trap_request    = 1'b1;
                trap_target     = csr_mtvec;
                trap_cause      = MCAUSE_EXT_IRQ;
                if (ex_valid)
                    trap_mepc_value = ex_pc;
                else if (id_valid)
                    trap_mepc_value = id_pc;
                else if (if_valid)
                    trap_mepc_value = if_pc;
                else
                    trap_mepc_value = pc_fetch;
            end
        end
    end

    // ------------------------------------------------------------
    // Interrupt detection
    // ------------------------------------------------------------
    wire timer_trigger_level = ((csr_mtime >= csr_mtimecmp) || irq_timer || timer0_irq);
    wire external_trigger_level = irq_external | uart0_irq | can0_irq | gpio_irq | spi0_irq | i2c0_irq;
    wire timer_pending   = csr_mip[7];
    wire external_pending= csr_mip[11];
    
    wire global_mie = csr_mstatus[3];
    wire timer_enabled = csr_mie[7];
    wire ext_enabled   = csr_mie[11];

    wire timer_can_fire = global_mie && timer_enabled && timer_pending;
    wire ext_can_fire   = global_mie && ext_enabled && external_pending;

    wire take_timer_irq = timer_can_fire && (!ext_can_fire || !csr_irq_priority);
    wire take_ext_irq   = ext_can_fire && (!timer_can_fire || csr_irq_priority);

    // ------------------------------------------------------------
    // Pipeline + state update
    // ------------------------------------------------------------
    wire ex_can_accept = !ex_valid || !stall_ex;
    wire id_stall = load_use_hazard || (!ex_can_accept && id_valid);
    wire id_accept = if_valid && !id_valid && !id_stall;
    wire [1:0] if_buf_count = if_valid ? 2'd1 : 2'd0;
    wire [1:0] slot_buf_count = prefetch_slot_valid ? 2'd1 : 2'd0;
    wire [1:0] fetch_buffer_occupancy = if_buf_count + slot_buf_count;
    wire slot_to_if = prefetch_slot_valid && (!if_valid || id_accept);
    wire if_fetch_target = (!if_valid || id_accept) && !slot_to_if;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_fetch          <= 32'b0;
            fetch_req_pending <= 1'b0;
            fetch_req_addr    <= 32'b0;
            if_valid          <= 1'b0;
            if_instr          <= 32'b0;
            if_pc             <= 32'b0;
            prefetch_slot_valid <= 1'b0;
            prefetch_slot_instr <= 32'b0;
            prefetch_slot_pc  <= 32'b0;
            fetch_req_cacheable <= 1'b0;
            icache_fill_index <= {ICACHE_INDEX_BITS{1'b0}};
            icache_fill_tag   <= {ICACHE_TAG_BITS{1'b0}};
            id_valid          <= 1'b0;
            id_instr          <= 32'b0;
            id_pc             <= 32'b0;
            ex_valid          <= 1'b0;
            ex_instr          <= 32'b0;
            ex_pc             <= 32'b0;
            ex_rs1_val        <= 32'b0;
            ex_rs2_val        <= 32'b0;
            dmem_pending      <= 1'b0;
            dmem_is_load      <= 1'b0;
            dmem_rd           <= 5'd0;
            mem_req_valid     <= 1'b0;
            mem_req_we        <= 1'b0;
            mem_req_addr      <= 32'b0;
            mem_req_wdata     <= {DMEM_DATA_WIDTH{1'b0}};
            csr_mstatus       <= 32'b0;
            csr_mtvec         <= 32'h00000100;
            csr_mepc          <= 32'b0;
            csr_mcause        <= 32'b0;
            csr_mie           <= 32'b0;
            csr_mip           <= 32'b0;
            csr_mtime         <= 32'b0;
            csr_mtimecmp      <= 32'd200;
            csr_irq_priority  <= 1'b0;
            irq_timer_ack     <= 1'b0;
            irq_external_ack  <= 1'b0;
            for (icache_init_idx = 0; icache_init_idx < REAL_ICACHE_ENTRIES; icache_init_idx = icache_init_idx + 1) begin
                icache_valid[icache_init_idx] <= 1'b0;
                icache_data[icache_init_idx]  <= 32'b0;
                icache_tag[icache_init_idx]   <= {ICACHE_TAG_BITS{1'b0}};
            end
        end else begin
            irq_timer_ack    <= 1'b0;
            irq_external_ack <= 1'b0;
            csr_mtime <= csr_mtime + 32'd1;
            if (csr_write_en && csr_write_addr == CSR_ADDR_MIP) begin
                csr_mip <= csr_write_data;
            end else begin
                csr_mip[7]  <= timer_trigger_level;
                csr_mip[11] <= external_trigger_level;
            end

            // Fetch management
            if (trap_request || flush_pipe) begin
                pc_fetch            <= trap_request ? trap_target : branch_target;
                fetch_req_pending   <= 1'b0;
                fetch_req_cacheable <= 1'b0;
                if_valid            <= 1'b0;
                prefetch_slot_valid <= 1'b0;
                id_valid            <= 1'b0;
                ex_valid            <= 1'b0;
            end else begin
                if (!fetch_req_pending && (fetch_buffer_occupancy < PREFETCH_DEPTH)) begin
                    if (icache_lookup_hit) begin
                        if (if_fetch_target) begin
                            if_valid <= 1'b1;
                            if_instr <= icache_lookup_word;
                            if_pc    <= pc_fetch;
                        end else begin
                            prefetch_slot_valid <= 1'b1;
                            prefetch_slot_instr <= icache_lookup_word;
                            prefetch_slot_pc    <= pc_fetch;
                        end
                        pc_fetch <= pc_fetch + 32'd4;
                    end else begin
                        fetch_req_pending   <= 1'b1;
                        fetch_req_addr      <= pc_fetch;
                        fetch_req_cacheable <= (ICACHE_ENABLED != 0);
                        icache_fill_index   <= next_cache_index;
                        icache_fill_tag     <= next_cache_tag;
                        pc_fetch            <= pc_fetch + 32'd4;
                    end
                end

                if (id_accept) begin
                    id_valid <= 1'b1;
                    id_instr <= if_instr;
                    id_pc    <= if_pc;
                    if_valid <= 1'b0;
                end

                if (slot_to_if) begin
                    if_valid            <= 1'b1;
                    if_instr            <= prefetch_slot_instr;
                    if_pc               <= prefetch_slot_pc;
                    prefetch_slot_valid <= 1'b0;
                end

                if (fetch_req_pending && imem_ready_in) begin
                    fetch_req_pending <= 1'b0;
                    if (if_fetch_target) begin
                        if_valid <= 1'b1;
                        if_instr <= imem_instr_word;
                        if_pc    <= fetch_req_addr;
                    end else begin
                        prefetch_slot_valid <= 1'b1;
                        prefetch_slot_instr <= imem_instr_word;
                        prefetch_slot_pc    <= fetch_req_addr;
                    end
                    if (fetch_req_cacheable && (ICACHE_ENABLED != 0)) begin
                        icache_data[icache_fill_index]  <= imem_instr_word;
                        icache_tag[icache_fill_index]   <= icache_fill_tag;
                        icache_valid[icache_fill_index] <= 1'b1;
                    end
                    fetch_req_cacheable <= 1'b0;
                end

                if (id_valid && !id_stall && ex_can_accept) begin
                    ex_valid   <= 1'b1;
                    ex_instr   <= id_instr;
                    ex_pc      <= id_pc;
                    ex_rs1_val <= forward_rs1;
                    ex_rs2_val <= forward_rs2;
                    id_valid   <= 1'b0;
                end else if (ex_valid && !stall_ex) begin
                    ex_valid <= 1'b0;
                end
            end

            if (start_mem && !dmem_pending) begin
                mem_req_valid <= 1'b1;
                mem_req_we    <= !start_mem_is_load;
                mem_req_addr  <= start_mem_addr;
                mem_req_wdata <= start_mem_wdata;
                dmem_pending  <= 1'b1;
                dmem_is_load  <= start_mem_is_load;
                dmem_rd       <= start_mem_rd;
            end else if (dmem_pending && mem_ready_in) begin
                mem_req_valid <= 1'b0;
                dmem_pending  <= 1'b0;
`ifdef CORE_DEBUG
                $display("DMEM handshake complete @%0t", $time);
`endif
            end

            if (csr_write_en) begin
                case (csr_write_addr)
                    CSR_ADDR_MSTATUS:  csr_mstatus <= csr_write_data;
                    CSR_ADDR_MTVEC:    csr_mtvec   <= csr_write_data;
                    CSR_ADDR_MEPC:     csr_mepc    <= csr_write_data;
                    CSR_ADDR_MCAUSE:   csr_mcause  <= csr_write_data;
                    CSR_ADDR_MIE:      csr_mie     <= csr_write_data;
                    CSR_ADDR_MTIME:    csr_mtime   <= csr_write_data;
                    CSR_ADDR_MTIMECMP: csr_mtimecmp<= csr_write_data;
                    CSR_ADDR_IRQ_PRIORITY: csr_irq_priority <= csr_write_data[0];
                    CSR_ADDR_IRQ_ACK: begin
                        if (csr_write_data[0])
                            irq_timer_ack <= 1'b1;
                        if (csr_write_data[1]) begin
                            irq_external_ack <= 1'b1;
                            csr_mip[11] <= 1'b0;
                        end
                    end
                    default: ;
                endcase
            end

            if (trap_request) begin
                csr_mepc   <= trap_mepc_value;
                csr_mcause <= trap_cause;
                csr_mstatus[7] <= csr_mstatus[3];
                csr_mstatus[3] <= 1'b0;
            end else if (ex_active && opcode == 7'b1110011 && funct3 == 3'b000 && ex_instr[31:20] == 12'h302 && !illegal_instr) begin
                csr_mstatus[3] <= csr_mstatus[7];
                csr_mstatus[7] <= 1'b1;
            end
        end
    end

`ifdef CORE_DEBUG
    always @(posedge clk) begin
        if (ex_valid)
            $display("CORE EX pc=%h instr=%h stall=%b", ex_pc, ex_instr, stall_ex);
        if (csr_write_en)
            $display("CSR WRITE addr=0x%03h data=0x%08h", csr_write_addr, csr_write_data);
    end
`endif

endmodule

`default_nettype wire
