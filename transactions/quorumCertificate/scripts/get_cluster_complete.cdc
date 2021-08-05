import FlowClusterQC from 0xQCADDRESS

// Gets the status of a cluster's QC generation

pub fun main(clusterIndex: UInt16): Bool {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].isComplete() != nil

}