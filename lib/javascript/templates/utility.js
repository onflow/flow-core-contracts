import { getTemplate } from "../utils/file";
import { replaceImportAddresses } from "../utils/imports";
import { defaultsByName } from "../utils/file";

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

export const mintFlow = () => {
  const raw = makeMintTransaction("FlowToken");
  return replaceImportAddresses(raw, defaultsByName);
};
