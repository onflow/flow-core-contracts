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
import {
    executeGetVersionUpdateBufferScript,
    executeGetVersionUpdateBufferVarianceScript, executeScriptByFilename, SCRIPT_FILENAMES
} from "../templates/script_templates";

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

    test("Deploy ExecutionNodeVersionBeacon successfully with proper initialization", async () => {
        // Contract initialization arguments
        const expectedBuffer = 1000;
        const expectedBufferVariance = 0.5;
        const expectedVersionTable = {}
        const expectedVersionBoundaryPair = []

        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        await deployContract(ExecNodeVersionBeaconAcct, [expectedBuffer, expectedBufferVariance]);

        // Check contract initialized values matching expectectations
        const actualBuffer = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionUpdateBufferFilename"]
        );
        const actualBufferVariance = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionUpdateBufferVarianceFilename"]
        );
        const actualVersionTable = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionTableFilename"]
        );
        const actualVersionBoundaryPair = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryPairFilename"]
        );

        // Check actual against expected
        expect(parseInt(actualBuffer)).toEqual(expectedBuffer);
        expect(parseFloat(actualBufferVariance)).toEqual(expectedBufferVariance);
        expect(actualVersionTable).toEqual(expectedVersionTable)
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundaryPair)
    });
});

// Deploys the ExecutionNodeVersionBeacon to the passed account
async function deployContract(to, args) {
    try {
        const [result, deployError] = await shallPass(
            deployContractByName({
                to: to,
                name: "ExecutionNodeVersionBeacon",
                args: args
            })
        );
    } catch (error) {
        throw error;
    };
};
