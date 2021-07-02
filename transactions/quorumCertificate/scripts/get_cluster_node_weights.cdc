import FlowClusterQC from 0xQCADDRESS

pub fun main(clusterIndex: UInt16): {String: UInt64} {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].nodeWeights

}