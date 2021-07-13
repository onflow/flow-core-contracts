import FlowClusterQC from 0xQCADDRESS

pub fun main(clusterIndex: UInt16): FlowClusterQC.Cluster {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex]

}