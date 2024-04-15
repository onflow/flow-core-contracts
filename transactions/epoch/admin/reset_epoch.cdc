import FlowEpoch from "FlowEpoch"
import FlowIDTableStaking from "FlowIDTableStaking"

// The resetEpoch transaction ends the current epoch in the FlowEpoch smart contract
// and begins a new epoch with the given configuration. The new epoch always has
// the counter currentEpochCounter+1. The transaction sender must provide the 
// currentEpochCounter (before the reset takes place) as a safety mechanism.
//
// During network sporks, the bootstrapped protocol state is in a new Epoch (currentEpochCounter+1),
// and resetEpoch is used to change the epoch counter in the FlowEpoch smart contract
// from currentEpochCounter to (currentEpochCounter + 1), so that it's consistent with 
// the bootstrapped protocol state.
// This transaction should only be used with the output of the bootstrap utility:
//   util epoch reset-tx-args

transaction(currentEpochCounter: UInt64,
            randomSource: String,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64) {

    prepare(signer: auth(BorrowValue) &Account) {
        let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow epoch admin from storage path")

        epochAdmin.resetEpoch(currentEpochCounter: currentEpochCounter,
                            randomSource: randomSource,
                             startView: startView,
                             stakingEndView: stakingEndView,
                             endView: endView,
                             collectorClusters: [],
                             clusterQCs: [],
                             dkgPubKeys: [])
    }
}
