import path from "path";
import {expect} from "@jest/globals";
import {
    deployContractByName,
    emulator,
    getAccountAddress,
    init,
    sendTransaction,
    shallPass
} from "@onflow/flow-js-testing";

import {executeScriptByFilename, SCRIPT_FILENAMES} from "../templates/script_templates";
import {
    sendTransactionByFilenamePasses,
    sendTransactionByFilenameReverts,
    TRANSACTION_FILENAMES
} from "../templates/transaction_templates";

// Set basepath of the project
const BASE_PATH = path.resolve(__dirname, "./../../../../");

const ZERO_BOUNDARY = {
    "blockHeight": "0",
    "version": {
        "major": "0",
        "minor": "0",
        "patch": "0",
        "preRelease": null,
    },
};

describe("NodeVersionBeacon Contract Tests", () => {

    // Setup each test
    beforeEach(async () => {
        const logging = false;

        await init(BASE_PATH);
        await emulator.start({logging});
    });

    // Stop the emulator after each test
    afterEach(async () => {
        await emulator.stop();
    });

    test("Deploy NodeVersionBeacon successfully with proper initialization", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 1000;

        const page = 0;
        const perPage = 100;

        // Define expected versionTable response object & boundary pair
        const expectedVersionTablePage = {
            "page": page.toString(),
            "perPage": perPage.toString(),
            "totalLength": "1",
            "values": [
                ZERO_BOUNDARY
            ]
        };
        const expectedVersionBoundary = null;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Check contract initialized values matching expectectations
        const actualFreezePeriod = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundaryFreezePeriodFilename"]
        );
        const actualVersionTablePage = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        const actualVersionBoundary = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryFilename"]
        );

        // Check actual against expected
        expect(parseInt(actualFreezePeriod)).toEqual(expectedFreezePeriod);
        expect(actualVersionTablePage).toEqual(expectedVersionTablePage);
        expect(actualVersionBoundary).toEqual(expectedVersionBoundary);
    });

    test("Add version boundary to table succeeds", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 10;

        const page = 0;
        const perPage = 100;

        // Version & boundary values
        const expectedBlockHeightBoundary = 15;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";

        // Define expected versionTable response object & boundary pair
        const expectedVersionTablePage = {
            "page": page.toString(),
            "perPage": perPage.toString(),
            "totalLength": "2",
            "values": [
                ZERO_BOUNDARY,
                {
                    "blockHeight": expectedBlockHeightBoundary.toString(),
                    "version": {
                        "major": expectedMajor.toString(),
                        "minor": expectedMinor.toString(),
                        "patch": expectedPatch.toString(),
                        "preRelease": expectedPreRelease,
                    }
                }
            ]
        };


        const expectedVersionBoundary = expectedVersionTablePage.values[1];
        const expectedCurrentVersionBoundary = expectedVersionTablePage.values[0].version;
        const expectedCurrentVersionBoundaryString = '0.0.0'

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Add version boundary to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [expectedMajor, expectedMinor, expectedPatch, expectedPreRelease, expectedBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTable = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        const actualVersionBoundaryPair = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryFilename"]
        );
        // getCurrentNodeVersion should return null as version is upcoming
        const actualCurrentVersion = await executeScriptByFilename(
            SCRIPT_FILENAMES["getCurrentNodeVersionFilename"]
        );
        const actualCurrentVersionAsString = await executeScriptByFilename(
            SCRIPT_FILENAMES["getCurrentNodeVersionAsStringFilename"]
        );

        // Check actual against expected
        expect(actualVersionTable).toEqual(expectedVersionTablePage);
        expect(actualVersionBoundaryPair).toEqual(expectedVersionBoundary);
        expect(actualCurrentVersion).toEqual(expectedCurrentVersionBoundary);
        expect(actualCurrentVersionAsString).toEqual(expectedCurrentVersionBoundaryString);
    });

    test("Add version boundary within buffer period fails", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 100;

        const page = 0;
        const perPage = 100;

        // Version & boundary values
        const expectedBlockHeightBoundary = 15;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";

        // Define expected versionTable response object & boundary pair
        const expectedVersionTablePage = {
            "page": page.toString(),
            "perPage": perPage.toString(),
            "totalLength": "1",
            "values": [
                ZERO_BOUNDARY,
            ]
        };
        const expectedVersionBoundary = null;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Attempt to add version boundary to table - should fail & revert
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenameReverts(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [expectedMajor, expectedMinor, expectedPatch, expectedPreRelease, expectedBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTablePage = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        const actualVersionBoundary = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryFilename"]
        );

        // Check version table remains empty
        expect(actualVersionTablePage).toEqual(expectedVersionTablePage);
        expect(actualVersionBoundary).toEqual(expectedVersionBoundary);
    });

    // Insert multiple versions in mixed order - 65: 0.1.0-alpha.2, 50: 0.1.0-alpha.1, 90: 0.1.0-alpha.3
    test("Add multiple versions to table in mixed block height order, getNextVersionBoundaryPair() returns correct boundary", async () => {

        // Contract initialization arguments
        const expectedFreezePeriod = 10;

        const page = 0;
        const perPage = 100;

        // First in block height, will add to versionTable second
        const firstBlockHeightBoundary = 50;
        const firstMajor = 0;
        const firstMinor = 1;
        const firstPatch = 0;
        const firstPreRelease = "alpha.1";

        // Second in block height, will add to versionTable first
        const secondBlockHeightBoundary = 65;
        const secondMajor = 0;
        const secondMinor = 1;
        const secondPatch = 0;
        const secondPreRelease = "alpha.2";

        // Third in block height, will add to versionTable third
        const thirdBlockHeightBoundary = 90;
        const thirdMajor = 0;
        const thirdMinor = 1;
        const thirdPatch = 1;
        const thirdPreRelease = null;

        // Define expected versionTable response object & version boundary pair
        const expectedFirstSequentialVersion = {
            "major": firstMajor.toString(),
            "minor": firstMinor.toString(),
            "patch": firstPatch.toString(),
            "preRelease": firstPreRelease
        };
        const expectedSecondSequentialVersion = {
            "major": secondMajor.toString(),
            "minor": secondMinor.toString(),
            "patch": secondPatch.toString(),
            "preRelease": secondPreRelease
        };
        const expectedThirdSequentialVersion = {
            "major": thirdMajor.toString(),
            "minor": thirdMinor.toString(),
            "patch": thirdPatch.toString(),
            "preRelease": thirdPreRelease
        };
        const expectedNextVersionBoundary = {
            "blockHeight": firstBlockHeightBoundary.toString(),
            "version": {
                "major": firstMajor.toString(),
                "minor": firstMinor.toString(),
                "patch": firstPatch.toString(),
                "preRelease": firstPreRelease,
            },
        }

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Add each version boundary to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [secondMajor, secondMinor, secondPatch, secondPreRelease, secondBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [firstMajor, firstMinor, firstPatch, firstPreRelease, firstBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [thirdMajor, thirdMinor, thirdPatch, thirdPreRelease, thirdBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTable = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        const actualVersionBoundary = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryFilename"]
        );

        // Check actual against expected
        expect(actualVersionTable.values[1].version)
            .toEqual(expectedFirstSequentialVersion);
        expect(actualVersionTable.values[2].version)
            .toEqual(expectedSecondSequentialVersion);
        expect(actualVersionTable.values[3].version)
            .toEqual(expectedThirdSequentialVersion);
        expect(actualVersionBoundary)
            .toEqual(expectedNextVersionBoundary);
    });

    test("/Delete version from table successful", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 10;

        const page = 0;
        const perPage = 100;

        // Version & boundary values
        const expectedBlockHeightBoundary = 20;
        const expectedMajor = 0;
        const expectedMinor = 1;
        const expectedPatch = 2;
        const expectedPreRelease = "alpha.1";

        // Define expected versionTable response object & boundary pair
        const expectedVersionTablePage = {
            "page": page.toString(),
            "perPage": perPage.toString(),
            "totalLength": "1",
            "values": [
                ZERO_BOUNDARY,
            ]
        };
        const expectedVersionBoundary = null;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Add version to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [expectedMajor, expectedMinor, expectedPatch, expectedPreRelease, expectedBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Then delete the version
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["deleteVersionBoundaryFilename"],
            [expectedBlockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Check the version table & version boundary pair
        const actualVersionTablePage = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        const actualVersionBoundary = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionBoundaryFilename"]
        );

        // Ensure that the table is empty and no upcoming
        // boundary pair exists
        expect(actualVersionTablePage).toEqual(expectedVersionTablePage);
        expect(actualVersionBoundary).toEqual(expectedVersionBoundary);
    });

    test("/Delete version from table fails - no boundary defined at passed boundary", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 10;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Attempt to delete version
        await sendTransactionByFilenameReverts(
            TRANSACTION_FILENAMES["deleteVersionBoundaryFilename"],
            [100],
            [NodeVersionBeaconAcct]
        );
    });

    test("Change versionUpdateBuffer succeed", async () => {
        // Contract initialization arguments
        const beginningBuffer = 10;
        // Buffer and variance we'll change and expect after checking
        const expectedFreezePeriod = 12;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [beginningBuffer]);

        // Change versionUpdateBuffer
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["changeVersionFreezePeriodFilename"],
            [expectedFreezePeriod],
            [NodeVersionBeaconAcct]
        );

        // Check that the versionUpdateBuffer has changed as expected
        const actualBuffer = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundaryFreezePeriodFilename"]
        );
        expect(parseInt(actualBuffer)).toEqual(expectedFreezePeriod);
    });

    test("Change versionUpdateBuffer too close to next version block boundary fails", async () => {
        // Contract initialization arguments
        const beginningBuffer = 10;
        // Buffer we'll try to change to, but will fail
        const newBuffer = 100;

        // Version & boundary values
        const blockHeightBoundary = 20;
        const major = 0;
        const minor = 1;
        const patch = 2;
        const preRelease = "alpha.1";

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [beginningBuffer]);

        // Add version to table
        // args: [newMajor, newMinor, newPatch, newPreRelease, isBackwardCompatible, targetBlockHeight]
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [major, minor, patch, preRelease, blockHeightBoundary],
            [NodeVersionBeaconAcct]
        );

        // Attempt to change versionUpdateBuffer, but newBuffer will
        // cross the next version boundary, reverting
        await sendTransactionByFilenameReverts(
            TRANSACTION_FILENAMES["changeVersionFreezePeriodFilename"],
            [newBuffer],
            [NodeVersionBeaconAcct]
        );

        // Ensure versionUpdateBuffer is still as initialized
        const actualBuffer = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundaryFreezePeriodFilename"]
        );
        expect(parseInt(actualBuffer)).toEqual(beginningBuffer);
    });

    test("Attempt to emit versionTableUpdated without making any changes, attempt it after adding two, then after deleting one, and then once again", async () => {
        // Contract initialization arguments
        const expectedFreezePeriod = 10;

        const page = 0;
        const perPage = 100;

        // Get account and deploy contract to account
        const NodeVersionBeaconAcct = await getAccountAddress("NodeVersionBeaconAddress");
        await deployContract(NodeVersionBeaconAcct, [expectedFreezePeriod]);

        // Version & boundary values
        const expectedBlockHeightBoundary1 = 150;
        const expectedMajor1 = 0;
        const expectedMinor1 = 1;
        const expectedPatch1 = 2;
        const expectedPreRelease1 = "alpha.1";

        const expectedBlockHeightBoundary2 = 1500;
        const expectedMajor2 = 0;
        const expectedMinor2 = 1;
        const expectedPatch2 = 2;
        const expectedPreRelease2 = "alpha.2";

        // Define expected versionTable response object & boundary pair
        const expectedVersionTablePage = {
            "page": page.toString(),
            "perPage": perPage.toString(),
            "totalLength": "3",
            "values": [
                ZERO_BOUNDARY,
                {
                    "blockHeight": expectedBlockHeightBoundary1.toString(),
                    "version": {
                        "major": expectedMajor1.toString(),
                        "minor": expectedMinor1.toString(),
                        "patch": expectedPatch1.toString(),
                        "preRelease": expectedPreRelease1,
                    }
                },
                {
                    "blockHeight": expectedBlockHeightBoundary2.toString(),
                    "version": {
                        "major": expectedMajor2.toString(),
                        "minor": expectedMinor2.toString(),
                        "patch": expectedPatch2.toString(),
                        "preRelease": expectedPreRelease2,
                    }
                }
            ]
        };

        const expectedTableUpdates = [
            ZERO_BOUNDARY,
            {
                "blockHeight": expectedBlockHeightBoundary1.toString(),
                "version": {
                    "major": expectedMajor1.toString(),
                    "minor": expectedMinor1.toString(),
                    "patch": expectedPatch1.toString(),
                    "preRelease": expectedPreRelease1,
                }
            },
            {
                "blockHeight": expectedBlockHeightBoundary2.toString(),
                "version": {
                    "major": expectedMajor2.toString(),
                    "minor": expectedMinor2.toString(),
                    "patch": expectedPatch2.toString(),
                    "preRelease": expectedPreRelease2,
                }
            }
        ];

        // Simulate that the event is called for the initial zeroth event
        var emitEventResult = await shallPass(
            sendTransaction({
                name: "nodeVersionBeacon/admin/heartbeat",
                args: [],
                signers: [NodeVersionBeaconAcct]
            })
        );
        // and check that the zero event is emitted
        expect(emitEventResult[0].events.length).toEqual(1)
        expect(emitEventResult[0].events[0].data.versionBoundaries.length).toEqual(1)
        expect(emitEventResult[0].events[0].data.versionBoundaries[0]).toEqual(ZERO_BOUNDARY)

        // Simulate that the event is called before any changes are made
        emitEventResult = await shallPass(
            sendTransaction({
                name: "nodeVersionBeacon/admin/heartbeat",
                args: [],
                signers: [NodeVersionBeaconAcct]
            })
        );
        // and check that the zero event is emitted
        expect(emitEventResult[0].events.length).toEqual(0)

        // Add two new versions to the table
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [expectedMajor1, expectedMinor1, expectedPatch1, expectedPreRelease1, expectedBlockHeightBoundary1],
            [NodeVersionBeaconAcct]
        );
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["setVersionBoundaryFilename"],
            [expectedMajor2, expectedMinor2, expectedPatch2, expectedPreRelease2, expectedBlockHeightBoundary2],
            [NodeVersionBeaconAcct]
        );
        // Get the version table & version boundary pair
        const actualVersionTablePage = await executeScriptByFilename(
            SCRIPT_FILENAMES["getVersionBoundariesFilename"],
            [page, perPage],
        );
        // Check actual against expected
        expect(actualVersionTablePage).toEqual(expectedVersionTablePage);

        // Call the method to emit the event with the updates
        emitEventResult = await shallPass(
            sendTransaction({
                name: "nodeVersionBeacon/admin/heartbeat",
                args: [],
                signers: [NodeVersionBeaconAcct]
            })
        );
        // Get the next sequence number for the event
        const updatedTableNextSequenceNumber = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionUpdateSequenceFilename"]
        );
        // Check that the updates emitted match the expected
        expect(emitEventResult[0].events[0].data.versionBoundaries).toEqual(expectedTableUpdates);
        // And that the next sequence number will be one
        expect(parseInt(updatedTableNextSequenceNumber)).toEqual(2);

        // Delete the second version
        await sendTransactionByFilenamePasses(
            TRANSACTION_FILENAMES["deleteVersionBoundaryFilename"],
            [expectedBlockHeightBoundary2],
            [NodeVersionBeaconAcct]
        );
        const expectedTableUpdates2 = [
            ZERO_BOUNDARY,
            {
                "blockHeight": expectedBlockHeightBoundary1.toString(),
                "version": {
                    "major": expectedMajor1.toString(),
                    "minor": expectedMinor1.toString(),
                    "patch": expectedPatch1.toString(),
                    "preRelease": expectedPreRelease1,
                }
            }
        ];
        // Call the method to emit the event with the updates
        emitEventResult = await shallPass(
            sendTransaction({
                name: "nodeVersionBeacon/admin/heartbeat",
                args: [],
                signers: [NodeVersionBeaconAcct]
            })
        );
        // Get the next sequence number for the event
        const updatedTableNextSequenceNumber2 = await executeScriptByFilename(
            SCRIPT_FILENAMES["getNextVersionUpdateSequenceFilename"]
        );
        // Check that the updates emitted match the expected
        expect(emitEventResult[0].events[0].data.versionBoundaries).toEqual(expectedTableUpdates2);
        // And that the next sequence number will be one
        expect(parseInt(updatedTableNextSequenceNumber2)).toEqual(3);


        // We check again that without new changes the event isn't emitted
        emitEventResult = await shallPass(
            sendTransaction({
                name: "nodeVersionBeacon/admin/heartbeat",
                args: [],
                signers: [NodeVersionBeaconAcct]
            })
        );
        expect(emitEventResult[0].events.length).toEqual(0)

    })
    ;

});

// Deploys the NodeVersionBeacon to the passed account
async function deployContract(to, args) {
    try {
        const [result, deployError] = await shallPass(
            deployContractByName({
                to: to,
                name: "NodeVersionBeacon",
                args: args
            })
        );
        expect(deployError).toBeNull();
    } catch (error) {
        throw error;
    }
    ;
};