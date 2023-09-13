import FlowIDTableStaking from "FlowIDTableStaking"
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Returns an array of NodeInfo objects that the account controls
// in its normal account and shared account

access(all) fun main(account: Address): [FlowIDTableStaking.NodeInfo] {

    let nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

    let pubAccount = getAccount(account)

    let nodeStakerCap = pubAccount
        .capabilities.get<&{FlowIDTableStaking.NodeStakerPublic}>(
            FlowIDTableStaking.NodeStakerPublicPath
        )!

    if let nodeStakerRef = nodeStakerCap.borrow() {
        let info = FlowIDTableStaking.NodeInfo(nodeID: nodeStakerRef.id)
        nodeInfoArray.append(info)
    }

    let lockedAccountInfoCap = pubAccount
        .capabilities.get<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )!

    if let lockedAccountInfoRef = lockedAccountInfoCap.borrow() {
        if let nodeID = lockedAccountInfoRef.getNodeID() {
            let info = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            nodeInfoArray.append(info)
        }
    }

    return nodeInfoArray
}
