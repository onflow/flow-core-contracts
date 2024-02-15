import FlowEpoch from "FlowEpoch"
import FlowClusterQC from 0xQCADDRESS

access(all) fun main(array: [String]): [FlowClusterQC.Cluster] {
    return FlowEpoch.createCollectorClusters(nodeIDs: array)
}
