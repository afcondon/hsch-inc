// FFI for Wash.Main — the only FFI in the wash package.
// Installs the API object where the film's timeline can reach it.
export const install = (api) => () => {
  window.PolyglotWash = api;
};
