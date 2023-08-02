import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from "FlowIDTableStaking"

/// Gets an array of all the node metadata for nodes stored in the staking collection

access(all) fun main(address: Address): [FlowIDTableStaking.NodeInfo] {
    return FlowStakingCollection.getAllNodeInfo(address: address)
}