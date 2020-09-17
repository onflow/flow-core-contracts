"use strict";

let types = {
  getAccount: {
    description:
      "get account with specific name. create new one if could not be found",
    props: {
      name: ["string", "required"],
    },
  },
  getContractAddress: {
    description: "get address of the deployed contract by it's name",
    props: {
      name: ["string", "required"],
    },
  },
  registerContractAddress: {
    description: "register deployed contract to specific address",
    props: {
      name: ["string", "required"],
      address: ["string", "required"],
    },
  },
  listContracts: {
    description: "get a list of registered contract addresses",
    props: {},
  },
};

module.exports = types;
