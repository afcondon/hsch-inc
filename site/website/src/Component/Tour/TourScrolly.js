// Minimal FFI for TourScrolly
// Only scrollIntoView - not available in purescript-web-dom

export const scrollToStep = (stepId) => () => {
  const element = document.querySelector(`[data-step="${stepId}"]`);
  if (element) {
    element.scrollIntoView({ behavior: "smooth", block: "center" });
  }
};
