"use strict";
import { createAccount } from "../utils/create-account";

let DB_INIT_STATE = {
  accounts: {},
  contracts: {},
};

let db = { ...DB_INIT_STATE };

const purge = () => {
  console.log("Return database to clean state");
  db = { accounts: {}, contracts: {} };
  console.log(db);
  return true;
};

const accountByName = async (name) => {
  let address = db.accounts[name];
  if (address) {
    return address;
  } else {
    const newAddress = await createAccount();
    console.log(`create new account for ${name} - ${newAddress}`);
    db.accounts[name] = newAddress;
    return newAddress;
  }
};

const contractByName = (name) => {
  let address = db.contracts[name];
  return address || null;
};

const storeContract = (name, address) => {
  db.contracts[name] = address;
  return true;
};

const listContracts = () => {
  return Object.keys(db.contracts).reduce((acc, key) => {
    acc[key] = db.contracts[key];
    return acc;
  }, {});
};

module.exports = {
  purge,
  accountByName,
  contractByName,
  storeContract,
  listContracts,
};
