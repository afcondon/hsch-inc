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

echo "Building content pages from markdown..."

CONTENT_DIR="$SITE_DIR/content"

# Template for content pages (bookmark image per section)
generate_content_page() {
  local title=$1
  local body_html=$2
  local bookmark=$3

  cat << CONTENTEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} - Hylograph</title>
  <link rel="stylesheet" href="../style.css">
  <style>
    .page { max-width: 720px; margin: 0 auto; padding: 3rem 1.5rem; }
    .back { font-size: 0.85rem; color: #999; text-decoration: none; display: block; margin-bottom: 2rem; }
    .back:hover { color: #333; }
    .page-header { display: flex; align-items: center; gap: 1.25rem; margin-bottom: 2rem; }
    .logo-mark { height: 64px; width: auto; }
    h1 { font-size: 1.75rem; font-weight: 300; }
    h2 { font-size: 1.05rem; font-weight: 700; margin: 2.5rem 0 0.75rem; }
    p { margin-bottom: 1rem; line-height: 1.7; }
    a { color: #2563eb; }
    a:hover { text-decoration: none; }
    code { font-family: 'SF Mono', 'Fira Code', monospace; font-size: 0.88em; background: #eee; padding: 0.15em 0.35em; border-radius: 3px; }
    pre { background: #1a1a1a; color: #e8e8e8; padding: 1rem 1.25rem; border-radius: 6px; overflow-x: auto; margin-bottom: 1.5rem; font-family: 'SF Mono', monospace; font-size: 0.82rem; line-height: 1.6; }
    pre code { background: none; padding: 0; color: inherit; }
    blockquote { border-left: 3px solid #ddd; padding-left: 1rem; margin: 1rem 0 1.5rem; color: #555; font-style: italic; }
    hr { border: none; border-top: 1px solid #e0e0e0; margin: 3rem 0; }
    ul { margin-bottom: 1rem; line-height: 1.8; padding-left: 1.5rem; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 1.5rem; font-size: 0.9rem; }
    th { text-align: left; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: #999; padding: 0.5rem; border-bottom: 2px solid #e0e0e0; }
    td { padding: 0.5rem; border-bottom: 1px solid #e0e0e0; }
    .bookmark { position: fixed; left: 0; top: 0; bottom: 0; width: 64px; z-index: 10; pointer-events: none; }
    .bookmark img { width: 100%; height: 100%; object-fit: cover; }
    @media (max-width: 900px) { .bookmark { display: none; } }
  </style>
</head>
<body>
  <div class="bookmark"><img src="../images/${bookmark}" alt=""></div>
  <main class="page">
    <a href="../" class="back">&larr; Hylograph</a>
    <div class="page-header">
      <img src="../images/logo.png" alt="Hylograph" class="logo-mark">
    </div>
${body_html}
  </main>
</body>
</html>
CONTENTEOF
}

if [ -d "$CONTENT_DIR" ]; then
  for md_file in "$CONTENT_DIR"/*.md; do
    [ ! -f "$md_file" ] && continue
    basename=$(basename "$md_file" .md)
    echo "  Converting $basename.md..."

    # Determine bookmark image
    case "$basename" in
      understanding) bookmark="understanding.jpeg" ;;
      getting-started) bookmark="getting-started.jpeg" ;;
      reference) bookmark="reference.jpeg" ;;
      *) bookmark="howto.jpeg" ;;
    esac

    # Extract title from first H1
    title=$(head -1 "$md_file" | sed 's/^# //')

    # Convert to HTML
    body_html=$(pandoc --from=markdown --to=html "$md_file")

    # Write page
    mkdir -p "$PUBLIC_DIR/$basename"
    generate_content_page "$title" "$body_html" "$bookmark" > "$PUBLIC_DIR/$basename/index.html"
  done
fi

# Copy how-to site if available
HOWTO_SITE="$SITE_DIR/../../../hylograph-howto/site"
if [ -d "$HOWTO_SITE" ]; then
  echo "Copying how-to site..."
  # Copy the generated site content into public/how-to/
  cp "$HOWTO_SITE/index.html" "$PUBLIC_DIR/how-to/index.html"
  # Copy each demo's bundle and page
  for demo_dir in "$HOWTO_SITE"/*/; do
    demo_name=$(basename "$demo_dir")
    [ "$demo_name" = "images" ] && continue
    mkdir -p "$PUBLIC_DIR/how-to/$demo_name"
    cp -r "$demo_dir"* "$PUBLIC_DIR/how-to/$demo_name/" 2>/dev/null
  done
  # Copy images
  mkdir -p "$PUBLIC_DIR/how-to/images"
  cp "$HOWTO_SITE"/images/* "$PUBLIC_DIR/how-to/images/" 2>/dev/null
  echo "  Copied how-to site into public/how-to/"
else
  echo "  Warning: hylograph-howto/site not found at $HOWTO_SITE"
fi

echo "Done!"
