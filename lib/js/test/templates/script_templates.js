import fs from "fs";
import path from "path";
import { expect } from "@jest/globals";
import { executeScript } from "@onflow/flow-js-testing";

export const SCRIPT_FILENAMES = {
    getCurrentMinimumExecutionNodeVersionFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_current_minimum_execution_node_version.cdc",
    getCurrentMinimumExecutionNodeVersionAsStringFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_current_minimum_execution_node_version_as_string.cdc",
    getNextVersionBoundaryPairFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_next_version_boundary_pair.cdc",
    getVersionTableFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_table.cdc",
    getVersionUpdateBufferFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_update_buffer.cdc",
    getVersionUpdateBufferVarianceFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_update_buffer_variance.cdc",
    isCompatibleVersionFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/is_compatible_version.cdc",
    getCurrentBlockHeightFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_current_block_height.cdc"
}

// Executes get_current_minimum_execution_node_version script
export async function executeScriptByFilename(filename, args) {
    const code = readScriptFile(
        filename,
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
};
