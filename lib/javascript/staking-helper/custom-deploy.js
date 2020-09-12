import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { authorization, pubFlowKey } from "../utils/crypto";
import { invariant } from "../utils/invariant";
import { withPrefix } from "../utils/address";

const deployTxCode = `
  import FlowToken from 0x0ae53cb6e3f42a79
  
  transaction(pubKey: String, code: String) {
  
    prepare(signer: AuthAccount) {
  
      let acct = AuthAccount(payer: signer)
      acct.addPublicKey(pubKey.decodeHex())  
  
      /// Borrow a reference to the Flow Token Admin in the account storage
      let flowTokenAdmin = signer.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
          ?? panic("Could not borrow a reference to the Flow Token Admin resource")
  
      /// Create a flowTokenMinterResource
      let flowTokenMinter <- flowTokenAdmin.createNewMinter(allowedAmount: 100.0)
  
      acct.save(<-flowTokenMinter, to: /storage/flowTokenMinter)
  
      acct.setCode(code.decodeHex())
    }
  }
`;

export const minterTransferDeploy = async (contract) => {
  const pubKey = await pubFlowKey();
  const contractCode = Buffer.from(contract, "utf8").toString("hex");
  const response = await fcl.send([
    fcl.transaction(deployTxCode),
    fcl.limit(999),
    fcl.proposer(authorization()),
    fcl.payer(authorization()),
    fcl.authorizations([authorization()]),
    fcl.args([fcl.arg(pubKey, t.String), fcl.arg(contractCode, t.String)]),
  ]);

  const { events } = await fcl.tx(response).onceExecuted();
  const creationEvent = events.find((d) => d.type === "flow.AccountCreated");
  invariant(creationEvent, "No flow.AccountCreated event emitted", events);
  return withPrefix(creationEvent.data.address);
};
