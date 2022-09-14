import fs from "fs";
import path from "path";

export const TRANSACTION_FILENAMES = {
    addVersionToTableFilename: "./../../../../transactions/executionNodeVersionBeacon/admin/add_version_to_table.cdc",
    changeVersionUpdateBufferFilename: "./../../../../transactions/executionNodeVersionBeacon/admin/change_version_update_buffer.cdc",
    changeVersionUpdateBufferVarianceFilename: "./../../../../transactions/executionNodeVersionBeacon/scripts/get_version_update_buffer.cdc",
    deleteLatestVersionFilename: "./../../../../transactions/executionNodeVersionBeacon/admin/delete_latest_version.cdc",
}

function readTransactionFile(filename) {
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