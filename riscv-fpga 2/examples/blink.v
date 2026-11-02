`timescale 1ns/1ps
`default_nettype none

// Milestone A: configure the FPGA with top module blink and blink.cst.
// The initial value must be preserved by FPGA configuration; verify this in
// the Gowin synthesis report and on the board before calling bring-up complete.
module blink #(
    parameter integer COUNTER_BITS = 25
) (
    input wire clk,
    output wire led0_n
);
    reg [COUNTER_BITS-1:0] counter = {COUNTER_BITS{1'b0}};

    always @(posedge clk)
        counter <= counter + 1'b1;

    // A 0 on the physical pin sinks current and illuminates LED0.
    assign led0_n = ~counter[COUNTER_BITS-1];
endmodule

`default_nettype wire
