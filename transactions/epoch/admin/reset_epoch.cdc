import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

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