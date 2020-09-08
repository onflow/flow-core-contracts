const fs = require("fs");
const { join, normalize } = require("path");

import "./utils/config";
import { extractImports, replaceImports } from "./utils/imports";
import { deployContract } from "./utils/deploy-code";
import { createAccount } from "./utils/create-account";

const readFile = (path) => fs.readFileSync(path, "utf8");

const makeDeploy = async (
  name,
  resolvePath,
  deployed,
  updateGlobals,
  level
) => {
  const prefix = Array(level).join("------") + ">";
  console.log(`${prefix} Deploy ${name}`);
  const { path } = resolvePath(name);
  const address = deployed(name);
  if (address) {
    console.log(`${prefix} ✅ ${name} already deployed at ${address}. Skip`);
    return address;
  }

  let rawCode = readFile(path);

  const imports = extractImports(rawCode);
  const contractNames = Object.keys(imports);

  if (contractNames.length > 0) {
    console.log(prefix, `${name} imports`, contractNames);
    for (let i = 0; i < contractNames.length; i++) {
      const name = contractNames[i];
      await makeDeploy(name, resolvePath, deployed, updateGlobals, level + 1);
      rawCode = replaceImports(rawCode, deployed);
    }
  }

  const newAddress = await createAccount();
  console.log({ rawCode });
  /*
  console.log(`New account created: ${newAddress}`);
  const deploytTx = await deployContract(newAddress, contractCode);
  //TODO: read emulator output to check if contract was deployed properly
  console.log(`Contract ${name}deployed to ${newAddress}`);
  */
  updateGlobals(name, newAddress);
  return newAddress;
};

const main = async () => {
  const codeBlocks = {};
  let allImports = {};
  let deployedContracts = {};

  const deployConfig = JSON.parse(readFile("./test/contracts/deploy.json"));
  const { contracts } = deployConfig;
  const basePath = "./test/contracts/";

  const contractPaths = contracts
    //.filter((contract) => !contract.address)
    .reduce((acc, { address, path, name }) => {
      if (address) {
        acc[name] = {
          address,
        };
      } else {
        acc[name] = {
          path: normalize(join(basePath, path)),
        };
      }
      return acc;
    }, {});

  console.log({ contractPaths });

  console.log("------------------------------------------");
  for (let i = 0; i < contracts.length; i++) {
    const { address, name } = contracts[i];
    if (address) {
      console.log(`✅ ${name} is already deployead. skip`);
      deployedContracts[name] = address;
    } else {
      await makeDeploy(
        name,
        (name) => contractPaths[name],
        (name) => deployedContracts[name],
        (name, address) => {
          deployedContracts[name] = address;
        },
        1
      );
      // console.log(JSON.stringify(deployedContracts));
    }
  }
  console.log({ deployedContracts });

  /*  console.log("------------------------------------------");
  console.log({ codeBlocks });
  console.log("------------------------------------------");
  console.log({ deployedContracts });
  console.log("------------------------------------------");
  console.log({ allImports });*/
};

main();
