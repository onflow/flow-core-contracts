"use strict";
const methods = require("./methods");
const types = require("./types");

let routes = {
  // this is the rpc endpoint
  // every operation request will come through here
  "/rpc": function (body) {
    return new Promise((resolve, reject) => {
      if (!body) {
        throw new `rpc request was expecting some data...!`();
      }
      let keys, _json;
      try {
        _json = JSON.parse(body); // might throw error
        keys = Object.keys(_json);
      } catch (e) {
        console.log("error with body");
      }

      let promiseArr = [];

      for (let key of keys) {
        if (methods[key] && typeof methods[key].exec === "function") {
          let execPromise = methods[key].exec.call(null, _json[key]);
          if (!(execPromise instanceof Promise)) {
            throw new Error(`exec on ${key} did not return a promise`);
          }
          promiseArr.push(execPromise);
        } else {
          let execPromise = Promise.resolve({
            error: "method not defined",
          });
          promiseArr.push(execPromise);
        }
      }

      Promise.all(promiseArr)
        .then((iter) => {
          console.log(iter);
          let response = {};
          // Current version support single call for
          iter.forEach((val, index) => {
            response.data = val;
          });

          resolve(response);
        })
        .catch((err) => {
          reject(err);
        });
    });
  },
};

module.exports = routes;
