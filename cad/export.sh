#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model="$repo_root/cad/caffeinate_switch.scad"
output_dir="$repo_root/build/stl"

if ! command -v openscad >/dev/null 2>&1; then
  echo "ERROR: OpenSCAD is required to export STL files." >&2
  exit 127
fi

mkdir -p "$output_dir"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for spec in shell:shell base:base steam:steam-insert coupon:fit-coupon; do
  selector="${spec%%:*}"
  filename="${spec#*:}"
  log="$tmp/$selector.log"

  if ! openscad --export-format asciistl \
    -o "$tmp/$filename.stl" \
    -D "part=\"$selector\"" \
    "$model" >"$log" 2>&1; then
    cat "$log" >&2
    exit 1
  fi

  test -s "$tmp/$filename.stl"
  grep -q '^solid OpenSCAD_Model' "$tmp/$filename.stl"
  if grep -Eiq 'top level object.*empty|empty.*top level object|not.*valid.*2-manifold|isn.t.*valid.*2-manifold|non-manifold' "$log"; then
    cat "$log" >&2
    exit 1
  fi

  mv "$tmp/$filename.stl" "$output_dir/$filename.stl"
  echo "exported build/stl/$filename.stl"
done
