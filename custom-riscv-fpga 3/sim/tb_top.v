`timescale 1ns/1ps
// Use fast firmware to test the board wrapper and power-on reset in Icarus.
// Physical pin voltages are *not* verified by this simulation.
module tb_top;
    reg clk = 0;
    reg button_n = 1;
    wire led_n;
    integer changes = 0;
    integer cycles = 0;
    reg last_led = 1;
    always #5 clk = ~clk;

    tangnano20k_top #(.MEM_FILE("software/build/gpio_fast.hex")) dut (
        .clk_27mhz(clk), .button_n(button_n), .led_n(led_n)
    );

    initial begin
        repeat (2) @(negedge clk);
        if (led_n !== 1'b1) $fatal(1, "LED not off during reset");
    end
    always @(negedge clk) begin
        cycles = cycles + 1;
        if (led_n !== last_led) begin
            changes = changes + 1;
            last_led = led_n;
        end
        if (dut.soc.halted) $fatal(1, "CPU halted unexpectedly");
        if (changes == 4) begin
            $display("PASS top power-on reset and LED output toggles=%0d", changes);
            $finish;
        end
        if (cycles > 15000) $fatal(1, "Board top timeout");
    end
endmodule
