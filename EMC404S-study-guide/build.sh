#!/usr/bin/env bash
# Builds the combined study guide (Word and PDF) from the chapter Markdown files.
# Usage: ./build.sh [output-dir]   (requires pandoc; PDF also requires LibreOffice)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="${1:-$here}"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
name="EMC404S_Behavioural_Emergencies_and_Toxicology_Study_Guide"

cat > "$work/pagebreak.lua" <<'EOF'
function RawBlock(el)
  if el.format:match('tex') and el.text:match('\\newpage') then
    return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
  end
end
EOF

cd "$here"
chapters=(0[0-9]-*.md 1[0-9]-*.md)

# Static contents list (a Word TOC field stays blank until updated, and LibreOffice does not update it).
{
  printf '# Contents\n\n'
  for f in "${chapters[@]}"; do
    grep -hE '^(# |## [0-9]+\.[0-9])' "$f" | sed -E 's/^# (.*)/- **\1**/; s/^## (.*)/    - \1/'
  done
  printf '\n\\newpage\n\n'
} > "$work/contents.md"

# YAML title block first, then contents, then all chapters separated by blank lines.
{
  awk 'NR==1 && /^---$/ {y=1} y {print} y && NR>1 && /^---$/ {exit}' "${chapters[0]}"
  printf '\n'
  cat "$work/contents.md"
  awk 'NR==1 && /^---$/ {y=1; next} y && /^---$/ {y=0; next} !y' "${chapters[0]}"
  printf '\n\n'
  for f in "${chapters[@]:1}"; do cat "$f"; printf '\n\n'; done
} > "$work/combined.md"

pandoc "$work/combined.md" -f markdown -t docx --lua-filter="$work/pagebreak.lua" -o "$out/$name.docx"

if command -v soffice >/dev/null 2>&1; then
  soffice --headless --convert-to pdf --outdir "$out" "$out/$name.docx" >/dev/null 2>&1
fi
echo "Built: $out/$name.docx"
