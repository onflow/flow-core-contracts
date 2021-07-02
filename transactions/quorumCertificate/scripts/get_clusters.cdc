import FlowClusterQC from 0xQCADDRESS

// Script to return an array of Collector Clusters with all of their metadata

pub fun main(clusterIndex: UInt16): [FlowClusterQC.Cluster] {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex]

}