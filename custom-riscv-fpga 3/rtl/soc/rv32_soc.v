// RV32I core with 16 KiB synchronous single-port RAM, GPIO and a simulation
// completion signature. This is a synthesizable teaching SoC, not yet proven
// to fit/timing-close on the physical Tang Nano 20K.
//
// Region 0x0000_0000..0x0000_3fff: byte-addressed on-chip RAM
// 0x1000_0000: GPIO output, bit 0=logical LED on
// 0x1000_0004: GPIO input, bit 0=logical button pressed
// 0x1000_0010: simulation status latch (write-only; no physical effect)
// All other reads return zero; unmapped writes are discarded.
module rv32_soc #(
    parameter MEM_FILE = "",
    parameter integer RAM_WORDS = 4096
)(
    input wire clk,
    input wire reset,
    input wire button_n,
    output wire led_n,
    output reg [31:0] gpio_out,
    output reg test_done,
    output reg [31:0] test_code,
    output wire halted,
    output wire [3:0] halt_reason,
    output wire trace_valid,
    output wire [31:0] trace_pc,
    output wire [31:0] trace_insn,
    output wire [4:0] trace_rd,
    output wire [31:0] trace_value,
    output wire [3:0] trace_store_mask,
    output wire [31:0] trace_store_addr,
    output wire [31:0] trace_store_data
);
    wire bus_valid, bus_write;
    wire [31:0] bus_addr, bus_wdata;
    wire [3:0] bus_wstrb;
    reg [31:0] bus_rdata;
    reg [31:0] ram [0:RAM_WORDS-1];
    wire ram_sel = bus_addr < (RAM_WORDS * 4);
    wire [11:0] word_index = bus_addr[13:2];
    integer i;

    // Initialized on power-up (synthesis with Gowin BRAM initialization
    // support) and in simulations. No runtime bootloader is implemented.
    initial begin
        for (i = 0; i < RAM_WORDS; i = i + 1) ram[i] = 32'h00000013;
        if (MEM_FILE != "") $readmemh(MEM_FILE, ram);
    end

    assign led_n = ~gpio_out[0];

    rv32i_core cpu (
        .clk(clk), .reset(reset),
        .mem_valid(bus_valid), .mem_write(bus_write),
        .mem_addr(bus_addr), .mem_wdata(bus_wdata), .mem_wstrb(bus_wstrb),
        .mem_rdata(bus_rdata), .halted(halted), .halt_reason(halt_reason),
        .trace_valid(trace_valid), .trace_pc(trace_pc), .trace_insn(trace_insn),
        .trace_rd(trace_rd), .trace_value(trace_value),
        .trace_store_mask(trace_store_mask),
        .trace_store_addr(trace_store_addr), .trace_store_data(trace_store_data)
    );

    // This is a *registered* memory response. As a result the CPU never
    // assumes a combinational response from an FPGA block RAM.
    always @(posedge clk) begin
        if (reset) begin
            bus_rdata <= 32'd0;
            gpio_out <= 32'd0;
            test_done <= 1'b0;
            test_code <= 32'd0;
        end else if (bus_valid) begin
            if (ram_sel) begin
                bus_rdata <= ram[word_index];
                if (bus_write) begin
                    if (bus_wstrb[0]) ram[word_index][7:0] <= bus_wdata[7:0];
                    if (bus_wstrb[1]) ram[word_index][15:8] <= bus_wdata[15:8];
                    if (bus_wstrb[2]) ram[word_index][23:16] <= bus_wdata[23:16];
                    if (bus_wstrb[3]) ram[word_index][31:24] <= bus_wdata[31:24];
                end
            end else begin
                case (bus_addr & 32'hffff_fffc)
                    32'h1000_0000: begin
                        bus_rdata <= gpio_out;
                        if (bus_write) begin
                            if (bus_wstrb[0]) gpio_out[7:0] <= bus_wdata[7:0];
                            if (bus_wstrb[1]) gpio_out[15:8] <= bus_wdata[15:8];
                            if (bus_wstrb[2]) gpio_out[23:16] <= bus_wdata[23:16];
                            if (bus_wstrb[3]) gpio_out[31:24] <= bus_wdata[31:24];
                        end
                    end
                    32'h1000_0004: bus_rdata <= {31'd0, ~button_n};
                    32'h1000_0010: begin
                        bus_rdata <= 32'd0;
                        if (bus_write && bus_wstrb == 4'b1111) begin
                            test_done <= 1'b1;
                            test_code <= bus_wdata;
                        end
                    end
                    default: bus_rdata <= 32'd0;
                endcase
            end
        end
    end
endmodule
