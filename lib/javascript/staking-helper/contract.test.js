import fs from "fs";
import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import { emulator } from "../emulator";
import "../utils/config";
import { deployContract } from "../utils/deploy-code";
import { createAccount } from "../utils/create-account";
import { minterTransferDeploy } from "./custom-deploy";
import { replaceImportAddresses } from "../utils/imports";
import { authorization } from "../utils/crypto";
import { get } from "../utils/config";

const bpContract = "../../contracts";
const bpTxTemplates = "../../transactions";
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

describe("StakingHelper - Main", () => {
  /*
  test("wait for emulator to start up", async () => {
    const emulatorStatus = await emulator.init(true);
    expect(emulatorStatus).toBe(true);
  });
   */
  test("IDTable contract deployed and initialized", async () => {
    const IDTableContract = getContractTemplate(`epochs/FlowIDTableStaking`);

    const deployedAddress = await minterTransferDeploy(IDTableContract);
    const getTableScript = getTxTemplate("idTableStaking/get_current_table", {
      "0xIDENTITYTABLEADDRESS": deployedAddress,
    });
    const getTableScriptResult = await fcl.send([sdk.script(getTableScript)]);
    const tableIDs = await fcl.decode(getTableScriptResult);

    deployed["tableIDContract"] = deployedAddress;
    console.log(`IDTable contract deployed successfully to ${deployedAddress}`);
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

      deployed["StakingHelper"] = stakingHelperAddress;
      console.log(
        `StakingHelper contract deployed successfully to ${stakingHelperAddress}`
      );
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    // const expected = "done";
    // expect("done").toEqual(expected);
  });
});

describe("StakingHelper - Assistant", () => {
  test("create new assistant and store capabilities", async () => {
    const nodeAccount = await createAccount();
    const custodyAccount = await createAccount();
    // console.log({ nodeAccount, custodyAccount });

    const idTableContractAddress = "0x01cf0e2f2f715450";
    const stakingHelperAddress = "0x179b6b1cb6755e31";

    const txCode = getTxTemplate("stakingHelper/create_new_assistant", {
      "0xIDENTITYTABLEADDRESS": idTableContractAddress,
      "0xSTAKINGHELPERADDRESS": stakingHelperAddress,
    });

    // console.log({ txCode });

    const serviceAuth = authorization();
    const nodeAuth = authorization(nodeAccount);
    const custodyAuth = authorization(custodyAccount);

    const awardReceiver = custodyAccount;
    try {
      const response = await fcl.send([
        fcl.transaction(txCode),
        sdk.args([
          sdk.arg("stakingKey", types.String),
          sdk.arg("stakingSignature", types.String),
          sdk.arg("networkingKey", types.String),
          sdk.arg("networkingSignature", types.String),
          sdk.arg("networkingAddress", types.String),
          sdk.arg(awardReceiver, types.Address),
        ]),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([nodeAuth, custodyAuth]),
        sdk.limit(100)
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
});
