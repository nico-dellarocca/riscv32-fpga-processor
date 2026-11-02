`timescale 1ns/1ps
`default_nettype none

module tb_top;
    reg clk = 1'b0;
    reg button_s1 = 1'b0;
    wire led0_n;
    integer edge_number;
    integer timeout;
    reg saw_led_on = 1'b0;

    tangnano20k_top #(.INIT_FILE(""), .POR_BITS(3)) dut (
        .clk(clk), .button_s1(button_s1), .led0_n(led0_n)
    );
    always #5 clk = ~clk;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/top.vcd");
            $dumpvars(0, tb_top);
        end
        // Wait until the SoC's configuration-time RAM initialization finishes.
        #1;
        dut.soc.ram[0] = 32'h100000b7; // lui  x1,0x10000
        dut.soc.ram[1] = 32'h00100113; // addi x2,x0,1
        dut.soc.ram[2] = 32'h0020a023; // sw   x2,0(x1): logical LED on
        dut.soc.ram[3] = 32'h0020a823; // sw   x2,16(x1): absent in hardware

        if (dut.reset !== 1'b1 || led0_n !== 1'b1)
            $fatal(1, "FAIL top: startup must assert reset and hold LED off");

        // The seventh edge still presents reset=1 to the CPU. The counter
        // reaches seven after that edge and releases reset for edge eight.
        for (edge_number = 1; edge_number <= 7; edge_number = edge_number + 1) begin
            @(posedge clk);
            if (dut.reset !== 1'b1)
                $fatal(1, "FAIL top: reset released before edge %0d", edge_number);
            #1;
            if (dut.soc.cpu.pc !== 32'd0 || dut.halted !== 1'b0 ||
                dut.button_sync !== 1'b0 || led0_n !== 1'b1)
                $fatal(1, "FAIL top: architectural state changed during POR");
            if (edge_number < 7 && dut.reset !== 1'b1)
                $fatal(1, "FAIL top: reset interval is shorter than seven edges");
        end
        if (dut.reset !== 1'b0)
            $fatal(1, "FAIL top: reset did not release after seven edges");

        // Drive the asynchronous input between clock edges. The second stage
        // must retain its old value for one edge on both rising and falling input.
        @(negedge clk);
        button_s1 = 1'b1;
        @(posedge clk); #1;
        if (dut.button_meta !== 1'b1 || dut.button_sync !== 1'b0 ||
            dut.soc.button_pressed !== 1'b0)
            $fatal(1, "FAIL top: rising button bypassed first synchronizer stage");
        @(posedge clk); #1;
        if (dut.button_sync !== 1'b1 || dut.soc.button_pressed !== 1'b1)
            $fatal(1, "FAIL top: pressed S1 must become logical one after two edges");

        @(negedge clk);
        button_s1 = 1'b0;
        @(posedge clk); #1;
        if (dut.button_meta !== 1'b0 || dut.button_sync !== 1'b1 ||
            dut.soc.button_pressed !== 1'b1)
            $fatal(1, "FAIL top: falling button bypassed first synchronizer stage");
        @(posedge clk); #1;
        if (dut.button_sync !== 1'b0 || dut.soc.button_pressed !== 1'b0)
            $fatal(1, "FAIL top: released S1 must become logical zero after two edges");

        timeout = 0;
        while (dut.halted !== 1'b1 && timeout < 100) begin
            @(posedge clk); #1;
            timeout = timeout + 1;
            if (dut.reset !== 1'b0 || dut.powerup_count !== 3'd7)
                $fatal(1, "FAIL top: saturated startup counter restarted reset");
            if (led0_n !== ~dut.led)
                $fatal(1, "FAIL top: physical LED output must invert logical LED");
            if (dut.led === 1'b1 && led0_n === 1'b0)
                saw_led_on = 1'b1;
            if (dut.sim_done !== 1'b0)
                $fatal(1, "FAIL top: hardware wrapper exposed simulation completion");
        end
        if (dut.halted !== 1'b1)
            $fatal(1, "FAIL top: timeout waiting for forbidden MMIO fault");
        if (!saw_led_on || dut.led !== 1'b1 || led0_n !== 1'b0)
            $fatal(1, "FAIL top: executed GPIO store did not illuminate LED output");
        if (dut.fault_pc !== 32'd12 || dut.fault_code !== 4'd4 ||
            dut.sim_done !== 1'b0 || dut.sim_code !== 32'd0)
            $fatal(1, "FAIL top: hardware completion access pc=%h code=%0d done=%b",
                   dut.fault_pc, dut.fault_code, dut.sim_done);
        repeat (3) begin
            @(posedge clk); #1;
            if (dut.soc.mem_req !== 1'b0 || dut.halted !== 1'b1 ||
                dut.reset !== 1'b0 || led0_n !== 1'b0)
                $fatal(1, "FAIL top: fault must remain halted with LED state preserved");
        end
        $display("PASS top: 7-edge POR, two-stage S1 rise/fall, active-low LED, hardware MMIO rejection");
        $finish;
    end
endmodule

`default_nettype wire
