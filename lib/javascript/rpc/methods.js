"use strict";
const {
  accountByName,
  contractByName,
  storeContract,
  listContracts,
} = require("./db");

let methods = {
  getAccount: {
    description: "get account with specific name. create new one if could not be found",
    params: ["name: assigned name of the user account"],
    returns: ["address"],
    exec: async ({ name }) => {
      return accountByName(name);
    },
  },
  getContractAddress: {
    description: "get address of the deployed contract",
    params: ["name: name of the contract"],
    returns: ["address"],
    exec: async ({ name }) => {
      return contractByName(name);
    },
  },
  registerContractAddress: {
    description: "register deployed contract to specific address",
    params: [
      "name: name of the contract",
      "address: address where contract is deployed",
    ],
    returns: ["status"],
    exec: async ({ name, address }) => {
      return storeContract(name, address);
    },
  },
  listContracts: {
    description: "get list of registered addresses",
    params: [],
    returns: ["list"],
    exec: async () => {
      return listContracts();
    },
  },
};

module.exports = methods;
