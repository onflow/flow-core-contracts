"use strict";
import { createAccount } from "../utils/create-account";

let db = {
  accounts: {},
  contracts: {},
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
  return address || nil;
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
  accountByName,
  contractByName,
  storeContract,
  listContracts,
};
