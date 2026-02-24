// FFI for TourMotionScrollyHATS

// Scroll to a specific step marker in the scroll panel
export const scrollToStep = (stepId) => () => {
  const marker = document.querySelector(`[data-step="${stepId}"]`);
  if (marker) {
    marker.scrollIntoView({ behavior: 'instant', block: 'center' });
  }
};
