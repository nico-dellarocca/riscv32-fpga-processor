// Milestone 01 (prepared, not yet hardware-verified): direct active-low input.
// Pressing the onboard S1 button drives button_n low; LED0 turns on when low.
// This is intentionally combinational. No debounce is required for this demo.
module button_led (
    input  wire button_n,
    output wire led
);
    assign led = button_n;
endmodule
