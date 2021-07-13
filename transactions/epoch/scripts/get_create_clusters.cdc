import FlowEpoch from 0xEPOCHADDRESS
import FlowClusterQC from 0xQCADDRESS

pub fun main(array: [String]): [FlowClusterQC.Cluster] {

    return FlowEpoch.createCollectorClusters(nodeIDs: array)

}