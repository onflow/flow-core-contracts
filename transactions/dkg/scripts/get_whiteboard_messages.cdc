import "FlowDKG"

access(all) fun main(): [FlowDKG.Message] {
    return FlowDKG.getWhiteBoardMessages() 
}