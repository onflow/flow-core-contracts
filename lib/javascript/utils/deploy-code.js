import * as types from "@onflow/types";
import { sendTransaction } from "./interaction";

export const deployContract = async (toAddress, contract, customDeploy) => {
  const deployCode = Buffer.from(contract, "utf8").toString("hex");
  const code =
    customDeploy ||
    `
      transaction(code: String) {
        prepare(acct: AuthAccount) {
          acct.setCode(code.decodeHex())
        }
      }
    `;
  const args = [[deployCode, types.String]];
  const signers = [toAddress];
  return sendTransaction({ code, args, signers });
};
