import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(randomSource: String,
            collectorClusters: [String]
            clusterQCs: [String],
            dkgPubKeys: [String],
            totalRewards: totalRewards) {

    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        heartbeat.resetEpoch(randomSource: randomSource,
                             collectorClusters: [],
                             clusterQCs: [],
                             dkgPubKeys: [],
                             totalRewards: totalRewards)
    }
}