import FlowEpoch from "FlowEpoch"
import FlowClusterQC from "FlowClusterQC"

access(all) fun main(array: [String]): [FlowClusterQC.Cluster] {
    return FlowEpoch.createCollectorClusters(nodeIDs: array)
}
