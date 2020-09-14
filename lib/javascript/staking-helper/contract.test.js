import fs from "fs";
import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import { emulator } from "../emulator";

const bpContract = "../../contracts";
const bpTxTemplates = "../../transactions";

import "../utils/config";
import { deployContract } from "../utils/deploy-code";
import { createAccount } from "../utils/create-account";
import { minterTransferDeploy } from "./custom-deploy";
import { replaceImportAddresses } from "../utils/imports";

const readFile = (path) => fs.readFileSync(path, "utf8");

const getTemplate = (path, addressMap) => {
  const rawCode = readFile(path);
  return addressMap
    ? replaceImportAddresses(rawCode, {
        "0x0ae53cb6e3f42a79": "0x0ae53cb6e3f42a79", // Emulator Default: FlowToken
        "0xee82856bf20e2aa6": "0xee82856bf20e2aa6", // Emulator Default: FungibleToken
        ...addressMap,
      })
    : rawCode;
};

const getContractTemplate = (name, addressMap) => {
  return getTemplate(`${bpContract}/${name}.cdc`, addressMap);
};

const getTxTemplate = (name, addressMap) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap);
};

let deployed = {
  tableIDContract: null,
};

describe("StakingHelper Test Suit", () => {
  test("wait for emulator to start up", async () => {
    const emulatorStatus = await emulator.init();
    expect(emulatorStatus).toBe(true);
  });
  test("IDTable contract deployed and initialized", async () => {
    const IDTableContract = getContractTemplate(`epochs/FlowIDTableStaking`);

    const deployedAddress = await minterTransferDeploy(IDTableContract);
    const getTableScript = getTxTemplate("idTableStaking/get_current_table", {
      "0xIDENTITYTABLEADDRESS": deployedAddress,
    });
    const getTableScriptResult = await fcl.send([sdk.script(getTableScript)]);
    const tableIDs = await fcl.decode(getTableScriptResult);

    deployed["tableIDContract"] = deployedAddress;
    console.log("IDTable contract deployed successfully");

    // TableID should be initially empty
    expect(tableIDs.length).toBe(0);
  });

  test("StakingHelper contract deployed and initialized", async () => {
    const stakingHelperAddress = await createAccount();
    const stakingContractCode = getContractTemplate("FlowStakingHelperFixed", {
      "0xIDENTITYTABLEADDRESS": deployed["tableIDContract"],
    });
    try {
      const deployTxResponse = await deployContract(
        stakingHelperAddress,
        stakingContractCode
      );
      const txStatus = await fcl.tx(deployTxResponse).onceExecuted();
      expect(txStatus.status).toBe(4);
      expect(txStatus.errorMessage).toBe("");
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    console.log("StakingHelper contract deployed successfully");
    // const expected = "done";
    // expect("done").toEqual(expected);
  });
});

describe("Staking Scaffold Deployment", () => {
  test("contract deployed and initialized", async () => {
    const stakingHelperAddress = await createAccount();
    const stakingContractCode = readFile(
      "../../contracts/FlowStakingScaffold.cdc"
    );

    const deployTx = await deployContract(
      stakingHelperAddress,
      stakingContractCode
    );

    const response = await fcl.send([
      sdk.script`
        import StakingHelper from ${stakingHelperAddress}
        pub fun main():String {
          return StakingHelper.message
        }
      `,
    ]);

    const result = await fcl.decode(response);
    console.log({ result });

    const expected = "Javascript works like a charm...";
    expect(result).toEqual(expected);
  });
});
describe("Staking Helper Deployment", () => {});
