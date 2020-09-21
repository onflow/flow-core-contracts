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

const addAccounts = (data) => {
  const { accounts } = data;
  console.log(accounts.length);
  for (let i = 0; i < accounts.length; i++) {
    const account = accounts[i];
    const [name, address] = account;

    // TODO: add check here if accounts exists, if not - create a new one
    db.accounts[name] = address;
  }
  return true;
};

const listAccounts = () => {
  return Object.keys(db.accounts).reduce((acc, key) => {
    acc[key] = db.accounts[key];
    return acc;
  }, {});
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
  addAccounts,
  listAccounts,
  contractByName,
  storeContract,
  listContracts,
};
