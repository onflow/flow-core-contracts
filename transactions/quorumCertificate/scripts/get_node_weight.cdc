import FlowClusterQC from 0xQCADDRESS

pub fun main(clusterIndex: UInt16, nodeID: String): UInt64 {

    let clusters = FlowClusterQC.getClusters()

    if clusters[clusterIndex].nodeWeights[nodeID] != nil {
        return clusters[clusterIndex].nodeWeights[nodeID]!
    } else {
        return 0 as UInt64
    }

}