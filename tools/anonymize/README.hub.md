# AccelMPC

> High-Rate, Low-Power FPGA-Accelerated Model Predictive Control for Tiny Drones

Anonymized code, firmware, and hardware design files accompanying our submission. AccelMPC pairs a co-designed FPGA-accelerated ADMM solver for linear MPC with a custom 6 g expansion deck so that a 35 g Crazyflie can run constrained MPC fully onboard at 1 kHz. Hardware experiments show up to 15.6x faster solve times and a 195.4x improvement in energy-delay product over state-of-the-art microcontroller-based solvers, while scaling to problems with over 20,000 optimization variables.

The three components are included as plain directories in this repository (the public release pins them as separate repositories).

## Components

| Directory | What it is | Tooling |
| --- | --- | --- |
| [`ADMM_FPGA/`](ADMM_FPGA/) | The FPGA solver: a fixed-point ADMM solver for linear MPC written in Vitis HLS, the Vivado top-level design with the SPI/UART interface, matrix and header generation scripts, hardware-in-the-loop simulation, benchmarking sweeps, and a top-level `Makefile` driving HLS, synthesis, bitstream generation, and programming. | Vitis HLS, Vivado, Python |
| [`crazyflie_fpga_firmware/`](crazyflie_fpga_firmware/) | The flight-controller side: an out-of-tree Crazyflie firmware app that streams the state deviation and constraint bounds to the FPGA over SPI, receives the optimal control inputs back, and applies them in the control loop. Builds against the upstream Bitcraze firmware tree. | Crazyflie firmware toolchain (arm-none-eabi) |
| [`Crazyflie_FPGA_Deck/`](Crazyflie_FPGA_Deck/) | The hardware: a 4 cm x 3 cm, 4-layer, 6 g Crazyflie expansion deck carrying an AMD Artix-7 100T FPGA with its PMIC, 100 MHz oscillator, and SPI configuration flash. KiCad schematic and layout, exported PDF documentation, and fabrication Gerbers. | KiCad |

### How They Fit Together

```
          Crazyflie Brushless 2.1 (STM32F405, FreeRTOS)
          ┌──────────────────────────────────────────┐
          │  crazyflie_fpga_firmware                 │
          │   state estimate ──► state deviation,    │
          │   reference, constraint bounds           │
          └───────────────┬──────────────▲───────────┘
                          │ SPI          │ optimal control inputs
          ┌───────────────▼──────────────┴───────────┐
          │  Crazyflie_FPGA_Deck (Artix-7 100T)      │
          │   ADMM_FPGA bitstream:                   │
          │   fixed-point ADMM, banded Cholesky,     │
          │   streaming forward/backward substitution│
          └──────────────────────────────────────────┘
```

Each control cycle the firmware sends the current problem data to the deck, the FPGA runs a fixed budget of ADMM iterations on the cached MPC formulation, and the first control input is returned to the MCU. The solver ships in two FPGA mappings: `full_sparse`, which stores the expanded operators directly and has the lowest energy at short horizons, and `staged`, which keeps a compact stage-wise representation and scales to horizons in the thousands.

## Building the System

Follow the README in each component. In the order you need them:

1. **Fabricate and Assemble the Deck** from the design files in [`Crazyflie_FPGA_Deck/`](Crazyflie_FPGA_Deck/). The Gerbers and drill files are in `plot/`, and `Deck_FPGA.pdf` has the schematic and layout for reference.
2. **Build and Program the FPGA Bitstream** from [`ADMM_FPGA/`](ADMM_FPGA/). The Python scripts generate the problem matrices and headers for your model and horizon, `make hls` synthesizes the solver IP, `make bit` builds the full Vivado design, and `make flash` writes it to the deck's configuration flash. An Arduino SPI sketch is included for bench-testing the deck before it goes on the drone.
3. **Build and Flash the Firmware** from [`crazyflie_fpga_firmware/`](crazyflie_fpga_firmware/), following the standard Crazyflie out-of-tree build and flash workflow. The upstream Bitcraze firmware tree it builds against is not vendored here; the component README gives the commit to check out.

## Related Work

- [TinyMPC](https://tinympc.org): the cached ADMM formulation for linear MPC that the FPGA solver builds on, and the microcontroller baseline in the paper.
- [Crazyflie firmware](https://github.com/bitcraze/crazyflie-firmware): the Bitcraze flight stack the firmware component extends.
- The deck design was inspired by the board in *FPGA-Based Neural Thrust Controller for UAVs* (Azem et al., 2024).

## License

All components are released under the MIT License. See [LICENSE](LICENSE) and the `LICENSE` file in each component directory.
