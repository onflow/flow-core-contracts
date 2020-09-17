"use strict";
const url = require("url");
const routes = require("./routes");

function requestListener(request, response) {
  let reqUrl = `http://${request.headers.host}${request.url}`;
  let parseUrl = url.parse(reqUrl, true);
  let pathName = parseUrl.pathname;
  response.setHeader("Content-Type", "application/json");

  let buf = null;

  request.on("data", (data) => {
    if (buf === null) {
      buf = data;
    } else {
      buf = buf + data;
    }
  });

  request.on("end", () => {
    let body = buf !== null ? buf.toString() : null;
    if (routes[pathName]) {
      let compute = routes[pathName].call(null, body);

      if (!(compute instanceof Promise)) {
        response.statusCode = 500;
        response.end("oops! server error!");
        console.warn(`whatever I got from rpc wasn't a Promise!`);
      } else {
        compute
          .then((res) => {
            response.end(JSON.stringify(res));
          })
          .catch((err) => {
            console.error(err);
            response.statusCode = 500;
            response.end("oops! server error!");
          });
      }
    } else {
      response.statusCode = 404;
      response.end(`oops! ${pathName} not found here`);
    }
  });
}

module.exports = requestListener;
