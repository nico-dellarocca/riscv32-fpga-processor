`timescale 1ns/1ps
// 16 KiB unified RAM and three small MMIO registers. No variable-latency bus.
module rv32_soc #(
    parameter INIT_FILE = "sim/programs/led_hw.mem",
    parameter SIMULATION = 0
) (
    input wire clk,
    input wire reset,
    input wire button_pressed,
    output reg led,
    output wire halted,
    output wire [31:0] fault_pc,
    output wire [3:0] fault_code,
    output reg sim_done,
    output reg [31:0] sim_code
);
    wire mem_req;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    wire mem_fault;
    wire writing = |mem_wstrb;
    wire ram_selected = (mem_addr[31:14] == 18'b0);
    wire led_selected = (mem_addr[31:2] == (32'h10000000 >> 2));
    wire button_selected = (mem_addr[31:2] == (32'h10000004 >> 2));
    wire completion_selected = (mem_addr == 32'h10000010);

    // The completion address is write-only, full-word, and absent in hardware.
    assign mem_fault = mem_req && !(ram_selected || led_selected ||
        (button_selected && !writing) ||
        (SIMULATION && completion_selected && mem_wstrb == 4'b1111));

    rv32i_core cpu (
        .clk(clk), .reset(reset), .mem_req(mem_req),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata), .mem_fault(mem_fault),
        .halted(halted), .fault_pc(fault_pc), .fault_code(fault_code)
    );

    reg [31:0] ram [0:4095];
    reg [31:0] ram_rdata;
    reg [31:0] io_rdata;
    reg read_was_ram;
    integer i;
    initial begin
        // Configuration-time initialization, NOT a clocked 4096-word reset.
        // Zero padding is deliberately illegal if execution leaves the program.
        for (i = 0; i < 4096; i = i + 1)
            ram[i] = 32'b0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, ram);
    end

    // Keep the RAM's synchronous read register separate from the MMIO mux.
    // This shape permits block-RAM inference; synthesis evidence is separate.
    always @(posedge clk) begin
        if (!reset && mem_req && !mem_fault && ram_selected) begin
            if (mem_wstrb[0]) ram[mem_addr[13:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) ram[mem_addr[13:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) ram[mem_addr[13:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) ram[mem_addr[13:2]][31:24] <= mem_wdata[31:24];
            if (!writing) ram_rdata <= ram[mem_addr[13:2]];
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            led <= 1'b0;
            sim_done <= 1'b0;
            sim_code <= 32'b0;
            io_rdata <= 32'b0;
            read_was_ram <= 1'b0;
        end else if (mem_req && !mem_fault) begin
            if (!writing) begin
                read_was_ram <= ram_selected;
                if (led_selected) io_rdata <= {31'b0, led};
                else if (button_selected) io_rdata <= {31'b0, button_pressed};
            end else begin
                // Other LED bits are reserved, read zero, and ignore writes.
                if (led_selected && mem_wstrb[0]) led <= mem_wdata[0];
                if (SIMULATION && completion_selected) begin
                    sim_done <= 1'b1;
                    sim_code <= mem_wdata;
                end
            end
        end
    end

    // Both mux inputs and its selector were registered at the request edge.
    assign mem_rdata = read_was_ram ? ram_rdata : io_rdata;
endmodule
