// FFI for Utilities.purs

export const highlightAllLineNumbers = () => {
  if (typeof Prism !== 'undefined' && Prism.highlightAll) {
    Prism.highlightAll();
  }
};
