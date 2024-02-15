import FlowClusterQC from "FlowClusterQC"

access(all) fun main(clusterIndex: UInt16): UInt64 {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].totalWeight

}