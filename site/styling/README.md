# PSD3 Shared Styling

A unified CSS foundation for all PSD3 projects, providing consistent theming and component styles across the ecosystem.

## Usage

Link the shared CSS in your HTML, then add a local override file for project-specific styles:

```html
<link rel="stylesheet" href="psd3.css">
<link rel="stylesheet" href="local.css">
```

Or copy the file to your project's public folder:

```bash
cp tools/psd3-styling/psd3.css your-project/public/
```

## Design Tokens

All styling is built on CSS custom properties, making theming straightforward:

### Brand Colors

| Variable | Value | Usage |
|----------|-------|-------|
| `--psd3-gold` | `#b8860b` | Logo/primary accent (dark goldenrod) |
| `--psd3-gold-light` | `#daa520` | Lighter gold for highlights |
| `--psd3-pure` | `#00a8cc` | PureScript/Halogen tech (teal) |
| `--psd3-python` | `#e91e8c` | Python tech (magenta) |
| `--psd3-purple` | `#7b2ff7` | Diagram middleware layers |

### Semantic Colors

| Variable | Value | Usage |
|----------|-------|-------|
| `--psd3-bg-page` | `#f8f8f8` | Page background (off-white) |
| `--psd3-bg-card` | `#ffffff` | Card backgrounds (white) |
| `--psd3-bg-subtle` | `#f0f0f0` | Subtle backgrounds |
| `--psd3-text-primary` | `#1a1a1a` | Headings (near-black) |
| `--psd3-text-body` | `#333333` | Body text (dark gray) |
| `--psd3-text-muted` | `#666666` | Captions, labels |
| `--psd3-border` | `#e0e0e0` | Subtle borders |
| `--psd3-link` | `#2563eb` | Link color (blue) |

### Spacing Scale

```css
--space-1: 0.25rem   /* 4px */
--space-2: 0.5rem    /* 8px */
--space-3: 0.75rem   /* 12px */
--space-4: 1rem      /* 16px */
--space-6: 1.5rem    /* 24px */
--space-8: 2rem      /* 32px */
--space-12: 3rem     /* 48px */
--space-16: 4rem     /* 64px */
```

### Typography Scale

```css
--text-xs: 0.75rem   /* 12px */
--text-sm: 0.875rem  /* 14px */
--text-base: 1rem    /* 16px */
--text-lg: 1.125rem  /* 18px */
--text-xl: 1.25rem   /* 20px */
--text-2xl: 1.5rem   /* 24px */
--text-3xl: 1.875rem /* 30px */
--text-4xl: 2.25rem  /* 36px */
--text-5xl: 3rem     /* 48px */
```

## Component Classes

### Navigation (Demo Website Pattern)

```html
<header class="site-nav">
  <div class="site-nav-content">
    <div class="site-nav-left">
      <a class="site-nav-logo-link">
        <img class="site-nav-logo site-nav-logo--large" />
      </a>
    </div>
    <div class="site-nav-center">
      <div class="site-nav-quadrant">
        <a class="site-nav-quadrant-box site-nav-quadrant-box--active"></a>
        <a class="site-nav-quadrant-box site-nav-quadrant-box--inactive"></a>
      </div>
    </div>
    <div class="site-nav-right">
      <nav class="site-nav-links">
        <a class="site-nav-link">Tour</a>
      </nav>
    </div>
  </div>
</header>
```

### Cards

```html
<div class="psd3-card">
  <div class="psd3-card-header">Header</div>
  <div class="psd3-card-body">Content</div>
</div>
```

Or use the home page doc box pattern:

```html
<a class="home-doc-box">
  <div class="home-doc-box__image-container">
    <img class="home-doc-box__image" />
  </div>
  <div class="home-doc-box__content">
    <h3 class="home-doc-box-title">Title</h3>
    <p class="home-doc-box-description">Description</p>
  </div>
</a>
```

### Badges

```html
<!-- PureScript/Halogen tech (cyan) -->
<span class="psd3-badge psd3-badge-pure">Halogen</span>

<!-- Python tech (pink) -->
<span class="psd3-badge psd3-badge-python">UMAP</span>
```

### Buttons

```html
<a class="psd3-btn psd3-btn-primary">Primary Action</a>
<a class="psd3-btn psd3-btn-secondary">Secondary Action</a>
```

### SVG Diagrams

```html
<rect class="psd3-diagram-box-accent" />
<rect class="psd3-diagram-box-purple" />
<rect class="psd3-diagram-box-pink" />
<text class="psd3-diagram-label">Label</text>
<text class="psd3-diagram-sublabel">Sublabel</text>
<line class="psd3-diagram-arrow" />
```

## Utility Classes

### Layout

| Class | Effect |
|-------|--------|
| `.psd3-flex` | `display: flex` |
| `.psd3-flex-col` | `flex-direction: column` |
| `.psd3-flex-center` | Center both axes |
| `.psd3-flex-between` | `justify-content: space-between` |
| `.psd3-flex-wrap` | `flex-wrap: wrap` |
| `.psd3-gap-2/4/6/8` | Gap spacing |

### Typography

| Class | Effect |
|-------|--------|
| `.psd3-text-center` | Center text |
| `.psd3-text-muted` | Muted color |
| `.psd3-text-accent` | Accent color |
| `.psd3-text-sm/lg/xl/2xl/3xl/5xl` | Font sizes |
| `.psd3-font-bold` | Bold weight |

### Spacing

| Class | Effect |
|-------|--------|
| `.psd3-mb-2/4/6/8` | Margin bottom |
| `.psd3-p-4/6` | Padding |
| `.psd3-py-8/16` | Vertical padding |

### Effects

| Class | Effect |
|-------|--------|
| `.psd3-gradient-text` | Gradient text fill |
| `.psd3-glass` | Glassmorphism effect |
| `.psd3-border-b` | Bottom border |
| `.psd3-border-t` | Top border |

## Page Templates

### Home Page

```html
<div class="home-page">
  <header class="site-nav">...</header>
  <section class="home-hero">
    <div class="home-hero-content">
      <h1 class="home-hero-title">...</h1>
    </div>
  </section>
  <section class="home-docs">
    <h2 class="home-section-title">...</h2>
    <div class="home-docs-grid">
      <a class="home-doc-box">...</a>
    </div>
  </section>
  <footer class="site-footer">...</footer>
</div>
```

### App Layout

```html
<div class="app">
  <main class="app__main">
    <!-- Page content -->
  </main>
</div>
```

## Local Overrides

Create a `local.css` file for project-specific styles:

```css
/* local.css - Project-specific overrides */

.screenshot-placeholder {
  height: 12rem;
  background: var(--psd3-bg-primary);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--psd3-text-muted);
}

.my-custom-component {
  /* Use CSS variables for consistency */
  background: var(--psd3-bg-secondary);
  border: 1px solid var(--psd3-border);
  border-radius: var(--radius-lg);
}
```

## File Size

| Approach | Size |
|----------|------|
| psd3.css | ~19KB |
| Tailwind (purescript-tailwind-css) | ~621KB |

The shared CSS approach is ~97% smaller than the Tailwind experiment while providing all necessary styling for PSD3 projects.

## Projects Using This

- `psd3-demo-website` - Main documentation site
- `showcase apps/psd3-embedding-explorer/landing` - Hypo-Punter landing page
