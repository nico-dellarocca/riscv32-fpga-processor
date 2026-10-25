# Uploading this project to GitHub

1. Create a new **public** repository on [GitHub](https://github.com/new), perhaps named `custom-riscv-fpga`.
2. Upload the **contents** of the `custom-riscv-fpga` folder, not the ZIP file. Keep `README.md` at the top level.
3. Include the hidden `.github/` directory if uploading from the website. It contains the automated test workflow.
4. Open the **Actions** tab. If the workflow fails, read the log; don't assume it succeeded just because the test files exist.
5. Update [`MY_WORK.md`](../MY_WORK.md) with your actual steps and results. Add genuine commits as the project develops.
6. If you can run the hardware, add your own dated demo video and measurements. Until then, keep the hardware status marked as untested.

A short description you can edit: **"Learning how a small RV32I processor works using Verilog, compiled C programs, and a Tang Nano 20K FPGA."**

The newer CPU and verification framework were created with substantial AI assistance. See [AI_ASSISTANCE.md](../AI_ASSISTANCE.md). Only describe design and debugging as personally completed if you actually did it.
