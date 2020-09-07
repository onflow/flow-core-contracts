import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { invariant } from "./invariant";
import { authorization, pubFlowKey } from "./crypto";
import { withPrefix } from "./address";

export const createAccount = async () => {
  const response = await fcl.send([
    fcl.transaction`
      transaction(pubKey: String) {
        prepare(acct: AuthAccount) {
          let account = AuthAccount(payer: acct)
          account.addPublicKey(pubKey.decodeHex())
        }
      }
    `,
    fcl.limit(999),
    fcl.proposer(authorization()),
    fcl.payer(authorization()),
    fcl.authorizations([authorization()]),
    fcl.args([fcl.arg(await pubFlowKey(), t.String)]),
  ]);

  const { events } = await fcl.tx(response).onceExecuted();
  const creationEvent = events.find((d) => d.type === "flow.AccountCreated");
  invariant(creationEvent, "No flow.AccountCreated event emitted", events);
  return withPrefix(creationEvent.data.address);
};
