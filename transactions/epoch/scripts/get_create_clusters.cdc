import FlowEpoch from 0xEPOCHADDRESS
import FlowClusterQC from 0xQCADDRESS

access(all) fun main(array: [String]): [FlowClusterQC.Cluster] {

    return FlowEpoch.createCollectorClusters(nodeIDs: array)

}