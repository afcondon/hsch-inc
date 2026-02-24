// PSD3 React Hooks FFI

let counter = 0;

export const generateContainerIdImpl = () => {
  counter++;
  return `psd3-container-${counter}-${Date.now()}`;
};
