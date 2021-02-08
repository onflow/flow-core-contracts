import FlowEpochClusterQC from 0xQCADDRESS

// Script to return an array of Collector Clusters with all of their metadata

pub fun main(clusterIndex: UInt16): [FlowEpochClusterQC.Cluster] {

    let clusters = FlowEpochClusterQC.getClusters()

    return clusters[clusterIndex]

}