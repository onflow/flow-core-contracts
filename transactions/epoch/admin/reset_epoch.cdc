import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// The resetEpoch transaction ends the current epoch in the FlowEpoch smart contract
// and begins a new epoch with the given configuration. The new epoch always has
// the counter currentEpochCounter+1. The transaction sender must provide the 
// currentEpochCounter (before the reset takes place) as a safety mechanism.
//
// During network sporks, resetEpoch is used to synchronize the FlowEpoch smart contract
// and the bootstrapped protocol state on a consistent post-spork epoch configuration.
// This transaction should only be used with the output of the bootstrap utility:
//   util epoch reset-tx-args

transaction(currentEpochCounter: UInt64,
            randomSource: String,
            newPayout: UFix64?,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64) {

    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        heartbeat.resetEpoch(currentEpochCounter: currentEpochCounter,
                            randomSource: randomSource,
                             newPayout: newPayout,
                             startView: startView,
                             stakingEndView: stakingEndView,
                             endView: endView,
                             collectorClusters: [],
                             clusterQCs: [],
                             dkgPubKeys: [])
    }
}
