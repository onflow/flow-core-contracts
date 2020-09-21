import * as fcl from "@onflow/fcl";
import * as sdk from "@onflow/sdk";
import { authorization } from "./crypto";

const unwrap = (arr) => {
  const type = arr[arr.length - 1];

  return arr.slice(0, -1).map((value) => {
    return sdk.arg(value, type);
  });
};
const mapArgs = (args) => {
  return args.reduce((acc, arg) => {
    const unwrapped = unwrap(arg);
    acc = [...acc, ...unwrapped];
    return acc;
  }, []);
};

export const sendTransaction = async ({ code, args, signers }) => {
  const serviceAuth = authorization();

  // set repeating transaction code
  const ix = [
    fcl.transaction(code),
    sdk.payer(serviceAuth),
    sdk.proposer(serviceAuth),
    sdk.limit(999),
  ];

  // use signers if specified
  if (signers) {
    const auths = signers.map((address) => authorization(address));
    ix.push(sdk.authorizations(auths));
  } else {
    // and only service account if no signers
    ix.push(sdk.authorizations([serviceAuth]));
  }

  // add arguments if any
  if (args) {
    ix.push(sdk.args(mapArgs(args)));
  }
  const response = await fcl.send(ix);
  return await fcl.tx(response).onceExecuted();
};

export const executeScript = async ({ code, args }) => {
  const ix = [fcl.script(code)];
  // add arguments if any
  if (args) {
    ix.push(sdk.args(mapArgs(args)));
  }
  const response = await fcl.send(ix);
  return fcl.decode(response);
};
