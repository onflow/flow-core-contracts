import "FlowEpoch"
import "FlowIDTableStaking"
import "FlowClusterQC"

// The recoverEpoch transaction creates and starts a new epoch in the FlowEpoch smart contract
// which will cause the network exit Epoch Fallback Mode [EFM]. The RecoverEpoch service event
// will be processed by the consensus committee, which will add it to the Protocol State.
//
// This transaction should only be used with the output of the bootstrap utility:
//   util epoch efm-recover-tx-args
//
// NOTE: setting unsafeAllowOverwrite to true will allow the FlowEpoch contract to overwrite the current 
// epoch with the new configuration, if the recoveryEpochCounter matches (otherwise will panic).
// This function exists to recover from potential race conditions that caused a prior recoverCurrentEpoch transaction to fail;
// this allows operators to retry the recovery procedure, overwriting the prior failed attempt.
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
            ?? panic("Could not borrow epoch admin from ".concat(FlowEpoch.adminStoragePath.toString()))

        let proposedEpochCounter = FlowEpoch.proposedEpochCounter()
        if recoveryEpochCounter == proposedEpochCounter {
            // Typical path: RecoveryEpoch uses proposed epoch counter (+1 from current)
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
        } else {
            // Atypical path: RecoveryEpoch is overwriting existing epoch. 
            // CAUTION: This causes data loss by replacing the existing current epoch metadata with the inputs to this function.
            // This function exists to recover from potential race conditions that caused a prior recoverCurrentEpoch transaction to fail;
            // this allows operators to retry the recovery procedure, overwriting the prior failed attempt.
            if !unsafeAllowOverwrite {
                panic("Cannot overwrite existing epoch without unsafeAllowOverwrite set to true")
            }
            epochAdmin.recoverCurrentEpoch(
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
}
