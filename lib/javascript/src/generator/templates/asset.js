import { replaceImportAddresses } from "flow-js-testing/dist/utils/imports";
import { getEnvironment } from "../../utils/env";
import { reportMissingImports } from '../utils'

export const NAME = "TestAsset"
export const HASH = "HASH_HERE";
export const CODE = `
  import Ninja from 0x0
  
  pub fun main(){ 
    log("Hello, Cadence!") 
  }
`;

/**
 * Method to generate cadence code for TestAsset
 * @param {Object.<string, string>} addressMap - contract name as a key and address where it's deployed as value
 * @param {( "emulator" | "testnet" | "mainnet" )} [env] - current working environment, defines default deployed contracts
 */
export const generateTestAsset = (addressMap, env) => {
	const envMap = getEnvironment(env);
	const fullMap = {
		...envMap,
		...addressMap,
	};

	// If there are any missing imports in fullMap it will be reported via console
	const prefix = `${NAME} =>`
	reportMissingImports(CODE, fullMap, prefix)

	return replaceImportAddresses(CODE, fullMap);
};
