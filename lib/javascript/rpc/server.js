"use strict";
import "../utils/config";

const http = require("http");

const requestListener = require("./requestListener");
const server = http.createServer(requestListener);
const PORT = process.env.PORT || 9090;

server.listen(PORT);
console.log(`RPC is up and running on port: ${PORT}`);
