// Milestone 00: Blink onboard LED0 using the 27 MHz Tang Nano 20K clock.
// The original hardware session used a hard-coded 13,500,000-cycle count.
// The parameter here preserves the hardware timing and allows fast simulation.
module blink #(
    parameter integer HALF_PERIOD_CYCLES = 13_500_000
) (
    input  wire clk,
    output reg  led = 1'b1
);
    // 2^24 = 16,777,216 > 13,500,000, so 24 bits are enough.
    reg [23:0] counter = 24'd0;

    always @(posedge clk) begin
        if (counter == HALF_PERIOD_CYCLES - 1) begin
            counter <= 24'd0;
            led <= ~led;
        end else begin
            counter <= counter + 1'b1;
        end
    end
endmodule
