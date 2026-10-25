`timescale 1ns/1ps
// Integration testbench. External control from +image=... +scenario=...
// +scenario=signature/gpio/fault +reason=N, +max_cycles=N.
module tb_soc;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1;
    reg button_n = 1;
    wire led_n;
    wire [31:0] gpio_out;
    wire test_done;
    wire [31:0] test_code;
    wire halted;
    wire [3:0] halt_reason;
    wire trace_valid;
    wire [31:0] trace_pc, trace_insn, trace_value, trace_store_addr, trace_store_data;
    wire [4:0] trace_rd;
    wire [3:0] trace_store_mask;

    rv32_soc #(.MEM_FILE("")) dut (
        .clk(clk), .reset(reset), .button_n(button_n), .led_n(led_n),
        .gpio_out(gpio_out), .test_done(test_done), .test_code(test_code),
        .halted(halted), .halt_reason(halt_reason), .trace_valid(trace_valid),
        .trace_pc(trace_pc), .trace_insn(trace_insn), .trace_rd(trace_rd),
        .trace_value(trace_value), .trace_store_mask(trace_store_mask),
        .trace_store_addr(trace_store_addr), .trace_store_data(trace_store_data)
    );

    reg [1023:0] image_path;
    reg [255:0] scenario;
    integer max_cycles = 30000;
    integer expect_reason = 0;
    integer cycles = 0;
    integer transitions = 0;
    reg last_gpio = 0;
    integer retired = 0;

    initial begin
        if (!$value$plusargs("image=%s", image_path)) $fatal(1, "+image required");
        if (!$value$plusargs("scenario=%s", scenario)) $fatal(1, "+scenario required");
        if ($value$plusargs("max_cycles=%d", max_cycles)) begin end
        if ($value$plusargs("reason=%d", expect_reason)) begin end
        #2;
        $readmemh(image_path, dut.ram);
        repeat (5) @(negedge clk);
        reset = 0;
    end

    always @(negedge clk) begin
        if (!reset) begin
            cycles = cycles + 1;
            if (trace_valid) begin
                retired = retired + 1;
                $display("TRACE %08x %08x %02x %08x %1x %08x %08x",
                    trace_pc, trace_insn, trace_rd, trace_value,
                    trace_store_mask, trace_store_addr, trace_store_data);
            end
            if (gpio_out[0] !== last_gpio) begin
                transitions = transitions + 1;
                last_gpio = gpio_out[0];
            end
            if (halted) begin
                if (scenario == "fault" && halt_reason == expect_reason) begin
                    $display("PASS fault reason=%0d cycles=%0d", halt_reason, cycles);
                    $finish;
                end
                $fatal(1, "Unexpected CPU stop: reason=%0d pc=%08x", halt_reason, dut.cpu.pc);
            end
            if (scenario == "signature" && test_done) begin
                if (test_code != 32'h600d600d) $fatal(1, "FAIL signature %08x", test_code);
                if (gpio_out[0] !== 1'b1) $fatal(1, "Signature reached without GPIO=1");
                if (retired == 0) $fatal(1, "No CPU instructions retired");
                $display("PASS signature=%08x cycles=%0d retired=%0d", test_code, cycles, retired);
                $finish;
            end
            if (scenario == "gpio" && transitions >= 4) begin
                $display("PASS gpio transitions=%0d cycles=%0d retired=%0d", transitions, cycles, retired);
                $finish;
            end
            if (cycles >= max_cycles) $fatal(1, "Timeout at pc=%08x", dut.cpu.pc);
        end
    end
endmodule
