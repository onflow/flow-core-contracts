import FlowClusterQC from 0xQCADDRESS

pub fun main(clusterIndex: UInt16): UInt64 {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].voteThreshold()

}