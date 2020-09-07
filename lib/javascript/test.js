import { deployContract } from "./utils/deploy-code";

const fs = require("fs");
const { join, normalize } = require("path");

import { extractImports } from "./utils/imports";
import { createAccount } from "./utils/create-account";

const readFile = (path) => fs.readFileSync(path, "utf8");

const makeDeploy = async (contractCode) => {
  const newAddress = await createAccount();
  console.log(`New account created: ${newAddress}`);
  const deploytTx = await deployContract(newAddress, contractCode);
  //TODO: read emulator output to check if contract was deployed properly

  console.log(`Contract was succesfully deployed to ${newAddress}`);
  return newAddress;
};

const main = async () => {
  const codeBlocks = {};
  let allImports = {};
  let deployedContracts = {};

  const deployConfig = JSON.parse(readFile("./test/contracts/deploy.json"));
  const { contracts } = deployConfig;
  const basePath = "./test/contracts/";

  console.log("------------------------------------------");
  for (let i = 0; i < contracts.length; i++) {
    const { address, path, name } = contracts[i];

    if (address) {
      deployedContracts[name] = address;
    } else {
      const fullPath = normalize(join(basePath, path));
      const rawCode = readFile(fullPath);
      const imports = extractImports(rawCode);

      codeBlocks[name] = {
        name,
        imports,
        code: rawCode,
      };

      allImports = {
        ...allImports,
        ...imports,
      };
    }
  }

  console.log("------------------------------------------");
  console.log({ codeBlocks });
  console.log("------------------------------------------");
  console.log({ deployedContracts });
  console.log("------------------------------------------");
  console.log({ allImports });
};

main();
