import FlowIDTableStaking from "FlowIDTableStaking"
import LockedTokens from "LockedTokens"

// Returns an array of NodeInfo objects that the account controls
// in its normal account and shared account

access(all) fun main(account: Address): [FlowIDTableStaking.NodeInfo] {

    let nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

    let pubAccount = getAccount(account)

    let optionalNodeStakerRef = pubAccount
        .capabilities.borrow<&{FlowIDTableStaking.NodeStakerPublic}>(
            FlowIDTableStaking.NodeStakerPublicPath
        )

    if let nodeStakerRef = optionalNodeStakerRef {
        let info = FlowIDTableStaking.NodeInfo(nodeID: nodeStakerRef.id)
        nodeInfoArray.append(info)
    }

    let optionalLockedAccountInfoRef = pubAccount
        .capabilities.borrow<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )

    if let lockedAccountInfoRef = optionalLockedAccountInfoRef {
        if let nodeID = lockedAccountInfoRef.getNodeID() {
            let info = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            nodeInfoArray.append(info)
        }
    }

    return nodeInfoArray
}
