#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
model="$repo_root/cad/caffeinate_switch.scad"

test -s "$model"
test -s "$repo_root/cad/export.sh"
test -s "$repo_root/cad/README.md"
bash -n "$repo_root/cad/export.sh"
bash "$repo_root/cad/tests/source_geometry_test.sh"

grep -Fq 'part = "shell";' "$model"
grep -Fq 'board = [27.2, 51.4];' "$model"
grep -Fq 'rocker = [8.8, 14];' "$model"
grep -Fq 'exterior = [72, 68, 44];' "$model"
grep -Fq 'wall = 2.4;' "$model"
grep -Fq 'fit = 0.30;' "$model"
grep -Fq 'board_fit = 0.80;' "$model"
for selector in shell base steam coupon; do
  grep -Fq "part == \"$selector\"" "$model"
done
echo "PASS: CAD source interface"

if ! command -v openscad >/dev/null 2>&1; then
  echo "SKIP: OpenSCAD is not installed; CAD render validation was not run."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for part in shell base steam coupon; do
  log="$tmp/$part.log"
  if ! openscad --export-format asciistl \
    -o "$tmp/$part.stl" \
    -D "part=\"$part\"" \
    "$model" >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi
  test -s "$tmp/$part.stl"
  grep -q '^solid OpenSCAD_Model' "$tmp/$part.stl"
  if grep -Eiq 'top level object.*empty|empty.*top level object|not.*valid.*2-manifold|isn.t.*valid.*2-manifold|non-manifold' "$log"; then
    cat "$log" >&2
    exit 1
  fi
  echo "PASS: rendered $part"
done
