import FlowClusterQC from "FlowClusterQC"

// Script to return an array of Collector Clusters with all of their metadata

access(all) fun main(clusterIndex: UInt16): [FlowClusterQC.Cluster] {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex]

}