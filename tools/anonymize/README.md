# Anonymous branches for double-blind review

`make_anonymous_branches.sh` rebuilds the `anonymous` branch of this hub and of the three component repositories from the currently checked-out component commits (including a pointer update not yet committed in the hub). Run it from anywhere; it needs `git`, `zip`/`unzip`, `ffmpeg`/`ffprobe`, and Python with `pymupdf` and `Pillow` (defaults to `~/venv/bin/python`; override with `PYTHON=/path/to/venv/bin/python`). It never pushes.

Why a vendored hub branch: [anonymous.4open.science](https://anonymous.4open.science/) lets you pick a branch but fetches through GitHub's archive/tree API, which never includes submodule contents (anonymous_github issues #34 and #737). The hub's `anonymous` branch therefore contains the three scrubbed component trees as plain directories, and that single branch is what you submit. The component repos get their own `anonymous` branches too, in case a per-component link is ever needed.

All four branches are orphans (no history) authored as "Anonymous Authors".

## What is scrubbed

| Where | What |
| --- | --- |
| component root READMEs | replaced by the `README.*.md` templates here: no authors, thesis, lab, paper link, or GitHub org URLs |
| component root `LICENSE` files | copyright holder becomes "Anonymous Authors" |
| hub | `CITATION.cff`, `.gitmodules`, and `tools/` are omitted |
| `ADMM_FPGA` text files | personal home-directory paths become `$HOME` or `/home/user`; references to the build host are removed across the current tree layout |
| `ADMM_FPGA/**/*.dcp` | QoR report JSON files inside checkpoint archives have host and user paths redacted when present |
| `crazyflie_fpga_firmware/.gitmodules` | removed; the README documents the upstream Bitcraze commit to check out |
| `Crazyflie_FPGA_Deck/Deck_FPGA.kicad_sch` | schematic title-block company field cleared |
| `Crazyflie_FPGA_Deck/{fp,sym}-lib-table` | personal library paths become `/home/user/...` |
| `Crazyflie_FPGA_Deck/Deck_FPGA.pdf` | designer name in the title block removed by true PDF redaction |

Before replacing any branches, `audit_tree.py` checks filenames, non-media file content,
recursively decompressed ZIP/DCP/gzip/tar members, PDF text/metadata/objects,
image metadata, video metadata, and subtitle text. It rejects known names,
affiliations, the paper identifier, and non-generic home paths. Errors in readers
also fail the run. The complete vendored hub passes the same gate.

The schematic PDF also loses its metadata. Recordings and images are preserved;
recording dates and device metadata are not treated as author identifiers.
Third-party license notices and upstream URLs remain intact.

Automated checks cannot prove anonymity of faces, logos, rasterized text, or
speech. Review new media for obvious identifying credits; the text gate alone is not
sufficient. This is a double-blind-review scrub, not forensic de-identification. Git history is not an issue: the branches are orphans, and the service shows only a file tree.

## Submitting

On anonymous.4open.science add `https://github.com/A2R-Lab/AccelMPC`, choose branch `anonymous`, and enter the term list as a second line of defence (the service replaces matches with `XXX`, including in file names): `Andrea`, `Grillo`, `Plancher`, `Brian`, `A2R`, `A2R-Lab`, `Dartmouth`, `EPFL`, `agrillo`. Turn off auto-update unless you want the mirror to follow later force-pushes of the branch.

## Refreshing

After the component `main` branches change: update the hub's submodule pins, re-run the script, and force-push the four `anonymous` branches (the script prints the commands).
