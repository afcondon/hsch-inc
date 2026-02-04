// FFI for marked.js and Prism.js

// Parse markdown to HTML using marked.js
export const parseMarkdown = (markdown) => {
  if (typeof marked === 'undefined') {
    console.warn('marked.js not loaded');
    return markdown;
  }

  // Configure marked for GFM (GitHub Flavored Markdown)
  marked.setOptions({
    gfm: true,
    breaks: false,
    pedantic: false
  });

  return marked.parse(markdown);
};

// Highlight all code blocks using Prism.js
export const highlightAll = () => {
  if (typeof Prism !== 'undefined') {
    Prism.highlightAll();
  }
};

// Highlight a specific element by selector
export const highlightElement = (selector) => () => {
  if (typeof Prism !== 'undefined') {
    const elements = document.querySelectorAll(selector + ' code');
    elements.forEach(el => Prism.highlightElement(el));
  }
};
