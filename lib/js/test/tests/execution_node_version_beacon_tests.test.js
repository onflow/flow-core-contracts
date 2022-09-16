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

    /** TODO: Test Cases
     *  [X] - Contract deploys with proper initialization
     *  [X] - Add version to table succeeds
     *  [X] - Add version to table fails as it's within buffer period
     *  [X] - Add multiple versions to table in mixed block height order, getNextVersionBoundaryPair() returns correct boundary
     *  [X] - Delete version from table successful
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

    // Setup each test
    beforeEach(async () => {
        const logging = false;

        await init(BASE_PATH);
        return emulator.start({ logging });
    });

    // Stop the emulator after each test
    afterEach(async () => {
        return emulator.stop();
    });

    test("Deploy ExecutionNodeVersionBeacon successfully with proper initialization", async () => {
        // Contract initialization arguments
        const expectedBuffer = 1000;
        const expectedBufferVariance = 0.5;

        // Define expected versionTable response object & boundary pair
        const expectedVersionTable = {};
        const expectedVersionBoundaryPair = [];

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

        // Version & boundary values
        const expectedBlockHeightBoundary = 15;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";
        const isBackwardsCompatible = true;

        // Define expected versionTable response object & boundary pair
        const expectedVersionTable = {
            [expectedBlockHeightBoundary.toString()]: {
                "isBackwardsCompatible": isBackwardsCompatible,
                "major": expectedMajor.toString(),
                "minor": expectedMinor.toString(),
                "patch": expectedPatch.toString(),
                "preRelease": expectedPreRelease,
            }
        };
        const expectedVersionBoundaryPair = [
            expectedBlockHeightBoundary.toString(),
            expectedVersionTable[expectedBlockHeightBoundary.toString()]
        ];

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
        // getCurrentExecutionNodeVersion should return null as version is upcoming
        const actualCurrentVersion = await executeScriptByFilename(
            SCRIPT_FILENAMES["getCurrentExecutionNodeVersionFilename"]
        );
        const actualCurrentVersionAsString = await executeScriptByFilename(
            SCRIPT_FILENAMES["getCurrentExecutionNodeVersionAsStringFilename"]
        );

        // Check actual against expected
        expect(actualVersionTable).toEqual(expectedVersionTable);
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundaryPair);
        expect(actualCurrentVersion).toBeNull();
        expect(actualCurrentVersionAsString).toBeNull();
    });

    test("Add version boundary within buffer period fails", async () => {
        // Contract initialization arguments
        const expectedBuffer = 100;
        const expectedBufferVariance = 0.5;

        // Version & boundary values
        const expectedBlockHeightBoundary = 15;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";
        const isBackwardsCompatible = true;

        // Define expected versionTable response object & boundary pair
        const expectedVersionTable = {};
        const expectedVersionBoundaryPair = [];

        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        await deployContract(ExecNodeVersionBeaconAcct, [expectedBuffer, expectedBufferVariance]);

        // Attempt to add version boundary to table - should fail & revert
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenameReverts(
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

        // Check version table remains empty
        expect(actualVersionTable).toEqual(expectedVersionTable);
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundaryPair);
    });

    // Insert multiple versions in mixed order - 65: 0.1.0-alpha.2, 50: 0.1.0-alpha.1, 90: 0.1.0-alpha.3
    test("Add multiple versions to table in mixed block height order, getNextVersionBoundaryPair() returns correct boundary", async () => {

        // Contract initialization arguments
        const expectedBuffer = 10;
        const expectedBufferVariance = 0.5;

        // First in block height, will add to versionTable second
        const firstBlockHeightBoundary = 50;
        const firstMajor = 0;
        const firstMinor = 1;
        const firstPatch = 0;
        const firstPreRelease = "alpha.1";
        const firstIsBackwardsCompatible = true;

        // Second in block height, will add to versionTable first
        const secondBlockHeightBoundary = 65;
        const secondMajor = 0;
        const secondMinor = 1;
        const secondPatch = 0;
        const secondPreRelease = "alpha.2";
        const secondIsBackwardsCompatible = true;

        // Third in block height, will add to versionTable third
        const thirdBlockHeightBoundary = 90;
        const thirdMajor = 0;
        const thirdMinor = 1;
        const thirdPatch = 1;
        const thirdPreRelease = null;
        const thirdIsBackwardsCompatible = true;

        // Define expected versionTable response object & version boundary pair
        const expectedFirstSequentialVersion = {
                "isBackwardsCompatible": firstIsBackwardsCompatible,
                "major": firstMajor.toString(),
                "minor": firstMinor.toString(),
                "patch": firstPatch.toString(),
                "preRelease": firstPreRelease
        };
        const expectedSecondSequentialVersion = {
            "isBackwardsCompatible": firstIsBackwardsCompatible,
            "major": secondMajor.toString(),
            "minor": secondMinor.toString(),
            "patch": secondPatch.toString(),
            "preRelease": secondPreRelease
        };
        const expectedThirdSequentialVersion = {
            "isBackwardsCompatible": firstIsBackwardsCompatible,
            "major": thirdMajor.toString(),
            "minor": thirdMinor.toString(),
            "patch": thirdPatch.toString(),
            "preRelease": thirdPreRelease
        };
        const expectedNextVersionBoundaryPair = [
            firstBlockHeightBoundary.toString(),
            expectedFirstSequentialVersion
        ];

        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        await deployContract(ExecNodeVersionBeaconAcct, [expectedBuffer, expectedBufferVariance]);

        // Add each version boundary to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["addVersionToTableFilename"],
            [secondMajor, secondMinor, secondPatch, secondPreRelease, secondIsBackwardsCompatible, secondBlockHeightBoundary],
            [ExecNodeVersionBeaconAcct]
        );
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["addVersionToTableFilename"],
            [firstMajor, firstMinor, firstPatch, firstPreRelease, firstIsBackwardsCompatible, firstBlockHeightBoundary],
            [ExecNodeVersionBeaconAcct]
        );
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["addVersionToTableFilename"],
            [thirdMajor, thirdMinor, thirdPatch, thirdPreRelease, thirdIsBackwardsCompatible, thirdBlockHeightBoundary],
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
        expect(actualVersionTable[firstBlockHeightBoundary.toString()])
            .toEqual(expectedFirstSequentialVersion);
        expect(actualVersionTable[secondBlockHeightBoundary.toString()])
            .toEqual(expectedSecondSequentialVersion);
        expect(actualVersionTable[thirdBlockHeightBoundary.toString()])
            .toEqual(expectedThirdSequentialVersion);
        expect(actualVersionBoundaryPair)
            .toEqual(expectedNextVersionBoundaryPair);
    });

    test("/Delete version from table successful", async () => {
        // Contract initialization arguments
        const expectedBuffer = 10;
        const expectedBufferVariance = 0.5;

        // Version & boundary values
        const expectedBlockHeightBoundary = 20;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";
        const isBackwardsCompatible = true;

        // Define expected versionTable response object & boundary pair
        const expectedVersionTable = {};
        const expectedVersionBoundaryPair = [];

        // Get account and deploy contract to account
        const ExecNodeVersionBeaconAcct = await getAccountAddress("ExecutionNodeVersionBeaconAddress");
        await deployContract(ExecNodeVersionBeaconAcct, [expectedBuffer, expectedBufferVariance]);

        // Add version to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["addVersionToTableFilename"],
            [expectedMajor, expectedMinor, expectedPatch, expectedPreRelease, isBackwardsCompatible, expectedBlockHeightBoundary],
            [ExecNodeVersionBeaconAcct]
        );

        // Then delete the version
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["deleteUpcomingVersionBoundaryFilename"],
            [expectedBlockHeightBoundary],
            [ExecNodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTable = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionTableFilename"]
        );
        const actualVersionBoundaryPair = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryPairFilename"]
        );

        // Ensure that the table is empty and no boundary pair exists
        expect(actualVersionTable).toEqual(expectedVersionTable);
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundaryPair);
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
        expect(deployError).toBeNull();
    } catch (error) {
        throw error;
    };
};
