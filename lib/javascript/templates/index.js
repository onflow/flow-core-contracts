import * as types from "@onflow/types";
import { getTemplate } from "../utils/file";
import { defaultsByName } from "../utils/file";
import { replaceImportAddresses } from "../utils/imports";
import { executeScript, sendTransaction } from "../utils/interaction";

const lowerFirst = (name) => {
  return name[0].toLowerCase() + name.slice(1);
};

export const makeMintTransaction = (name) => {
  const code = getTemplate(`../templates/transactions/mint_tokens.cdc`);
  const pattern = /(ExampleToken)/gi;

  return code.replace(pattern, (match) => {
    return match === "ExampleToken" ? name : lowerFirst(name);
  });
};

export const makeGetBalance = (name) => {
  const code = getTemplate(`../templates/scripts/get_balance.cdc`);
  const pattern = /(ExampleToken)/gi;

  return code.replace(pattern, (match) => {
    return match === "ExampleToken" ? name : lowerFirst(name);
  });
};

export const mintFlow = (recipient, amount) => {
  console.log({ recipient, amount });
  const raw = makeMintTransaction("FlowToken");
  const code = replaceImportAddresses(raw, defaultsByName);
  const args = [
    [recipient, types.Address],
    [amount, types.UFix64],
  ];

  return sendTransaction({ code, args });
};

export const getFlowBalance = async (address) => {
  const raw = makeGetBalance("FlowToken");
  const code = replaceImportAddresses(raw, defaultsByName);
  const args = [[address, types.Address]];
  const balance = await executeScript({ code, args });
  console.log(`Balance of ${address}: ${balance}`);

  return balance;
};
