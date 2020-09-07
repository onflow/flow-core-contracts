import * as fcl from "@onflow/fcl";
import { authorization, pubFlowKey } from "./crypto";
import * as t from "@onflow/types";

export const sendSimpleTransaction = async (address) => {
  const auth = authorization(address);
  const response = await fcl.send([
    fcl.transaction`
      transaction() {
        prepare(acct: AuthAccount) {
          log(acct)
        }
      }
    `,
    fcl.limit(999),
    fcl.proposer(auth),
    fcl.payer(auth),
    fcl.authorizations([auth]),
  ]);

  return fcl.tx(response).onceExecuted();
};

export const sendTransaction = async (address, txCode) => {
  const auth = authorization(address);
  const txInstance = fcl.transaction(txCode);
  const response = await fcl.send([
    txInstance,
    fcl.limit(999),
    fcl.proposer(auth),
    fcl.payer(auth),
    fcl.authorizations([auth])
  ])

  return fcl.tx(response).onceExecuted();
}
