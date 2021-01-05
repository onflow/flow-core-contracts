import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Returns an array of NodeInfo objects that the account controls
// in its normal account and shared account

pub fun main(account: Address): [FlowIDTableStaking.NodeInfo] {

    let nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

    let pubAccount = getAccount(account)

    let nodeStaker = pubAccount.getCapability<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath)!
        .borrow()

    if let nodeRef = nodeStaker {
        nodeInfoArray.append(FlowIDTableStaking.NodeInfo(nodeID: nodeRef.id))
    }

    let lockedAccountInfoCap = pubAccount
        .getCapability
        <&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>
        (LockedTokens.LockedAccountInfoPublicPath)

    if lockedAccountInfoCap == nil || !(lockedAccountInfoCap!.check()) {
        return nodeInfoArray
    }

    if let lockedAccountInfoRef = lockedAccountInfoCap!.borrow() {
    
        if (lockedAccountInfoRef.getNodeID() == nil) {
            return nodeInfoArray
        }

        nodeInfoArray.append(FlowIDTableStaking.NodeInfo(nodeID: lockedAccountInfoRef.getNodeID()!))
    }

    return nodeInfoArray
}
