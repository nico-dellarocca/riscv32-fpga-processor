# First experiment: blink an LED

This small Verilog module uses the Tang Nano 20K's 27 MHz clock. A counter counts up and flips the LED output roughly every half second. LED0 is active-low, so a logic **0** turns it on.

The **original supplied project log** reports building and loading this example onto the board on October 19, 2026. The package itself does not contain a new video proving the visible blink, and this basic circuit is separate from the newer RISC-V CPU.

From the repository root, with Gowin-compatible FPGA tools installed:

```sh
make blink
make program-blink
```

With Icarus Verilog installed, you can test only this small example:

```sh
mkdir -p build
iverilog -g2012 -s tb_blink -o build/blink_test.vvp \
  examples/01_blink/blink.v examples/01_blink/tb_blink.v
vvp build/blink_test.vvp
```

The testbench uses a much smaller counter limit so it doesn't need millions of simulation cycles. Real hardware still uses the full divider. The clock pin is `4`, LED0 is pin `15`, and the constraints use `LVCMOS33`.

**Things to understand:** Why does this need a counter? What would happen if you changed the count? Why is the LED inverted?

[Official board example](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/led.html)
