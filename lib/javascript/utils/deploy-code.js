import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import { sendTransaction } from "./interaction";

export const deployContract = async (toAddress, contract, customDeploy) => {
  const accountCode = Buffer.from(contract, "utf8").toString("hex");
  const code =
    customDeploy ||
    `
      transaction(code: String) {
        prepare(acct: AuthAccount) {
          acct.setCode(code.decodeHex())
        }
      }
    `;
  const args = [sdk.arg(accountCode, types.String)];
  return sendTransaction({ code, args });
};
