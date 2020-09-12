import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import * as types from "@onflow/types";
import { authorization } from "./crypto";

export const deployContract = async (toAddress, contract, customDeploy) => {
  const auth = authorization(toAddress);

  const code = Buffer.from(contract, "utf8").toString("hex");
  const deployCode =
    customDeploy ||
    `
      transaction(code: String) {
        prepare(acct: AuthAccount) {
          acct.setCode(code.decodeHex())
        }
      }
    `;
  return fcl.send([
    sdk.transaction(deployCode),
    sdk.args([sdk.arg(code, types.String)]),
    sdk.payer(auth),
    sdk.proposer(auth),
    sdk.authorizations([auth]),
  ]);
};
