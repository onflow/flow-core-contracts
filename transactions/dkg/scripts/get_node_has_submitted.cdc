import FlowDKG from 0xDKGADDRESS

access(all) fun main(nodeID: String): Bool {
    return FlowDKG.nodeHasSubmitted(nodeID)
}