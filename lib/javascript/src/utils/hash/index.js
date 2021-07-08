import crypto from "crypto";

export const hashInput = (input) => {
	const algorithm = "sha256";
	const inputEncoding = "utf8";
	const encoding = "hex";
	return crypto.createHash(algorithm).update(input, inputEncoding).digest(encoding);
};
