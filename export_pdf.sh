#!/usr/bin/env bash
# Export notebooks to PDF without the code: only markdown, printed output and figures.
# Goes through HTML + headless Chrome (the LaTeX route drops characters like θ and ✓).
#
# Usage:
#   ./export_pdf.sh                          # every notebook in the current folder
#   ./export_pdf.sh 02_mle_cop               # every notebook in a folder
#   ./export_pdf.sh 02_mle_cop/01_*.ipynb    # specific notebooks
#
# The PDF is written next to each notebook. Only saved outputs are exported,
# so run and save the notebook first. Interactive widgets come out blank.

set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
JUPYTER="$(command -v jupyter || echo /opt/anaconda3/bin/jupyter)"

[[ -x "$CHROME" ]] || { echo "Google Chrome not found at $CHROME" >&2; exit 1; }
[[ -x "$JUPYTER" ]] || { echo "jupyter not found" >&2; exit 1; }

# collect notebooks from the arguments (files or folders; default: current folder)
notebooks=()
for arg in "${@:-.}"; do
    if [[ -d "$arg" ]]; then
        for f in "$arg"/*.ipynb; do [[ -e "$f" ]] && notebooks+=("$f"); done
    elif [[ "$arg" == *.ipynb && -f "$arg" ]]; then
        notebooks+=("$arg")
    else
        echo "skipping $arg (not a notebook or folder)" >&2
    fi
done
[[ ${#notebooks[@]} -gt 0 ]] || { echo "no notebooks found" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for nb in "${notebooks[@]}"; do
    name="$(basename "${nb%.ipynb}")"
    pdf="$(cd "$(dirname "$nb")" && pwd)/$name.pdf"
    printf '%-50s ' "$nb"
    "$JUPYTER" nbconvert --to html --no-input "$nb" --output-dir "$tmp" --log-level ERROR
    # the time budget gives MathJax (loaded from the web) time to typeset the formulas
    "$CHROME" --headless --disable-gpu --no-pdf-header-footer --virtual-time-budget=10000 \
        --print-to-pdf="$pdf" "$tmp/$name.html" >/dev/null 2>&1
    [[ -s "$pdf" ]] && echo "→ ${pdf#"$PWD"/}" || echo "FAILED"
done
