import FlowClusterQC from "FlowClusterQC"

// Gets the status of a cluster's QC generation

access(all) fun main(clusterIndex: UInt16): Bool {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].isComplete() != nil

}