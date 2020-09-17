"use strict";

const sys = require("sys");
const { join, slice } = require("./utility");

const DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3;
const ACTIVE_LOG_LEVEL = DEBUG;

function log(level) {
  if (level >= ACTIVE_LOG_LEVEL) sys.puts(join(slice(arguments, 1)));
}

const logLevel = {
  DEBUG,
  INFO,
  WARN,
  ERROR,
};

module.exports = {
  log,
  logLevel,
};
