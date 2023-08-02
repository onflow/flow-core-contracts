import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Returns an array of all the node IDs stored in the staking collection

access(all) fun main(address: Address): [String] {
    return FlowStakingCollection.getNodeIDs(address: address)
}