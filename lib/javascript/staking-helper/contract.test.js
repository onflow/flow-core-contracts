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

const getContractTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpContract}/${name}.cdc`, addressMap, byName);
};
const getTxTemplate = (name, addressMap, byName = true) => {
  return getTemplate(`${bpTxTemplates}/${name}.cdc`, addressMap, byName);
};

const NODE_AWARD_CUT = 0.3;

// ------------------------------------- TEST AREA -----------------------------

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

/*
describe("Staking Helper - Known Holder", ()=>{
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
})
*/
/*
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
*/

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

describe("StakingHelper - Deposit Escrow", () => {
  test("get escrow balance", async () => {
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const custodyAccount = await getAccount("custody-provider");

    const code = getTxTemplate("stakingHelper/get_escrow_balance", {
      FlowStakingHelper: stakingHelperAddress,
    });
    const args = [[custodyAccount, types.Address]];
    const balance = await executeScript({ code, args });
    console.log(`Escrow balance: ${balance}`);
  });
  test("deposit tokens", async () => {
    const custodyAccount = await getAccount("custody-provider");
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const addressMap = {
      FlowStakingHelper: stakingHelperAddress,
    };

    const escrowBalancecode = getTxTemplate(
      "stakingHelper/get_escrow_balance",
      addressMap
    );

    const depositEscrowcode = getTxTemplate(
      "stakingHelper/deposit_escrow",
      addressMap
    );

    const getEscrowBalance = async () =>
      executeScript({
        code: escrowBalancecode,
        args: [[custodyAccount, types.Address]],
      });

    const initialBalance = await getFlowBalance(custodyAccount);
    expect(initialBalance).not.toBe(undefined);

    const initialEscrowBalance = await getEscrowBalance();
    expect(initialEscrowBalance).not.toBe(undefined);

    if (initialBalance === 0) {
      const amount = 13.37;
      try {
        const txStatus = await mintFlow(custodyAccount, amount);
        console.log({ txStatus });
      } catch (error) {
        console.log("⚠ ERROR:", error);
        expect(error).toBe("");
      }
      const newBalance = await getFlowBalance(custodyAccount);
      expect(newBalance).toBe(amount);
    }

    const depositAmount = 0.01;
    try {
      const args = [[depositAmount, types.UFix64]];
      const signers = [custodyAccount];
      const code = depositEscrowcode;
      const txStatus = await sendTransaction({ code, args, signers });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    const newEscrowBalance = await getEscrowBalance();
    const escrowDifference = newEscrowBalance - initialEscrowBalance;
    console.log({ newEscrowBalance, initialEscrowBalance });
    expect(escrowDifference.toFixed(2)).toBe(depositAmount.toFixed(2));

    const newVaultBalance = await getFlowBalance(custodyAccount);
    const vaultDifference = newVaultBalance - initialBalance;
    expect(vaultDifference.toFixed(2)).toBe(vaultDifference.toFixed(2));
  });
});

describe("StakingHelper - withdrawEscrow", () => {
  test("deposit escrow", async () => {
    const custodyAccount = await getAccount("custody-provider");
    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const addressMap = {
      FlowStakingHelper: stakingHelperAddress,
    };

    const escrowBalanceCode = getTxTemplate(
      "stakingHelper/get_escrow_balance",
      addressMap
    );

    const getEscrowBalance = async () =>
      executeScript({
        code: escrowBalanceCode,
        args: [[custodyAccount, types.Address]],
      });

    const depositEscrowcode = getTxTemplate(
      "stakingHelper/deposit_escrow",
      addressMap
    );

    const depositAmount = 0.25;

    try {
      const args = [[depositAmount, types.UFix64]];
      const signers = [custodyAccount];
      const txStatus = await sendTransaction({
        code: depositEscrowcode,
        args,
        signers,
      });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    const escrowBalance = await getEscrowBalance();
    console.log({ escrowBalance });
  });
  test("withdraw escrow", async () => {
    const custodyAccount = await getAccount("custody-provider");
    const custodyAwardAccount = await getAccount("custody-provider-awards");

    const stakingHelperAddress = await getContractAddress("FlowStakingHelper");
    const addressMap = {
      FlowStakingHelper: stakingHelperAddress,
    };

    const escrowBalanceCode = getTxTemplate(
      "stakingHelper/get_escrow_balance",
      addressMap
    );

    /*
    const depositEscrowcode = getTxTemplate(
      "stakingHelper/deposit_escrow",
      addressMap
    );
    */

    const withdrawEscrowcode = getTxTemplate(
      "stakingHelper/withdraw_escrow",
      addressMap
    );

    const getEscrowBalance = async () =>
      executeScript({
        code: escrowBalanceCode,
        args: [[custodyAccount, types.Address]],
      });

    const initialAwardBalance = await getFlowBalance(custodyAwardAccount);
    const initialVaultBalance = await getEscrowBalance();

    console.log({ initialAwardBalance, initialVaultBalance });

    const withdrawAmount = 0.01;
    try {
      const args = [[withdrawAmount, types.UFix64]];
      const signers = [custodyAccount];
      const txStatus = await sendTransaction({
        code: withdrawEscrowcode,
        args,
        signers,
      });
      console.log({ txStatus });
    } catch (error) {
      console.log("⚠ ERROR:", error);
      expect(error).toBe("");
    }

    const newAwardBalance = await getFlowBalance(custodyAwardAccount);
    const difference = newAwardBalance - withdrawAmount;
    console.log({ difference, newAwardBalance, withdrawAmount });
    expect(difference.toFixed(4)).toBe(initialAwardBalance.toFixed(4));
    console.log({ initialAwardBalance, newAwardBalance });

    const newVaultBalance = await getEscrowBalance();
    const expectedBalance = initialVaultBalance - withdrawAmount;
    console.log({ initialVaultBalance, newVaultBalance, expectedBalance, withdrawAmount });
    expect(newVaultBalance.toFixed(4)).toBe(expectedBalance.toFixed(4));
  });
});
