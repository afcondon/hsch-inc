#!/usr/bin/env bash
# Build script for polyglot.purescript (polyglot.purescri.pt)
# Renders content/*.md and content/backends/*.md into public/ via pandoc.
# The landing page (public/index.html) and public/style.css are hand-authored
# and left untouched.

set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENT_DIR="$SITE_DIR/content"
PUBLIC_DIR="$SITE_DIR/public"

if ! command -v pandoc &> /dev/null; then
  echo "ERROR: pandoc not found. Install with: brew install pandoc" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Page shell. Args: title, body_html, css_prefix (e.g. ".." or "../..")
# ---------------------------------------------------------------------------
page_shell() {
  local title="$1" body="$2" prefix="$3" back_href="$4" back_label="$5"
  cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — Polyglot PureScript</title>
  <link rel="stylesheet" href="${prefix}/style.css">
</head>
<body>
  <main class="page">
    <a class="back" href="${back_href}">&larr; ${back_label}</a>
${body}
  </main>
</body>
</html>
HTML
}

# ---------------------------------------------------------------------------
# Top-level content pages: content/*.md  ->  public/<name>/index.html
# ---------------------------------------------------------------------------
echo "Building top-level content pages..."
shopt -s nullglob
for md in "$CONTENT_DIR"/*.md; do
  name="$(basename "$md" .md)"
  title="$(grep -m1 '^# ' "$md" | sed 's/^# //')"
  body="$(pandoc --from=gfm --to=html "$md")"
  mkdir -p "$PUBLIC_DIR/$name"
  page_shell "$title" "$body" ".." "/" "Polyglot PureScript" > "$PUBLIC_DIR/$name/index.html"
  echo "  $name/"
done

# ---------------------------------------------------------------------------
# Backend pages: content/backends/*.md  ->  public/backends/<slug>/index.html
# ---------------------------------------------------------------------------
echo "Building backend pages..."
for md in "$CONTENT_DIR"/backends/*.md; do
  slug="$(basename "$md" .md)"
  title="$(grep -m1 '^# ' "$md" | sed 's/^# //')"
  body="$(pandoc --from=gfm --to=html "$md")"
  mkdir -p "$PUBLIC_DIR/backends/$slug"
  page_shell "$title" "$body" "../.." "/#backends" "All backends" > "$PUBLIC_DIR/backends/$slug/index.html"
  echo "  backends/$slug/"
done

echo "Done. Open $PUBLIC_DIR/index.html"
