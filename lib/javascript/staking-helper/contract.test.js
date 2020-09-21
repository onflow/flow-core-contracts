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

const unwrap = (arr) => {
  const type = arr[arr.length - 1];

  return arr.slice(0, -1).map((value) => {
    return sdk.arg(value, type);
  });
};

const mapArgs = (args) => {
  return args.reduce((acc, arg) => {
    const unwrapped = unwrap(arg);
    acc = [...acc, ...unwrapped];
    return acc;
  }, []);
};

const sendTransaction = async ({ code, args, signers }) => {
  const serviceAuth = authorization();

  // set repeating transaction code
  const ix = [
    fcl.transaction(code),
    sdk.payer(serviceAuth),
    sdk.proposer(serviceAuth),
    sdk.limit(999),
  ];

  // use signers if specified
  if (signers) {
    const auths = signers.map((address) => authorization(address));
    ix.push(sdk.authorizations(auths));
  } else {
    // and only service account if no signers
    ix.push(sdk.authorizations([serviceAuth]));
  }

  // add arguments if any
  if (args) {
    ix.push(sdk.args(mapArgs(args)));
  }
  const response = await fcl.send(ix);
  return await fcl.tx(response).onceExecuted();
};

const executeScript = async ({ code, args }) => {
  const ix = [fcl.script(code)];
  // add arguments if any
  if (args) {
    ix.push(sdk.args(mapArgs(args)));
  }
  const response = await fcl.send(ix);
  return fcl.decode(response);
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
    // get contract addresses
    const idTableContractAddress = await getContractAddress(
      "FlowIDTableStaking"
    );
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    // get account addresses
    const nodeAccount = await getAccount("node-operator");
    const nodeAwardReceiver = await getAccount("node-operator-awards");
    const custodyAccount = await getAccount("custody-provider");
    const custodyAwardReceiver = await getAccount("custody-provider-awards");

    // Prepare transactions arguments
    const stakingKey = "----key-----";
    const networkingKey = "----key-----";
    const networkingAddress = "1.1.1.1";

    const code = getTxTemplate("stakingHelper/create_staking_helper", {
      FlowIDTableStaking: idTableContractAddress,
      FlowStakingHelper: stakingHelperAddress,
    });

    // set
    const args = [
      [stakingKey, networkingKey, networkingAddress, types.String],
      [nodeAwardReceiver, custodyAwardReceiver, types.Address],
      [NODE_AWARD_CUT, types.UFix64],
    ];

    const signers = [nodeAccount, custodyAccount];

    try {
      const txStatus = await sendTransaction({ code, args, signers });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });

  /*
  test("create new StakingHelper with known holder", async () => {
    const idTableContractAddress = await getContractAddress(
      "FlowIDTableStaking"
    );
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");

    const code = getTxTemplate(
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

    // Prepare transactions arguments
    const stakingKey = "----key-----";
    const networkingKey = "----key-----";
    const networkingAddress = "1.1.1.1";

    const args = [
      [stakingKey, networkingKey, networkingAddress, types.String],
      [nodeAwardReceiver, custodyAwardReceiver, types.Address],
      [NODE_AWARD_CUT, types.UFix64],
    ];
    const signers = [nodeAccount, custodyAccount, holderAccount];

    try {
      const txStatus = await sendTransaction({ code, args, signers });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("create public capability on holder", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const holderAccount = await getAccount("holder");

    const code = getTxTemplate(
      "stakingHelper/create_public_capability_holder",
      {
        FlowStakingHelper: stakingHelperAddress,
      }
    );
    const signers = [holderAccount];
    try {
      const txStatus = await sendTransaction({ code, signers });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("get value from public capability on holder", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const holderAccount = await getAccount("holder");

    const code = getTxTemplate("stakingHelper/get_cut_percentage_from_holder", {
      FlowStakingHelper: stakingHelperAddress,
    });
    const args = [[holderAccount, types.Address]];

    try {
      const cutPercentage = await executeScript({
        code,
        args,
      });
      expect(cutPercentage).toBe(NODE_AWARD_CUT);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  */

  test("create public capability on custody provider account", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const custodyAccount = await getAccount("custody-provider");

    const code = getTxTemplate("stakingHelper/create_public_capability", {
      FlowStakingHelper: stakingHelperAddress,
    });
    const signers = [custodyAccount];

    try {
      const txStatus = await sendTransaction({
        code,
        signers,
      });
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

    const code = getTxTemplate("stakingHelper/get_cut_percentage", {
      FlowStakingHelper: stakingHelperAddress,
    });
    const args = [[custodyAccount, types.Address]];
    try {
      const cutPercentage = await executeScript({
        code,
        args,
      });
      expect(cutPercentage).toBe(NODE_AWARD_CUT);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
});
