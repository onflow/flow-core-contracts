import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(randomSource: String,
            newPayout: UFix64,
            startView: UInt64,
            endView: UInt64,
            collectorClusters: [String]
            clusterQCs: [String],
            dkgPubKeys: [String]) {

    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        heartbeat.resetEpoch(randomSource: randomSource,
                             newPayout: newPayout,
                             startView: startView,
                             endView: endView,
                             collectorClusters: [],
                             clusterQCs: [],
                             dkgPubKeys: [])
    }
}