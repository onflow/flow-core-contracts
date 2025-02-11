import "FlowDKG"

access(all) fun main(nodeID: String): Bool {
    return FlowDKG.nodeHasSubmitted(nodeID)
}