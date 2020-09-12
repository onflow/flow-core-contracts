import { flowConfig } from "@onflow/fcl-config";
import { config } from "@onflow/config";

const get = (scope, path, fallback) => {
  if (typeof path === "string") return get(scope, path.split("/"), fallback);
  if (!path.length) return scope;
  try {
    const [head, ...rest] = path;
    return get(scope[head], rest, fallback);
  } catch (_error) {
    return fallback;
  }
};

const set = (key, env, conf, fallback) => {
  config().put(key, env || get(flowConfig(), conf, fallback));
};

set("PRIVATE_KEY", process.env.PK, "accounts/service/privateKey");
set(
  "SERVICE_ADDRESS",
  process.env.SERVICE_ADDRESS,
  "accounts/service/address",
  "f8d6e0586b0a20c7"
);
set(
  "accessNode.api",
  process.env.ACCESS_NODE,
  "wallet/accessNode",
  "http://localhost:8080"
);
