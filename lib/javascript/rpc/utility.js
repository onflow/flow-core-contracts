"use strict";

function slice(array, start) {
  return Array.prototype.slice.call(array, start);
}

function isString(s) {
  return typeof s === "string" || s instanceof String;
}

function flatten(array) {
  var result = [],
    i,
    len = array && array.length;
  if (len && !isString(array)) {
    for (i = 0; i < len; i++) {
      result = result.concat(flatten(array[i]));
    }
  } else if (len !== 0) {
    result.push(array);
  }
  return result;
}

function join() {
  return flatten(slice(arguments, 0)).join(" ");
}

module.exports = {
  join,
  slice,
};
