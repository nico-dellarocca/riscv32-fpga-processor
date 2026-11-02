`timescale 1ns/1ps
`default_nettype none

module tb_blink;
    reg clk = 1'b0;
    wire led0_n;
    integer cycle;
    integer changes = 0;
    reg last_led;
    reg expected_led;

    blink #(.COUNTER_BITS(4)) dut (.clk(clk), .led0_n(led0_n));
    always #5 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/blink.vcd");
            $dumpvars(0, tb_blink);
        end
        #1;
        if (led0_n !== 1'b1)
            $fatal(1, "FAIL blink: LED must start off (pin high)");
        last_led = led0_n;
        for (cycle = 1; cycle <= 32; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            // Four expected intervals: off/on/off/on, eight clocks each.
            if (cycle < 8 || (cycle >= 16 && cycle < 24) || cycle == 32)
                expected_led = 1'b1;
            else
                expected_led = 1'b0;
            if (led0_n !== expected_led)
                $fatal(1, "FAIL blink: cycle=%0d pin=%b expected=%b",
                       cycle, led0_n, expected_led);
            if (led0_n != last_led)
                changes = changes + 1;
            last_led = led0_n;
        end
        if (changes != 4)
            $fatal(1, "FAIL blink: expected four transitions, got %0d", changes);
        $display("PASS blink: pin toggles every 8 clocks; 4 transitions in 32 clocks");
        $finish;
    end
endmodule

`default_nettype wire
