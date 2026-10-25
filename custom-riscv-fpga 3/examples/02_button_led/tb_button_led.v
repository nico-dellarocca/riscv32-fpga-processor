`timescale 1ns/1ps
module tb_button_led;
    reg button_n;
    wire led;

    button_led dut (.button_n(button_n), .led(led));

    initial begin
        button_n = 1'b1;
        #1;
        if (led !== 1'b1) $fatal(1, "LED should be off when unpressed");

        button_n = 1'b0;
        #1;
        if (led !== 1'b0) $fatal(1, "LED should be on when pressed");

        button_n = 1'b1;
        #1;
        if (led !== 1'b1) $fatal(1, "LED should be off again");

        $display("PASS: active-low button directly drives active-low LED");
        $finish;
    end
endmodule
