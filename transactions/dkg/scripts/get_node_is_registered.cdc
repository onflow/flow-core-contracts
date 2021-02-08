import FlowDKG from 0xDKGADDRESS

pub fun main(nodeID: String): Bool {
    return FlowDKG.participantIsRegistered(nodeID)
}