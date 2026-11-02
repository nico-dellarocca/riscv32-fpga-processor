`timescale 1ns/1ps
module tb_soc;
    reg clk = 0;
    always #5 clk = ~clk; // Fast simulated clock; no board timing claim.
    reg reset = 1;
    reg button_pressed = 1;
    wire led, halted, sim_done;
    wire [31:0] fault_pc, sim_code;
    wire [3:0] fault_code;
    rv32_soc #(.INIT_FILE(""), .SIMULATION(1)) dut (
        .clk(clk), .reset(reset), .button_pressed(button_pressed), .led(led),
        .halted(halted), .fault_pc(fault_pc), .fault_code(fault_code),
        .sim_done(sim_done), .sim_code(sim_code)
    );

    integer led_writes = 0;
    reg track_led = 0;
    reg expected_led;
    // Observe requested GPIO values, including the initial write of zero.
    always @(posedge clk) begin
        if (!reset && track_led && dut.mem_req && !dut.mem_fault &&
            dut.mem_addr == 32'h10000000 && dut.mem_wstrb[0]) begin
            case (led_writes)
                0, 2: if (dut.mem_wdata[0] !== 1'b0)
                    $fatal(1, "LED write %0d must be zero", led_writes);
                1: if (dut.mem_wdata[0] !== 1'b1)
                    $fatal(1, "LED write 1 must be one");
                default: $fatal(1, "unexpected additional LED write");
            endcase
            expected_led = dut.mem_wdata[0];
            led_writes = led_writes + 1;
            #1;
            if (led !== expected_led)
                $fatal(1, "LED register failed to update after accepted write");
        end
    end

    reg [31:0] bss_bounds [0:1];
    integer word_index;
    integer cycles;
    task run_image;
        input [1023:0] filename;
        input check_led;
        input poison_bss;
        begin
            @(negedge clk);
            reset = 1;
            track_led = 0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            $readmemh(filename, dut.ram);
            if (poison_bss) begin
                $readmemh("sim/programs/c_smoke.bss", bss_bounds);
                if (bss_bounds[0] >= bss_bounds[1] || bss_bounds[1] > 32'h4000 ||
                    bss_bounds[0][1:0] != 0 || bss_bounds[1][1:0] != 0)
                    $fatal(1, "invalid C .bss metadata");
                for (word_index = bss_bounds[0] >> 2;
                    word_index < (bss_bounds[1] >> 2); word_index = word_index + 1)
                    dut.ram[word_index] = 32'hdeadbeef;
            end
            led_writes = 0;
            track_led = check_led;
            reset = 0;
            cycles = 0;
            while (!sim_done && !halted && cycles < 100000) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
            end
            if (halted) $fatal(1, "%0s halted: PC=%08x fault=%0d",
                filename, fault_pc, fault_code);
            if (!sim_done) $fatal(1, "%0s timed out", filename);
            if (sim_code !== 32'd1) $fatal(1, "%0s firmware FAIL code=%08x", filename, sim_code);
            if (check_led && (led_writes != 3 || led !== 0))
                $fatal(1, "%0s LED sequence incomplete: writes=%0d final=%b",
                    filename, led_writes, led);
            $display("PASS SoC %0s cycles=%0d LED_writes=%0d", filename, cycles, led_writes);
        end
    endtask

    // Test the real SoC decoder, independently of firmware self-checks.
    task rejected_store;
        input [31:0] address_setup;
        input [31:0] store_instruction;
        input [1023:0] label;
        begin
            @(negedge clk); reset = 1; track_led = 0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            dut.ram[0] = address_setup;
            dut.ram[1] = 32'h00100113; // addi x2,x0,1
            dut.ram[2] = store_instruction;
            reset = 0;
            cycles = 0;
            while (!halted && cycles < 50) begin
                @(posedge clk); #1; cycles = cycles + 1;
            end
            if (!halted || fault_code !== 4 || fault_pc !== 8 || led !== 0 || sim_done)
                $fatal(1, "%0s: wrong fault or a forbidden side effect", label);
            if (dut.ram[0] !== address_setup)
                $fatal(1, "%0s: bad address aliased RAM", label);
            $display("PASS SoC rejects %0s", label);
        end
    endtask

    initial begin
        run_image("sim/programs/arithmetic.mem", 0, 0);
        run_image("sim/programs/memory.mem", 0, 0);
        run_image("sim/programs/branch.mem", 0, 0);
        run_image("sim/programs/led.mem", 1, 0);
        run_image("sim/programs/c_smoke.mem", 1, 1);
        rejected_store(32'h100000b7, 32'h0020a223, "write to read-only button");
        rejected_store(32'h000040b7, 32'h0020a023, "store above 16 KiB RAM");
        rejected_store(32'h100000b7, 32'h00208823, "byte store to word-only PASS");
        $display("PASS tb_soc");
        $finish;
    end
endmodule
