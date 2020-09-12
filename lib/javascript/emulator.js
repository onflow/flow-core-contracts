"use strict";
const { spawn } = require("child_process");

const command = "cmd";
const args = ["/C", "flow", "emulator", "start"];
const options = {
  /* your spawn options */
};

/*
const flowProcess = spawn(command, args, options);

flowProcess.stdout.on("data", (data) => {
  if (data.includes("Starting HTTP server")) {
    console.log("EMULATOR IS UP!");
  }
});

flowProcess.stderr.on("data", (data) => {
  console.error(`stderr: ${data}`);
});

flowProcess.on("close", (code) => {
  console.log(`child process exited with code ${code}`);
});
 */

class Emulator {
  constructor() {
    this.process = spawn(command, args, options);
    this.initialized = false;
    this.init();
  }

  init() {
    return new Promise((resolve, reject) => {
      this.process.stdout.on("data", (data) => {
        console.log(`LOG: ${data}`);
        if (data.includes("Starting HTTP server")) {
          console.log("EMULATOR IS UP! Listening for events!");
          this.initialized = true;
          resolve(true);
        }
      });
    });

    /*
    this.process.stderr.on("data", (data) => {
      console.error(`stderr: ${data}`);
    });

    this.process.on("close", (code) => {
      console.log(`child process exited with code ${code}`);
    });
    
     */
  }
}

const emulator = new Emulator();

module.exports = {
  emulator
};
