# Anonymous branches for double-blind review

`make_anonymous_branches.sh` rebuilds the `anonymous` branch of this hub and of the three component repositories from the commits currently pinned by the hub's submodules. Run it from anywhere; it needs `git`, `zip`/`unzip`, `pdftotext`, and a `python3` with `pymupdf` (`PYTHON=/path/to/venv/bin/python`). It never pushes.

Why a vendored hub branch: [anonymous.4open.science](https://anonymous.4open.science/) lets you pick a branch but fetches through GitHub's archive/tree API, which never includes submodule contents (anonymous_github issues #34 and #737). The hub's `anonymous` branch therefore contains the three scrubbed component trees as plain directories, and that single branch is what you submit. The component repos get their own `anonymous` branches too, in case a per-component link is ever needed.

All four branches are orphans (no history) authored as "Anonymous Authors".

## What is scrubbed

| Where | What |
| --- | --- |
| all READMEs | replaced by the `README.*.md` templates here: no authors, thesis, lab, paper link, or GitHub org URLs |
| all `LICENSE` files | copyright holder becomes "Anonymous Authors" |
| hub | `CITATION.cff`, `.gitmodules`, and `tools/` are omitted |
| `ADMM_FPGA/experiments/slurm/*.sh`, `vitis_projects/ADMM/solver_numerics_notes.md` | personal home-directory paths become `$HOME`; the build host name is removed |
| `ADMM_FPGA/vivado_project/vivado_project.xpr` | personal absolute paths become `/home/user/...` |
| `ADMM_FPGA/.../utils_1/imports/synth_1/top.dcp` | the QoR report JSON inside the checkpoint zip named the host and user; it is rewritten in place |
| `crazyflie_fpga_firmware/.gitmodules` | removed; the README documents the upstream Bitcraze commit to check out |
| `Crazyflie_FPGA_Deck/Deck_FPGA.kicad_sch` | schematic title-block company field cleared |
| `Crazyflie_FPGA_Deck/{fp,sym}-lib-table` | personal library paths become `/home/user/...` |
| `Crazyflie_FPGA_Deck/Deck_FPGA.pdf` | designer name in the title block removed by true PDF redaction |

The script ends with a binary-safe grep for the forbidden-term list and fails if anything remains. Git history is not an issue: the branches are orphans, and the service shows only a file tree.

## Submitting

On anonymous.4open.science add `https://github.com/A2R-Lab/AccelMPC`, choose branch `anonymous`, and enter the term list as a second line of defence (the service replaces matches with `XXX`, including in file names): `Andrea`, `Grillo`, `Plancher`, `Brian`, `A2R`, `A2R-Lab`, `Dartmouth`, `EPFL`, `agrillo`. Turn off auto-update unless you want the mirror to follow later force-pushes of the branch.

## Refreshing

After the component `main` branches change: update the hub's submodule pins, re-run the script, and force-push the four `anonymous` branches (the script prints the commands).
