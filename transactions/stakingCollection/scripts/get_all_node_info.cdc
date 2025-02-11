import "FlowStakingCollection"
import "FlowIDTableStaking"

/// Gets an array of all the node metadata for nodes stored in the staking collection

access(all) fun main(address: Address): [FlowIDTableStaking.NodeInfo] {
    return FlowStakingCollection.getAllNodeInfo(address: address)
}