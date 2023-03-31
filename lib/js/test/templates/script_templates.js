import fs from "fs";
import path from "path";
import { expect } from "@jest/globals";
import { executeScript } from "@onflow/flow-js-testing";

export const SCRIPT_FILENAMES = {
    getCurrentNodeVersionFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_current_node_version.cdc",
    getCurrentNodeVersionAsStringFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_current_node_version_as_string.cdc",
    getNextVersionBoundaryFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_next_version_boundary.cdc",
    getVersionBoundariesFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_version_boundaries.cdc",
    getVersionBoundaryFreezePeriodFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_version_boundary_freeze_period.cdc",
    getNextVersionUpdateSequenceFilename: "./../../../../transactions/nodeVersionBeacon/scripts/get_next_version_update_sequence.cdc",
}

// Executes get_current_minimum_node_version script
export async function executeScriptByFilename(filename, args) {
    const code = readScriptFile(
        filename,
        args
    );

    const [result, err] = await executeScript({ code, args });
    expect(err).toBeNull();
    return result;
}

function readScriptFile(filename) {
    try {
        return fs.readFileSync(
            path.resolve(
                __dirname,
                filename
            ),
            {encoding:'utf8', flag:'r'}
        );
    } catch (error) {
        throw error
    }
}
