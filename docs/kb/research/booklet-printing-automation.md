# Booklet Printing Automation on macOS

**Status**: research
**Date**: 2026-02-02
**Tags**: macos, printing, automation, pdf

## Summary

Investigation into automating the workflow: Markdown → PDF → Booklet Print on macOS. **Conclusion: Not easily automatable.** The manual workflow (VS Code → Preview → Cmd+P → Booklet preset) is about as efficient as possible.

## The Goal

Automate the sequence:
1. Convert markdown to nicely-formatted PDF
2. Print with macOS "Layout: Booklet" setting to Brother printer

## Findings

### Markdown to PDF Conversion

| Tool | Quality | Tables | Automation |
|------|---------|--------|------------|
| VS Code Markdown PDF | Excellent | Wraps properly | Interactive only |
| pandoc + LaTeX | Good | Often overflow | CLI friendly |
| pandoc + WeasyPrint | Good | CSS-based | CLI friendly |

**VS Code's extension uses Chromium/Puppeteer** for HTML→PDF, which handles CSS tables much better than LaTeX. This is why its output looks dramatically better for documents with tables.

### macOS Booklet Printing

**Key finding: Booklet is a GUI-only feature.**

- Not exposed via CUPS/`lp` command
- Not in printer PPD options (`lpoptions -l` shows only Duplex, not Booklet)
- Handled by macOS Print Dialog's "Layout" pane

**Where settings live:**
```
~/Library/Preferences/com.apple.print.custompresets.plist
~/Library/Preferences/com.apple.print.custompresets.forprinter.<PrinterName>.plist
```

**Relevant keys:**
```
BookletBinding = 1
BookletType = 1
com.apple.print.PrintSettings.PMLayoutColumns = 2
com.apple.print.PrintSettings.PMLayoutNUp = 1
Duplex = DuplexTumble
```

### Automation Attempts

| Approach | Result |
|----------|--------|
| `lp -o BookletBinding=1` | Ignored (not a CUPS option) |
| pdfbook2 (pdfjam) | Works but requires careful margin tuning |
| AppleScript keystrokes | Requires Accessibility permissions |
| Named print presets | Can be created but not invoked from CLI |

**pdfbook2** can do page imposition for booklets, but:
- Default margins (inner=150pt) create off-center layouts
- pandoc/LaTeX tables often overflow when scaled 2-up
- Requires tuning: `--inner-margin=60 --outer-margin=30`

### What Does Work

**Creating a named "Booklet" preset** via PlistBuddy:
```bash
/usr/libexec/PlistBuddy -c "Add :Booklet dict" \
  ~/Library/Preferences/com.apple.print.custompresets.plist
```

This preset then appears in print dialogs, reducing clicks from:
- Layout dropdown → Two-Sided → Booklet

To:
- Presets dropdown → Booklet

## Recommended Workflow

The manual workflow is optimal:

1. **VS Code**: Open markdown, use Markdown PDF extension (Cmd+Shift+P → "Export PDF")
2. **Finder**: Navigate to PDF
3. **Preview**: Open PDF
4. **Print**: Cmd+P → Presets → Booklet → Print

Or with Keyboard Maestro, bind a key sequence to automate steps 3-4 after VS Code export.

## Why Not Worth Automating

- VS Code's PDF quality is significantly better than pandoc for tables
- VS Code extension is interactive (no CLI)
- macOS booklet printing requires GUI
- Total manual steps: ~10 keystrokes/clicks
- Automation would save perhaps 5 seconds per document

## Files Reference

- Print presets: `~/Library/Preferences/com.apple.print.custompresets.plist`
- VS Code extension CSS: `~/.vscode/extensions/yzane.markdown-pdf-*/styles/`
- pdfbook2: Part of texlive (`brew install texlive-basic`)

## See Also

- `man lp` - CUPS printing options
- `lpoptions -l` - List printer-specific options
- `plutil -p <file>.plist` - Read plist files
