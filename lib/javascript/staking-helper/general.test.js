import * as types from "@onflow/types";
import "../utils/config";
import { getTemplate } from "../utils/file";
import { mintFlow, getFlowBalance } from "../templates/";
import { getAccount, getContractAddress } from "../rpc-calls";
import { executeScript, sendTransaction } from "../utils/interaction";

const bpTxTemplates = "../../../transactions";

const getTxTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap, byName);
};

const NODE_AWARD_CUT = 0.3;

describe("Staking Helper - Known Holder", () => {
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
});
describe("Generic - Mint Flow Tokens and Get Balance", () => {
  test("get balance of stake holder account", async () => {
    const stakingHelper = await getAccount("staking-helper");
    const balance = await getFlowBalance(stakingHelper);
    expect(balance).not.toBe(undefined);
  });
  test("mint flow tokens for stake holder account", async () => {
    const stakingHelper = await getAccount("staking-helper");
    const initialBalance = await getFlowBalance(stakingHelper);

    const amount = 1.01;
    try {
      const txStatus = await mintFlow(stakingHelper, amount);
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    const newBalance = await getFlowBalance(stakingHelper);
    const balanceDifference = newBalance - amount;
    expect(balanceDifference).toBe(initialBalance);
  });
});
