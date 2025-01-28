import FlowIDTableStaking from "FlowIDTableStaking"
import FlowEpoch from "FlowEpoch"
import FlowClusterQC from "FlowClusterQC"

// This transaction invokes recoverNewEpoch without the safety checks that exist in the
// production version of the transaction. Used for testing only.
transaction(recoveryEpochCounter: UInt64,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            targetDuration: UInt64,
            targetEndTime: UInt64,
            clusterAssignments: [[String]],
            clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],
            dkgPubKeys: [String],
            dkgGroupKey: String,
            dkgIdMapping: {String: Int},
            nodeIDs: [String],
            unsafeAllowOverwrite: Bool) {

    prepare(signer: auth(BorrowValue) &Account) {
        let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow epoch admin from storage path")

        epochAdmin.recoverNewEpoch(
                recoveryEpochCounter: recoveryEpochCounter,
                startView: startView,
                stakingEndView: stakingEndView,
                endView: endView,
                targetDuration: targetDuration,
                targetEndTime: targetEndTime,
                clusterAssignments: clusterAssignments,
                clusterQCVoteData: clusterQCVoteData,
                dkgPubKeys: dkgPubKeys,
                dkgGroupKey: dkgGroupKey,
                dkgIdMapping: dkgIdMapping,
                nodeIDs: nodeIDs
            )
    }
}