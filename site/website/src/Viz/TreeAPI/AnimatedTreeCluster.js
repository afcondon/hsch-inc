// FFI for AnimatedTreeCluster.purs

export const requestAnimationFrame_ = (callback) => () => {
  return window.requestAnimationFrame(() => callback());
};

export const setAttributeNS_ = (attrName) => (value) => (element) => () => {
  element.setAttribute(attrName, value);
};

export const getTimestamp = () => {
  return performance.now();
};

export const parseNumberNullable = (str) => {
  const n = parseFloat(str);
  return isNaN(n) ? null : n;
};

export const unsafeCoerceToElement = (x) => x;
