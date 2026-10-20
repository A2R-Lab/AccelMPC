#!/usr/bin/env bash
# Build the double-blind `anonymous` branches for AccelMPC and its three
# component repositories, for use with https://anonymous.4open.science/.
#
#   tools/anonymize/make_anonymous_branches.sh
#
# What it does
#   1. Exports each component's HEAD (the commit pinned by this hub) into a
#      staging tree and scrubs identifying content (see tools/anonymize/README.md).
#   2. Replaces the `anonymous` branch of each component repo with an orphan
#      commit of its scrubbed tree (no history, anonymous author).
#   3. Replaces the `anonymous` branch of the hub with an orphan commit that
#      VENDORS the three scrubbed trees as plain directories. anonymous.4open.science
#      cannot expand submodules, so the hub branch must carry the files itself.
#   4. Greps the result for the forbidden-term list and fails on any hit.
#
# Nothing is pushed. Requires: git, zip/unzip, python3 with pymupdf (set PYTHON).
set -euo pipefail

HUB="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$HUB/tools/anonymize"
PYTHON="${PYTHON:-python3}"
BRANCH="${BRANCH:-anonymous}"
COMPONENTS=(ADMM_FPGA crazyflie_fpga_firmware Crazyflie_FPGA_Deck)
FORBIDDEN='\b(andrea|grillo|plancher|brian|a2r|dartmouth|epfl|lausanne|agrillo|ag-think|arxiv|nsf|toyota|burke)\b'

export GIT_AUTHOR_NAME="Anonymous Authors" GIT_AUTHOR_EMAIL="anonymous@example.com"
export GIT_COMMITTER_NAME="Anonymous Authors" GIT_COMMITTER_EMAIL="anonymous@example.com"

"$PYTHON" -c 'import pymupdf' 2>/dev/null || { echo "error: $PYTHON lacks pymupdf (pip install pymupdf), needed to redact the schematic PDF" >&2; exit 1; }

STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
log() { printf '\n== %s\n' "$*"; }

# --- 1. export + scrub each component -------------------------------------
for c in "${COMPONENTS[@]}"; do
  log "export $c @ $(git -C "$HUB/$c" rev-parse --short HEAD)"
  mkdir -p "$STAGE/$c"
  git -C "$HUB/$c" archive HEAD | tar -x -C "$STAGE/$c"      # gitlinks are skipped
  cp "$HERE/README.$c.md" "$STAGE/$c/README.md"
  sed -i -E 's/^Copyright \(c\) [0-9]{4} .*/Copyright (c) 2026 Anonymous Authors/' "$STAGE/$c/LICENSE"
done

log "scrub ADMM_FPGA"
( cd "$STAGE/ADMM_FPGA"
  # Scrub identifying paths and host references across the current tree. The
  # component layout changes over time, so don't depend on retired fixed paths.
  find . -type f ! -path './.git/*' \
    ! -iname '*.png' ! -iname '*.jpg' ! -iname '*.jpeg' ! -iname '*.gif' \
    ! -iname '*.mp4' ! -iname '*.dcp' ! -iname '*.pdf' \
    ! -iname '*.zip' ! -iname '*.gz' ! -iname '*.tar' \
    -print0 | xargs -0 -r sed -i -E \
    -e 's#/home/agrillo#\$HOME#g' \
    -e 's#/media/andrea/[0-9a-f-]+#/home/user#g' \
    -e 's#/home/andrea#/home/user#g' \
    -e 's/`a2r-main`/the build host/g' \
    -e 's/\ba2r-main-fpga\b/the build host/g' \
    -e 's/\ba2r-main-mount\b/the build host/g' \
    -e 's/Dartmouth/University/g' \
    -e 's#https://arxiv\.org/abs/2609\.09380#https://example.invalid/paper#g' \
    -e 's#https://github\.com/A2R-Lab/crazyflie_fpga_firmware#https://example.invalid/companion-firmware#g' \
    -e 's#A2R-Lab#the project#g'
  # The imported synthesis checkpoint is a zip; scrub its report when present.
  while IFS= read -r -d '' dcp; do
    dcp="$(realpath "$dcp")"
    t="$(mktemp -d)"
    if unzip -l "$dcp" | grep -q 'top_spi_rda\.json'; then
      unzip -q -o "$dcp" top_spi_rda.json -d "$t"
      sed -i -E 's#"Host": "[^"]*"#"Host": "redacted"#; s#/home/andrea#/home/user#g; s#Vivado-[0-9]+-ag-think#Vivado-0-host#g' "$t/top_spi_rda.json"
      ( cd "$t" && zip -q "$dcp" top_spi_rda.json )
    fi
    rm -rf "$t"
  done < <(find . -type f -name '*.dcp' -print0)
)

