import "FlowEpoch"
import "FlowClusterQC"

access(all) fun main(array: [String]): [FlowClusterQC.Cluster] {
    return FlowEpoch.createCollectorClusters(nodeIDs: array)
}
