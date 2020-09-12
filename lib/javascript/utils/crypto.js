import { ec as EC } from "elliptic";
import { SHA3 } from "sha3";
import * as fcl from "@onflow/fcl";
import * as rlp from "rlp";
import { config } from "@onflow/config";
import { sansPrefix } from "./address";
import { invariant } from "./invariant";
const ec = new EC("p256");

const hashMsgHex = (msgHex) => {
  const sha = new SHA3(256);
  sha.update(Buffer.from(msgHex, "hex"));
  return sha.digest();
};

export const signWithKey = (privateKey, msgHex) => {
  const key = ec.keyFromPrivate(Buffer.from(privateKey, "hex"));
  const sig = key.sign(hashMsgHex(msgHex));
  const n = 32; // half of signature length?
  const r = sig.r.toArrayLike(Buffer, "be", n);
  const s = sig.s.toArrayLike(Buffer, "be", n);
  return Buffer.concat([r, s]).toString("hex");
};

const getSeqNum = async (addr, keyId = 0) => {
  const response = await fcl.send([fcl.getAccount(addr.replace(/^0x/, ""))]);
  const account = await fcl.decode(response);
  return account.keys[keyId].sequenceNumber;
};

export const authorization = (addr, keyId = 0) => async (account = {}) => {
  addr = sansPrefix(addr || (await config().get("SERVICE_ADDRESS")));
  invariant(addr, "Authorization Function does not know which address to use", {
    addr,
    keyId,
    account,
  });
  let sequenceNum;
  if (account.role.proposer) {
    sequenceNum = await getSeqNum(addr, keyId);
    invariant(
      sequenceNum != null,
      "Could not figure out sequence number for authorization with role proposer",
      { addr, keyId, account }
    );
  }

  const signingFunction = async (data) => ({
    addr,
    keyId,
    signature: signWithKey(await config().get("PRIVATE_KEY"), data.message),
  });

  return {
    ...account,
    addr,
    keyId,
    signingFunction,
    sequenceNum,
  };
};

export const pubFlowKey = async () => {
  const keys = ec.keyFromPrivate(
    Buffer.from(await config().get("PRIVATE_KEY"), "hex")
  );
  const publicKey = keys.getPublic("hex").replace(/^04/, "");
  return rlp
    .encode([
      Buffer.from(publicKey, "hex"), // publicKey hex to binary
      2, // P256 per https://github.com/onflow/flow/blob/master/docs/accounts-and-keys.md#supported-signature--hash-algorithms
      3, // SHA3-256 per https://github.com/onflow/flow/blob/master/docs/accounts-and-keys.md#supported-signature--hash-algorithms
      1000, // give key full weight
    ])
    .toString("hex");
};
