"use strict";

const Module = require("module");

function loadWithMocks(targetModule, mocks) {
  const originalLoad = Module._load;
  const resolvedTarget = require.resolve(targetModule);

  delete require.cache[resolvedTarget];

  Module._load = function patchedLoad(request, parent, isMain) {
    if (Object.prototype.hasOwnProperty.call(mocks, request)) {
      return mocks[request];
    }

    return originalLoad.call(this, request, parent, isMain);
  };

  try {
    return require(resolvedTarget);
  } finally {
    Module._load = originalLoad;
  }
}

module.exports = {
  loadWithMocks,
};
