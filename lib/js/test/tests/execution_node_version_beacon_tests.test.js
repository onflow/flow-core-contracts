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
import { executeScriptByFilename, SCRIPT_FILENAMES } from "../templates/script_templates";
import {
    sendTransactionByFilenamePasses,
    sendTransactionByFilenameReverts,
    TRANSACTION_FILENAMES
} from "../templates/transaction_templates";

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
        expect(actualVersionTable).toEqual(expectedVersionTable);
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundaryPair);
    });

    test("Add version boundary to table succeeds", async () => {
        // Contract initialization arguments
        const expectedBuffer = 10;
        const expectedBufferVariance = 0.5;
        const expectedBlockHeightBoundary = 15;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha-";
        const isBackwardsCompatible = true;

        // Define expected versionTable response object
        const expectedVersionTable = {
            [expectedBlockHeightBoundary.toString()]: {
                "isBackwardsCompatible": isBackwardsCompatible,
                "major": expectedMajor.toString(),
                "minor": expectedMinor.toString(),
                "patch": expectedPatch.toString(),
                "preRelease": expectedPreRelease,
            }
        }

        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        await deployContract(ExecNodeVersionBeaconAcct, [expectedBuffer, expectedBufferVariance]);

        // Add version boundary to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["addVersionToTableFilename"],
            [expectedMajor, expectedMinor, expectedPatch, expectedPreRelease, isBackwardsCompatible, expectedBlockHeightBoundary],
            [ExecNodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTable = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionTableFilename"]
        );
        const actualVersionBoundaryPair = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryPairFilename"]
        );

        // Check actual against expected
        expect(actualVersionTable).toEqual(expectedVersionTable);
        expect(actualVersionBoundaryPair)
            .toEqual([
                expectedBlockHeightBoundary.toString(),
                expectedVersionTable[expectedBlockHeightBoundary.toString()]
            ]);
    });

    /** TODO: Test Cases
     *  [ ] - Add version to table fails as it's within buffer period
     *  [ ] - Add version to table fails as it's not sequential
     *  [ ] - Delete version from table successful
     *  [ ] - Delete version from table fails as it's too close to boundary
     *  [ ] - Delete version from table fails as it doesn't exist
     *  [ ] - Change buffer within variance succeeds
     *  [ ] - Change buffer outside of variance fails
     *  [ ] - Change buffer too close to current block fails
     *  [ ] - Change variance succeeds
     *  [ ] - Add multiple versions succeeds
     *          - Check is compatible version is correct
     *          - Check getNextVersionBoundaryPair is correct
     * */
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
        expect(deployError).toBeNull();
    } catch (error) {
        throw error;
    };
};
