// Tang Nano 20K demo top. The LED reflects GPIO writes made by the custom CPU.
// Constraint pins are carried forward from the original bring-up examples;
// clock/LED were programmed previously, button mapping remains provisional.
module tangnano20k_top #(
    parameter MEM_FILE = "software/build/gpio_demo.hex"
) (
    input  wire clk_27mhz,
    input  wire button_n,
    output wire led_n
);
    // SRAM/flip-flops need an initial reset after FPGA configuration. This
    // 16-cycle synchronous power-on reset is intentionally simple.
    reg [4:0] reset_count = 5'd0;
    wire reset = !reset_count[4];
    always @(posedge clk_27mhz)
        if (!reset_count[4]) reset_count <= reset_count + 5'd1;

    rv32_soc #(.MEM_FILE(MEM_FILE)) soc (
        .clk(clk_27mhz), .reset(reset), .button_n(button_n),
        .led_n(led_n), .gpio_out(), .test_done(), .test_code(),
        .halted(), .halt_reason(), .trace_valid(), .trace_pc(),
        .trace_insn(), .trace_rd(), .trace_value(),
        .trace_store_mask(), .trace_store_addr(), .trace_store_data()
    );
endmodule
