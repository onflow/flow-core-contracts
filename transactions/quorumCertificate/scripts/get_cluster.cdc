import FlowEpochClusterQC from 0xQCADDRESS

pub fun main(clusterIndex: UInt16): FlowEpochClusterQC.Cluster {

    let clusters = FlowEpochClusterQC.getClusters()

    return clusters[clusterIndex]

}