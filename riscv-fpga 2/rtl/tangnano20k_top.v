`timescale 1ns/1ps
`default_nettype none

module tangnano20k_top #(
    parameter INIT_FILE = "sim/programs/led_hw.mem",
    parameter integer POR_BITS = 8
) (
    input wire clk,
    input wire button_s1,
    output wire led0_n
);
    // This FPGA-only startup scheme relies on configuration honoring the
    // initial register value. It is not an external reset or a power monitor.
    // Verify initialization in the target toolchain and by repeated board boots.
    reg [POR_BITS-1:0] powerup_count = {POR_BITS{1'b0}};
    wire reset = ~(&powerup_count);

    always @(posedge clk) begin
        if (reset)
            powerup_count <= powerup_count + 1'b1;
    end

    // PCB 3921 S1 is active HIGH. Two sampling stages reduce the probability
    // that metastability reaches the CPU. They do not debounce the switch.
    reg button_meta;
    reg button_sync;
    always @(posedge clk) begin
        if (reset) begin
            button_meta <= 1'b0;
            button_sync <= 1'b0;
        end else begin
            button_meta <= button_s1;
            button_sync <= button_meta;
        end
    end

    wire led;
    wire halted;
    wire [31:0] fault_pc;
    wire [3:0] fault_code;
    wire sim_done;
    wire [31:0] sim_code;

    rv32_soc #(.INIT_FILE(INIT_FILE), .SIMULATION(0)) soc (
        .clk(clk),
        .reset(reset),
        .button_pressed(button_sync),
        .led(led),
        .halted(halted),
        .fault_pc(fault_pc),
        .fault_code(fault_code),
        .sim_done(sim_done),
        .sim_code(sim_code)
    );

    assign led0_n = reset ? 1'b1 : ~led;
endmodule

`default_nettype wire
