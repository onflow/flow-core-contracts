import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import "../utils/config";
import { deployContract } from "../utils/deploy-code";
import { minterTransferDeploy } from "./custom-deploy";
import { authorization } from "../utils/crypto";
import { getTemplate } from "../utils/file";
import { mintFlow } from "../templates/utility";
import { getAccount, registerContract, getContractAddress } from "../rpc-calls";
import { executeScript } from "../utils/interaction";

const bpContract = "../../contracts";
const bpTxTemplates = "../../transactions";
const bpTemplates = "../templates";

const getContractTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpContract}/${name}.cdc`, addressMap, byName);
};

const getTxTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap, byName);
};

const NODE_AWARD_CUT = 0.3;

test("generate minter", () => {
  let code = mintFlow();
  console.log({ code });
});

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
    const code = getTxTemplate("idTableStaking/get_current_table", {
      FlowIDTableStaking: deployedAddress,
    });

    try {
      const tableIDs = await executeScript({ code });
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

    const code = getContractTemplate("FlowStakingHelper", {
      FlowIDTableStaking: IDTableStakingAddress,
    });

    try {
      const txStatus = await deployContract(stakingHelperAddress, code);
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
