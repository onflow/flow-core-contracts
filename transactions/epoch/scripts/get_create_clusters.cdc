import FlowEpoch from 0xEPOCHADDRESS
import FlowEpochClusterQC from 0xQCADDRESS

pub fun main(array: [String]): [FlowEpochClusterQC.Cluster] {

    return FlowEpoch.createCollectorClusters(nodeIDs: array)

}