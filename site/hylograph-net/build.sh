#!/usr/bin/env bash
# Build script for hylograph.net
# Converts library README.md files to HTML pages

set -e

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBS_DIR="$SITE_DIR/../../../purescript-hylograph-libs"
PUBLIC_DIR="$SITE_DIR/public"

# Check for pandoc
if ! command -v pandoc &> /dev/null; then
  echo "Warning: pandoc not found. README conversion will be skipped."
  echo "Install with: brew install pandoc (macOS) or apt install pandoc (Linux)"
  exit 0
fi

# Template for library pages
generate_lib_page() {
  local slug=$1
  local readme_html=$2

  cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>hylograph-${slug} - Hylograph</title>
  <link rel="stylesheet" href="../style.css">
  <link rel="stylesheet" href="../lib.css">
</head>
<body>
  <header class="lib-header">
    <a href="../" class="back-link">Hylograph Project Documentation</a>
  </header>

  <main class="lib-page">
    <h1>hylograph-${slug}</h1>

    <article class="readme">
${readme_html}
    </article>

    <aside class="lib-links">
      <a href="https://pursuit.purescript.org/packages/purescript-hylograph-${slug}" class="pursuit-link">API Docs (Pursuit)</a>
      <a href="https://github.com/afcondon/purescript-hylograph-${slug}" class="github-link">GitHub</a>
    </aside>
  </main>
</body>
</html>
EOF
}

echo "Building hylograph.net library pages..."

# Process each library (no associative arrays needed)
for slug in selection simulation layout graph music; do
  lib_dir="purescript-hylograph-${slug}"
  readme_path="$LIBS_DIR/$lib_dir/README.md"
  output_dir="$PUBLIC_DIR/$slug"

  if [ -f "$readme_path" ]; then
    echo "  Converting $lib_dir README..."
    mkdir -p "$output_dir"

    # Convert README to HTML fragment
    readme_html=$(pandoc --from=markdown --to=html "$readme_path")

    # Generate full page
    generate_lib_page "$slug" "$readme_html" > "$output_dir/index.html"
  else
    echo "  Warning: No README.md found at $readme_path"
  fi
done

echo "Done!"
