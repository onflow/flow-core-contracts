let fetch;
if (!fetch) {
  fetch = require("node-fetch");
}

const RPC_URL = "http://localhost:9090/rpc";

const makeParams = (data) => {
  return {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  };
};

// TODO: Throw error if response is error, don't have data field or data field of specific value
const dial = async (params) => {
  const response = await fetch(RPC_URL, makeParams(params));
  const { data } = await response.json();
  return data;
};

// RPC Calls
export const purge = async (name) => {
  const rpcCall = {
    purge: {},
  };
  return dial(rpcCall);
};

export const getAccount = async (name) => {
  const rpcCall = {
    getAccount: {
      name,
    },
  };
  return dial(rpcCall);
};

export const listContracts = async () => {
  const rpcCall = {
    listContracts: {},
  };
  return dial(rpcCall);
};

export const registerContract = async (name, address) => {
  const rpcCall = {
    registerContractAddress: {
      name,
      address,
    },
  };
  return dial(rpcCall);
};

export const getContractAddress = async (name) => {
  const rpcCall = {
    getContractAddress: {
      name,
    },
  };
  return dial(rpcCall);
};
