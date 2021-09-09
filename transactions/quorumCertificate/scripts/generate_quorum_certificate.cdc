import FlowClusterQC from 0xQCADDRESS

// Gets the status of a cluster's QC generation

pub fun main(clusterIndex: UInt16): FlowClusterQC.ClusterQC {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex].generateQuorumCertificate()
        ?? panic("Could not generate quorum certificate")

}