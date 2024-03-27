import FlowClusterQC from "FlowClusterQC"

// Returns an array of Votes for the specified cluster

access(all) fun main(clusterIndex: UInt16): [FlowClusterQC.Vote] {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].votes

}