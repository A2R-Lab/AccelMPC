# AccelMPC

> High-Rate, Low-Power FPGA-Accelerated Model Predictive Control for Tiny Drones

This is the central repository for ["AccelMPC: High-Rate, Low-Power FPGA-Accelerated Model Predictive Control for Tiny Drones"](https://arxiv.org/abs/2609.09380) (Andrea Grillo and Brian Plancher, 2026). It collects the three open-source components of the system (the code, firmware, and hardware design files) as pinned submodules and documents how they fit together.

AccelMPC pairs a co-designed FPGA-accelerated ADMM solver for linear MPC with a custom 6 g expansion deck so that a 35 g Crazyflie can run constrained MPC fully onboard at 1 kHz. Hardware experiments show up to 15.6x faster solve times and a 195.4x improvement in energy-delay product over state-of-the-art microcontroller-based solvers, while scaling to problems with over 20,000 optimization variables.

## Components

| Repository | What it is | Tooling |
| --- | --- | --- |
| [`ADMM_FPGA/`](https://github.com/A2R-Lab/ADMM_FPGA) | The FPGA solver: a fixed-point ADMM solver for linear MPC written in Vitis HLS, the Vivado top-level design with the SPI/UART interface, matrix and header generation scripts, hardware-in-the-loop simulation, benchmarking sweeps, and a top-level `Makefile` driving HLS, synthesis, bitstream generation, and programming. | Vitis HLS, Vivado, Python |
| [`crazyflie_fpga_firmware/`](https://github.com/A2R-Lab/crazyflie_fpga_firmware) | The flight-controller side: an out-of-tree Crazyflie firmware app that streams the state deviation and constraint bounds to the FPGA over SPI, receives the optimal control inputs back, and applies them in the control loop. Bundles the upstream `crazyflie-firmware` tree it builds against. | Crazyflie firmware toolchain (arm-none-eabi) |
| [`Crazyflie_FPGA_Deck/`](https://github.com/A2R-Lab/Crazyflie_FPGA_Deck) | The hardware: a 4 cm x 3 cm, 4-layer, 6 g Crazyflie expansion deck carrying an AMD Artix-7 100T FPGA with its PMIC, 100 MHz oscillator, and SPI configuration flash. KiCad schematic and layout, exported PDF documentation, and fabrication Gerbers. | KiCad |

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

## Getting the Code

Clone with submodules. The firmware repository itself contains a nested submodule (the upstream Bitcraze firmware), so use the recursive form:

```bash
git clone --recurse-submodules https://github.com/A2R-Lab/AccelMPC.git
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

The submodules are pinned to the commits that match this hub. To move to the latest `main` of each component:

```bash
git submodule update --remote --recursive
```

## Building the System

Follow the README in each component. In the order you need them:

1. **Fabricate and Assemble the Deck** from the design files in [`Crazyflie_FPGA_Deck/`](Crazyflie_FPGA_Deck/). The Gerbers and drill files are in `plot/`, and `Deck_FPGA.pdf` has the schematic and layout for reference.
2. **Build and Program the FPGA Bitstream** from [`ADMM_FPGA/`](ADMM_FPGA/). The Python scripts generate the problem matrices and headers for your model and horizon, `make hls` synthesizes the solver IP, `make bit` builds the full Vivado design, and `make flash` writes it to the deck's configuration flash. An Arduino SPI sketch is included for bench-testing the deck before it goes on the drone.
3. **Build and Flash the Firmware** from [`crazyflie_fpga_firmware/`](crazyflie_fpga_firmware/), following the standard Crazyflie out-of-tree build and flash workflow.

## Paper

Andrea Grillo and Brian Plancher. "AccelMPC: High-Rate, Low-Power FPGA-Accelerated Model Predictive Control for Tiny Drones." arXiv:2609.09380, 2026. [arXiv](https://arxiv.org/abs/2609.09380) · [HTML](https://arxiv.org/html/2609.09380v1)

```bibtex
@misc{grillo2026accelmpc,
  title={AccelMPC: High-Rate, Low-Power FPGA-Accelerated Model Predictive Control for Tiny Drones},
  author={Andrea Grillo and Brian Plancher},
  year={2026},
  eprint={2609.09380},
  archivePrefix={arXiv},
  primaryClass={cs.RO},
  url={https://arxiv.org/abs/2609.09380}
}
```

The work was developed as a part of Andrea Grillo's master's thesis, *Hardware-Algorithm Co-Design for Real-Time Linear Model Predictive Control: FPGA Implementation and Deployment on a Resource-Constrained Quadrotor* (2025-2026), and then extended, at the [A2R Lab](https://a2r-lab.org) at Dartmouth College.

## Related Work

- [TinyMPC](https://tinympc.org): the cached ADMM formulation for linear MPC that the FPGA solver builds on, and the microcontroller baseline in the paper.
- [Crazyflie firmware](https://github.com/bitcraze/crazyflie-firmware): the Bitcraze flight stack the firmware component extends.
- The deck design was inspired by the board in [FPGA-Based Neural Thrust Controller for UAVs (Azem et al., 2024)](https://arxiv.org/abs/2403.18703).

## License

The hub and all three components are released under the MIT License. See [LICENSE](LICENSE) and the `LICENSE` file in each submodule.

## Funding Acknowledgement

This material is based upon work supported by the National Science Foundation (under Award [2411369](https://www.nsf.gov/awardsearch/show-award/?AWD_ID=2411369)), the Toyota Research Institute, and a Burke Research Initiation Award. Any opinions, findings, conclusions, or recommendations expressed in this material are those of the authors and do not necessarily reflect those of the funding organizations.
