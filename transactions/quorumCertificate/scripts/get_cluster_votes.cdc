import FlowClusterQC from 0xQCADDRESS

// Returns an array of Votes for the specified cluster

pub fun main(clusterIndex: UInt16): [FlowClusterQC.Vote] {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].votes

}