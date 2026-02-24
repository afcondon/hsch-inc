#!/usr/bin/env python3
"""Generate an Atom feed from worklog markdown files.

Usage:
    python3 scripts/worklog-feed.py [--serve PORT]

Without --serve, writes docs/worklog/feed.xml.
With --serve, writes the feed then starts a local HTTP server so
NetNewsWire can subscribe to http://localhost:PORT/feed.xml
"""

import re
import sys
import html
from pathlib import Path
from datetime import datetime, timezone
from xml.etree.ElementTree import Element, SubElement, tostring, indent

WORKLOG_DIR = Path(__file__).resolve().parent.parent / "docs" / "worklog"
FEED_PATH = WORKLOG_DIR / "feed.xml"
FEED_TITLE = "Hylograph Worklog"
FEED_ID = "urn:hylograph:worklog"
AUTHOR_NAME = "afc"


def extract_title(text: str, date_str: str) -> str:
    """Pull the first meaningful heading or session focus line as the entry title."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        # Use "Session Focus" line if present (next non-empty line is the text)
        if re.match(r"^## Session Focus\s*$", line):
            rest = "\n".join(lines[i + 1 :]).lstrip("\n")
            first_line = rest.split("\n", 1)[0].strip()
            if first_line:
                return first_line
        # Use first H1 that isn't just the date
        m = re.match(r"^#\s+(.+)", line)
        if m:
            heading = m.group(1).strip()
            if date_str not in heading and "worklog" not in heading.lower():
                return heading
    # Fallback: first H3 (### heading) which is often the first topic
    for line in lines:
        m = re.match(r"^###\s+(.+)", line)
        if m:
            return m.group(1).strip()
    return date_str


def markdown_to_html_simple(md: str) -> str:
    """Minimal markdown -> HTML for feed content. Just enough to be readable."""
    lines = md.splitlines()
    out = []
    in_list = False
    in_code = False
    in_table = False

    for line in lines:
        # Fenced code blocks
        if line.strip().startswith("```"):
            if in_code:
                out.append("</code></pre>")
                in_code = False
            else:
                out.append("<pre><code>")
                in_code = True
            continue
        if in_code:
            out.append(html.escape(line))
            continue

        # Close list if we've left it
        if in_list and not line.strip().startswith("- ") and line.strip():
            out.append("</ul>")
            in_list = False

        # Close table
        if in_table and not line.strip().startswith("|"):
            out.append("</tbody></table>")
            in_table = False

        stripped = line.strip()

        # Headings
        m = re.match(r"^(#{1,4})\s+(.+)", stripped)
        if m:
            level = len(m.group(1))
            out.append(f"<h{level}>{html.escape(m.group(2))}</h{level}>")
            continue

        # Table rows
        if stripped.startswith("|"):
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            # Skip separator rows
            if all(re.match(r"^[-:]+$", c) for c in cells):
                continue
            if not in_table:
                out.append('<table><thead><tr>')
                for c in cells:
                    out.append(f"<th>{html.escape(c)}</th>")
                out.append("</tr></thead><tbody>")
                in_table = True
            else:
                out.append("<tr>")
                for c in cells:
                    out.append(f"<td>{html.escape(c)}</td>")
                out.append("</tr>")
            continue

        # List items
        if stripped.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            content = stripped[2:]
            # Bold
            content = re.sub(
                r"\*\*(.+?)\*\*", lambda m: f"<strong>{html.escape(m.group(1))}</strong>", content
            )
            out.append(f"<li>{content}</li>")
            continue

        # Empty line
        if not stripped:
            if in_list:
                out.append("</ul>")
                in_list = False
            continue

        # Paragraph (inline formatting)
        text = html.escape(stripped)
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
        text = re.sub(
            r"\[(.+?)\]\((.+?)\)",
            lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>',
            text,
        )
        out.append(f"<p>{text}</p>")

    if in_list:
        out.append("</ul>")
    if in_code:
        out.append("</code></pre>")
    if in_table:
        out.append("</tbody></table>")

    return "\n".join(out)


def build_feed() -> bytes:
    entries = []

    for path in sorted(WORKLOG_DIR.glob("2*.md"), reverse=True):
        date_str = path.stem  # e.g. "2026-02-13"
        try:
            date = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            continue

        text = path.read_text()
        title = extract_title(text, date_str)
        content_html = markdown_to_html_simple(text)
        entries.append((date, date_str, title, content_html))

    # Build Atom XML
    feed = Element("feed", xmlns="http://www.w3.org/2005/Atom")
    SubElement(feed, "title").text = FEED_TITLE
    SubElement(feed, "id").text = FEED_ID
    SubElement(feed, "updated").text = entries[0][0].isoformat() if entries else ""

    author = SubElement(feed, "author")
    SubElement(author, "name").text = AUTHOR_NAME

    for date, date_str, title, content_html in entries:
        entry = SubElement(feed, "entry")
        SubElement(entry, "title").text = f"{date_str}: {title}"
        SubElement(entry, "id").text = f"{FEED_ID}:{date_str}"
        SubElement(entry, "updated").text = date.isoformat()
        content_el = SubElement(entry, "content", type="html")
        content_el.text = content_html

    indent(feed)
    return b'<?xml version="1.0" encoding="utf-8"?>\n' + tostring(feed, encoding="unicode").encode("utf-8")


def main():
    xml = build_feed()
    FEED_PATH.write_bytes(xml)
    print(f"Wrote {FEED_PATH} ({len(xml)} bytes)")

    if "--serve" in sys.argv:
        import http.server
        import functools

        idx = sys.argv.index("--serve")
        port = int(sys.argv[idx + 1]) if idx + 1 < len(sys.argv) else 8384
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(WORKLOG_DIR))
        server = http.server.HTTPServer(("127.0.0.1", port), handler)
        print(f"Serving at http://localhost:{port}/feed.xml")
        print("Add this URL to NetNewsWire. Ctrl-C to stop.")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print()


if __name__ == "__main__":
    main()
