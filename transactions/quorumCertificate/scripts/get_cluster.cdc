import FlowClusterQC from 0xQCADDRESS

access(all) fun main(clusterIndex: UInt16): FlowClusterQC.Cluster {

    let clusters = FlowClusterQC.getClusters()

    return clusters[clusterIndex]

}