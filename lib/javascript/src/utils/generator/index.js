import { extractImports } from "flow-js-testing/dist/utils/imports";

/**
 * Get list of missing
 * @param {string} code - template cadence code
 * @param {Object.<string, string>} addressMap - contract name as a key and address where it's deployed as value
 */
export const missingImports = (code, addressMap) => {
	const importsList = extractImports(code);
	const missing = [];

	for (const key in importsList) {
		if (!addressMap[key] && importsList.hasOwnProperty(key)) {
			missing.push(key);
		}
	}

	return missing;
};

/**
 * Get list of missing
 * @param {string} prefix - template cadence code
 * @param {Array.<string>} list - list of missing addresses
 */
export const report = (list = [], prefix = "") => {
	const errorMessage = `Missing imports for contracts:`;
	const message = prefix ? `${prefix} ${errorMessage}` : errorMessage;
	console.error(message, list);
};

/**
 * Get list of missing
 * @param {string} code - template cadence code
 * @param {Object.<string, string>} addressMap - contract name as a key and address where it's deployed as value
 * @param {string} [prefix] - prefix to add to error message
 */
export const reportMissingImports = (code, addressMap, prefix = "") => {
	const list = missingImports(code, addressMap);
	if (list.length > 0) {
		report(list, prefix);
	}
};
