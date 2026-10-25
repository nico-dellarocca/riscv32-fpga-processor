`timescale 1ns/1ps
module tb_blink;
    reg clk = 1'b0;
    wire led;
    reg expected_led;
    integer cycle;

    // Use 4 clocks in simulation to avoid 13.5 million clock delays.
    blink #(.HALF_PERIOD_CYCLES(4)) dut (
        .clk(clk), .led(led)
    );

    always #5 clk = ~clk;

    initial begin
        expected_led = 1'b1;
        #1;
        if (led !== expected_led) $fatal(1, "LED initial state wrong");

        for (cycle = 1; cycle <= 20; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if (cycle % 4 == 0) expected_led = ~expected_led;
            if (led !== expected_led) begin
                $fatal(1, "LED mismatch at cycle %0d", cycle);
            end
        end
        $display("PASS: blink toggles every 4 test clocks (20 clocks tested)");
        $finish;
    end
endmodule
