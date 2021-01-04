import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

pub fun main(account: Address): FlowIDTableStaking.NodeInfo? {
    let lockedAccountInfoCap = getAccount(account)
        .getCapability
        <&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>
        (LockedTokens.LockedAccountInfoPublicPath)
    if lockedAccountInfoCap == nil || !(lockedAccountInfoCap!.check()) {
        return nil
    }
    let lockedAccountInfoRef = lockedAccountInfoCap!.borrow() ?? panic("Could not borrow a reference to public LockedAccountInfo")
    if (lockedAccountInfoRef.getNodeID() == nil) {
        return nil
    }
    return FlowIDTableStaking.NodeInfo(nodeID: lockedAccountInfoRef.getNodeID()!)
}
