// Minimal FFI for PackageSetSwarm
// Only date functions - all D3/SVG operations use PSD3 library

// Parse ISO date string to timestamp (milliseconds)
// Returns PureScript Maybe: { value0: n } for Just, {} for Nothing
export const parseDateImpl = (dateStr) => {
  if (!dateStr) return {};  // Nothing
  const d = new Date(dateStr);
  const ts = d.getTime();
  return isNaN(ts) ? {} : { value0: ts };  // Just ts or Nothing
};

// Format timestamp as YYYY-MM-DD string
export const formatTimestampImpl = (ts) => {
  return new Date(ts).toISOString().slice(0, 10);
};
