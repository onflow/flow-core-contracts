import path from "path";
import { expect } from "@jest/globals";
import {
    deployContractByName,
    emulator,
    getAccountAddress,
    init,
    sendTransaction,
    shallPass,
    shallRevert,
} from "@onflow/flow-js-testing";

// Set basepath of the project
const BASE_PATH = path.resolve(__dirname, "./../../../../");

describe("ExecutionNodeVersionBeacon Contract Tests", () => {

    // Setup each test
    beforeEach(async () => {
        const logging = false;

        await init(BASE_PATH);
        return emulator.start({ logging });
    });

    // Stop the emulator after each test
    afterEach(async () => {
        return emulator.stop();
    })

    // ! - ISSUE: getAccountAddress() Results in `Cannot read properties of undefined (reading 'replace')...`
    test("getAccountAddress breaks", async () => {
        const testAddress = await getAccountAddress("TestAddress");
    });

    test("Deploy ExecutionNodeVersionBeacon successfully with proper initialization", async () => {
        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        const i = 2;
        await deployContract(ExecNodeVersionBeaconAcct);
        expect(0).toEqual(0);
    });
});

// Deploys the ExecutionNodeVersionBeacon to the passed account
async function deployContract(account) {
    try {
        const [result, deployError] = await shallPass(
            deployContractByName({
                to: account,
                name: "ExecutionNodeVersionBeacon"
            })
        );
    } catch (error) {
        throw error;
    };
};
