import FlowEpoch from 0xEPOCHADDRESS
import FlowClusterQC from 0xQCADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(currentEpochCounter: UInt64,
            randomSource: String,
            newPayout: UFix64?,
            startView: UInt64,
            endView: UInt64,
            clusterWeights: [{String: UInt64}]) {

    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        // first, construct Cluster objects from cluster weights
        let clusters: [FlowClusterQC.Cluster] = []
        var clusterIndex: UInt16 = 0
        for weightMapping in clusterWeights {
            let cluster = FlowClusterQC.Cluster(clusterIndex, weightMapping)
            clusterIndex = clusterIndex + 1
        }

        heartbeat.resetEpoch(currentEpochCounter: currentEpochCounter,
                            randomSource: randomSource,
                             newPayout: newPayout,
                             startView: startView,
                             endView: endView,
                             collectorClusters: clusters,
                             clusterQCs: [],
                             dkgPubKeys: [])
    }
}