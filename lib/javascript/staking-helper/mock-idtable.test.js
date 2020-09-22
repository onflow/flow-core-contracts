import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import "../utils/config";
import { deployContract } from "../utils/deploy-code";
import { minterTransferDeploy } from "./custom-deploy";
import { authorization } from "../utils/crypto";
import { getTemplate } from "../utils/file";
import { mintFlow, getFlowBalance } from "../templates/";
import { getAccount, registerContract, getContractAddress } from "../rpc-calls";
import { executeScript, sendTransaction } from "../utils/interaction";

const bpContract = "../../../contracts";
const bpTxTemplates = "../../../transactions";
const bpMockContract = "../../../mocks";

const getMockContractTemplate = (name, addressmap, byName = true) => {
  return getTemplate(`${bpMockContract}/${name}.cdc`, addressmap, byName);
};

const getContractTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpContract}/${name}.cdc`, addressMap, byName);
};
const getTxTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap, byName);
};

// ------------------------------------- CONSTANTS -----------------------------

const NODE_AWARD_CUT = 0.3;

// ------------------------------------- TEST AREA -----------------------------

describe("deploy contracts", () => {
  test("deploy mock FlowIDTableStaking", async () => {
    const mockIDTableContract = getMockContractTemplate(
      "Mock_FlowIDTableStaking",
      {}
    );
    const mockOwner = await getAccount("mock-table-owner");
    try {
      const deployedAddress = await deployContract(
        mockOwner,
        mockIDTableContract
      );
      console.log(`Mock contract was deployed to ${mockOwner}`);
      await registerContract("Mock_FlowIDTableStaking", mockOwner);
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
  test("deploy StakingHelper", async () => {
    const IDTableStakingAddress = await getContractAddress(
      "Mock_FlowIDTableStaking"
    );
    const stakingHelperAddress = await getAccount("staking-helper-owner");

    const contractCode = getContractTemplate("FlowStakingHelper", {
      FlowIDTableStaking: IDTableStakingAddress,
    });

    try {
      const txStatus = await deployContract(stakingHelperAddress, contractCode);
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

describe("call methods", () => {
  test("create new StakingHelper and store capabilities", async () => {
    // get contract addresses
    const idTableContractAddress = await getContractAddress(
      "Mock_FlowIDTableStaking"
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
  test("initiate NodeStaker", async () => {
    const custodyAccount = await getAccount("custody-provider");
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const addressMap = {
      FlowStakingHelper: stakingHelperAddress,
    };

    const code = await getTxTemplate(
      "stakingHelper/send_staking_request",
      addressMap
    );

    const nodeId = "temp-node";
    const role = 5; // access node
    const args = [
      [nodeId, types.String],
      [role, types.UInt8],
    ];

    const signers = [custodyAccount];

    try {
      const txStatus = await sendTransaction({
        code,
        args,
        signers,
      });
      expect(txStatus.status).toBe(4);
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }
  });
});