log "scrub crazyflie_fpga_firmware"
( cd "$STAGE/crazyflie_fpga_firmware"
  rm -f .gitmodules          # upstream Bitcraze tree is documented in README.md instead
)

log "scrub Crazyflie_FPGA_Deck"
( cd "$STAGE/Crazyflie_FPGA_Deck"
  sed -i 's/(company "[^"]*")/(company "")/' Deck_FPGA.kicad_sch
  sed -i 's#/home/andrea#/home/user#g' fp-lib-table sym-lib-table
  "$PYTHON" "$HERE/redact_pdf.py" Deck_FPGA.pdf "Andrea Grillo"
)

# --- 2. forbidden-term gate ------------------------------------------------
log "forbidden-term gate"
if hits="$(
  find "$STAGE" -type f \
    ! \( \
      -iname '*.png'  -o -iname '*.jpg'  -o -iname '*.jpeg' \
      -o -iname '*.gif'  -o -iname '*.bmp'  -o -iname '*.webp' \
      -o -iname '*.tif'  -o -iname '*.tiff' \
      -o -iname '*.mp4'  -o -iname '*.mov'  -o -iname '*.avi' \
      -o -iname '*.mkv'  -o -iname '*.webm' \
      -o -iname '*.pdf' \
    \) \
    -exec grep -a -i -l -E "$FORBIDDEN" {} +
)"; then
  echo "error: identifying terms remain in:" >&2; echo "$hits" >&2; exit 1
fi
pdftotext "$STAGE/Crazyflie_FPGA_Deck/Deck_FPGA.pdf" - | grep -q -i grillo && { echo "error: PDF text still contains the name" >&2; exit 1; }
echo "clean"

# --- 3. orphan branches -----------------------------------------------------
# replace_branch <repo> <content-dir> <message>
replace_branch() {
  local repo="$1" src="$2" msg="$3" wt
  wt="$(mktemp -d -u)"
  git -C "$repo" worktree prune
  git -C "$repo" worktree add -q --detach "$wt" HEAD
  ( cd "$wt"
    git branch -D "$BRANCH" >/dev/null 2>&1 || true
    git checkout -q --orphan "$BRANCH"
    git rm -r -f -q . >/dev/null
    find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -a "$src"/. .
    git add -A
    git commit -q -m "$msg"
    echo "$repo: $BRANCH = $(git rev-parse --short HEAD) ($(git ls-files | wc -l) files)"
  )
  git -C "$repo" worktree remove --force "$wt"
}

for c in "${COMPONENTS[@]}"; do
  log "branch $c"
  replace_branch "$HUB/$c" "$STAGE/$c" "Anonymized snapshot for double-blind review"
done

log "branch hub"
HUBSTAGE="$STAGE/hub"; mkdir -p "$HUBSTAGE"
cp "$HERE/README.hub.md" "$HUBSTAGE/README.md"
cp "$HUB/LICENSE" "$HUBSTAGE/LICENSE"
sed -i -E 's/^Copyright \(c\) [0-9]{4} .*/Copyright (c) 2026 Anonymous Authors/' "$HUBSTAGE/LICENSE"
for c in "${COMPONENTS[@]}"; do cp -a "$STAGE/$c" "$HUBSTAGE/$c"; done

if hits="$(
  find "$HUBSTAGE" -type f \
    ! \( \
      -iname '*.png'  -o -iname '*.jpg'  -o -iname '*.jpeg' \
      -o -iname '*.gif'  -o -iname '*.bmp'  -o -iname '*.webp' \
      -o -iname '*.tif'  -o -iname '*.tiff' \
      -o -iname '*.mp4'  -o -iname '*.mov'  -o -iname '*.avi' \
      -o -iname '*.mkv'  -o -iname '*.webm' \
      -o -iname '*.pdf' \
    \) \
    -exec grep -a -i -l -E "$FORBIDDEN" {} +
)"; then
  echo "error: identifying terms remain in hub tree:" >&2; echo "$hits" >&2; exit 1
fi
replace_branch "$HUB" "$HUBSTAGE" "Anonymized snapshot for double-blind review (components vendored)"

log "done (nothing pushed). Push with:"
for c in "${COMPONENTS[@]}"; do echo "  git -C $c push -f origin $BRANCH"; done
echo "  git push -f origin $BRANCH"
