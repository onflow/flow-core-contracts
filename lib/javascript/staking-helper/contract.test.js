import fs from "fs";
import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import "../utils/config";
import { deployContract } from "../utils/deploy-code";
import { minterTransferDeploy } from "./custom-deploy";
import { replaceImportAddresses } from "../utils/imports";
import { authorization } from "../utils/crypto";

import { getAccount, registerContract, getContractAddress } from "../rpc-calls";

const bpContract = "../../contracts";
const bpTxTemplates = "../../transactions";
const readFile = (path) => fs.readFileSync(path, "utf8");

const getTemplate = (path, addressMap, byName) => {
  const rawCode = readFile(path);
  const defaults = byName
    ? {
        FlowToken: "0x0ae53cb6e3f42a79", // Emulator Default: FlowToken
        FungibleToken: "0xee82856bf20e2aa6", // Emulator Default: FungibleToken
      }
    : {
        "0x0ae53cb6e3f42a79": "0x0ae53cb6e3f42a79", // Emulator Default: FlowToken
        "0xee82856bf20e2aa6": "0xee82856bf20e2aa6", // Emulator Default: FungibleToken
      };

  return addressMap
    ? replaceImportAddresses(rawCode, {
        ...defaults,
        ...addressMap,
      })
    : rawCode;
};

const getContractTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpContract}/${name}.cdc`, addressMap, byName);
};

const getTxTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap, byName);
};

const NODE_AWARD_CUT = 0.3;

describe("Deploy", () => {
  test("FlowIDTableStaking contract deployed", async () => {
    const IDTableContract = getContractTemplate(`epochs/FlowIDTableStaking`);
    let deployedAddress;
    try {
      deployedAddress = await minterTransferDeploy(IDTableContract);
      await registerContract("FlowIDTableStaking", deployedAddress);
      console.log(
        `IDTable contract deployed successfully to ${deployedAddress}`
      );
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });

  test("FlowIDTableStaking contract initialized properly", async () => {
    const deployedAddress = await getContractAddress("FlowIDTableStaking");
    const getTableScript = getTxTemplate("idTableStaking/get_current_table", {
      FlowIDTableStaking: deployedAddress,
    });
    try {
      const getTableScriptResult = await fcl.send([sdk.script(getTableScript)]);
      const tableIDs = await fcl.decode(getTableScriptResult);
      // TableID should be initially empty
      expect(tableIDs.length).toBe(0);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });

  test("FlowStakingHelper contract deployed", async () => {
    const IDTableStakingAddress = await getContractAddress(
      "FlowIDTableStaking"
    );
    const stakingHelperAddress = await getAccount("staking-helper-owner");

    const stakingContractCode = getContractTemplate("FlowStakingHelper", {
      FlowIDTableStaking: IDTableStakingAddress,
    });

    try {
      const deployTxResponse = await deployContract(
        stakingHelperAddress,
        stakingContractCode
      );
      const txStatus = await fcl.tx(deployTxResponse).onceExecuted();
      expect(txStatus.status).toBe(4);
      expect(txStatus.errorMessage).toBe("");

      await registerContract("FlowStakingHelper", stakingHelperAddress);
      console.log(
        `StakingHelper contract deployed successfully to ${stakingHelperAddress}`
      );
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
});

describe("StakingHelper", () => {
  test("create new StakingHelper and store capabilities", async () => {
    const idTableContractAddress = await getContractAddress(
      "FlowIDTableStaking"
    );
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const txCode = getTxTemplate("stakingHelper/create_staking_helper", {
      FlowIDTableStaking: idTableContractAddress,
      FlowStakingHelper: stakingHelperAddress,
    });

    const nodeAccount = await getAccount("node-operator");
    const nodeAwardReceiver = await getAccount("node-operator-awards");
    const custodyAccount = await getAccount("custody-provider");
    const custodyAwardReceiver = await getAccount("custody-provider-awards");

    const serviceAuth = authorization();
    const nodeAuth = authorization(nodeAccount);
    const stakerAuth = authorization(custodyAccount);

    // Prepare transactions arguments
    const stakingKey = "----key-----";
    const networkingKey = "----key-----";
    const networkingAddress = "1.1.1.1";

    try {
      const response = await fcl.send([
        fcl.transaction(txCode),
        sdk.args([
          sdk.arg(stakingKey, types.String),
          sdk.arg(networkingKey, types.String),
          sdk.arg(networkingAddress, types.String),
          sdk.arg(nodeAwardReceiver, types.Address),
          sdk.arg(custodyAwardReceiver, types.Address),
          sdk.arg(NODE_AWARD_CUT, types.UFix64),
        ]),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([nodeAuth, stakerAuth]),
        sdk.limit(999),
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });

  test("create new StakingHelper with known holder", async () => {
    const idTableContractAddress = await getContractAddress(
      "FlowIDTableStaking"
    );
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const txCode = getTxTemplate(
      "stakingHelper/create_staking_helper_with_holder",
      {
        FlowIDTableStaking: idTableContractAddress,
        FlowStakingHelper: stakingHelperAddress,
      }
    );

    const nodeAccount = await getAccount("node-operator");
    const nodeAwardReceiver = await getAccount("node-operator-awards");
    const custodyAccount = await getAccount("custody-provider");
    const custodyAwardReceiver = await getAccount("custody-provider-awards");
    const holderAccount = await getAccount("holder");

    const serviceAuth = authorization();
    const nodeAuth = authorization(nodeAccount);
    const stakerAuth = authorization(custodyAccount);
    const holderAuth = authorization(holderAccount);

    // Prepare transactions arguments
    const stakingKey = "----key-----";
    const networkingKey = "----key-----";
    const networkingAddress = "1.1.1.1";

    try {
      const response = await fcl.send([
        fcl.transaction(txCode),
        sdk.args([
          sdk.arg(stakingKey, types.String),
          sdk.arg(networkingKey, types.String),
          sdk.arg(networkingAddress, types.String),
          sdk.arg(nodeAwardReceiver, types.Address),
          sdk.arg(custodyAwardReceiver, types.Address),
          sdk.arg(NODE_AWARD_CUT, types.UFix64),
        ]),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([nodeAuth, stakerAuth, holderAuth]),
        sdk.limit(999),
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("create public capability on holder", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const serviceAuth = authorization();
    const holderAccount = await getAccount("holder");
    const holderAuth = authorization(holderAccount);

    const txCode = getTxTemplate(
      "stakingHelper/create_public_capability_holder",
      {
        FlowStakingHelper: stakingHelperAddress,
      }
    );
    try {
      const response = await fcl.send([
        fcl.transaction(txCode),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([holderAuth]),
        sdk.limit(999),
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("get value from public capability on holder", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const holderAccount = await getAccount("holder");

    const scriptCode = getTxTemplate(
      "stakingHelper/get_cut_percentage_from_holder",
      {
        FlowStakingHelper: stakingHelperAddress,
      }
    );

    try {
      const response = await fcl.send([
        sdk.script(scriptCode),
        sdk.args([sdk.arg(holderAccount, types.Address)]),
      ]);

      console.log({ response });
      const cutPercentage = await fcl.decode(response);
      expect(cutPercentage).toBe(NODE_AWARD_CUT);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });

  test("create public capability on custody provider account", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const serviceAuth = authorization();
    const custodyAccount = await getAccount("custody-provider");
    const custodyAuth = authorization(custodyAccount);

    const txCode = getTxTemplate("stakingHelper/create_public_capability", {
      FlowStakingHelper: stakingHelperAddress,
    });

    console.log({ txCode });

    try {
      const response = await fcl.send([
        sdk.transaction(txCode),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([custodyAuth]),
        fcl.limit(999),
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("check cut percentage with transaction", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const serviceAuth = authorization();
    const custodyAccount = await getAccount("custody-provider");
    const custodyAuth = authorization(custodyAccount);

    const txCode = getTxTemplate("stakingHelper/check_node_capability", {
      FlowStakingHelper: stakingHelperAddress,
    });

    try {
      const response = await fcl.send([
        sdk.transaction(txCode),
        sdk.payer(serviceAuth),
        sdk.proposer(serviceAuth),
        sdk.authorizations([custodyAuth]),
        fcl.limit(999),
      ]);
      const txStatus = await fcl.tx(response).onceExecuted();
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("access public capability and read one of StakingHelper params", async () => {
    const stakingHelperAddress = await getAccount("staking-helper-owner");
    const custodyAccount = await getAccount("custody-provider");

    const getCutPercentageScript = getTxTemplate(
      "stakingHelper/get_cut_percentage",
      {
        FlowStakingHelper: stakingHelperAddress,
      }
    );
    try {
      const response = await fcl.send([
        sdk.script(getCutPercentageScript),
        sdk.args([sdk.arg(custodyAccount, types.Address)]),
      ]);
      console.log({ response });
      const cutPercentage = await fcl.decode(response);
      expect(cutPercentage).toBe(NODE_AWARD_CUT);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
});
