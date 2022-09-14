import fs from "fs";
import path from "path";
import { expect } from "@jest/globals";
import { executeScript } from "@onflow/flow-js-testing";

export const SCRIPT_FILENAMES = {
    getCurrentMinimumExecutionNodeVersionFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_current_minimum_execution_node_version.cdc",
    getNextVersionBoundaryPairFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_next_version_boundary_pair.cdc",
    getVersionTableFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_table.cdc",
    getVersionUpdateBufferFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_update_buffer.cdc",
    getVersionUpdateBufferVarianceFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_update_buffer_variance.cdc",
    isCompatibleVersionFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/is_compatible_version.cdc",
}

// Executes get_current_minimum_execution_node_version script
export async function executeScriptByFilename(filename, args) {
    const code = readScriptFile(
        filename,
        args
    );

    const [result, err] = await executeScript({ code });
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

};
