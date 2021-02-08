import FlowEpochClusterQC from 0xQCADDRESS

// Returns an array of Votes for the specified cluster

pub fun main(clusterIndex: UInt16): [FlowEpochClusterQC.Vote] {

    let clusters = FlowEpochClusterQC.getClusters()

    return clusters[clusterIndex].votes

}