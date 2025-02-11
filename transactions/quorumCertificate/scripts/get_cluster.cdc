import "FlowClusterQC"

access(all) fun main(clusterIndex: UInt16): FlowClusterQC.Cluster {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex]

}