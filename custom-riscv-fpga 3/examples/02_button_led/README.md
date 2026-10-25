# Next experiment: button controls LED

This is a simple connection between the onboard S1 button and LED0. Both are active-low: pressing the button makes the input `0`, and output `0` turns the LED on.

The Verilog and testbench are included, but **this button experiment has not been confirmed on a physical board**. Check the S1 pin against the schematic for your board revision before programming it (the supplied constraint file currently uses pin 88).

From the project root:

```sh
make button
make program-button
```

To run only the small Verilog testbench using Icarus:

```sh
mkdir -p build
iverilog -g2012 -s tb_button_led -o build/button_test.vvp \
  examples/02_button_led/button_led.v examples/02_button_led/tb_button_led.v
vvp build/button_test.vvp
```

After trying it on a board, record what happened in [`MY_WORK.md`](../../MY_WORK.md). This is an immediate combinational example; a proper processor input would need a synchronizer and usually debounce logic.
