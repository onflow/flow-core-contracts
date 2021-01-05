import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

pub fun main(account: Address): FlowIDTableStaking.DelegatorInfo? {
    let lockedAccountInfoCap = getAccount(account)
        .getCapability
        <&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>
        (LockedTokens.LockedAccountInfoPublicPath)
    if lockedAccountInfoCap == nil || !(lockedAccountInfoCap!.check()) {
        return nil
    }
    let lockedAccountInfoRef = lockedAccountInfoCap!.borrow() ?? panic("Could not borrow a reference to public LockedAccountInfo")
    let nodeID = lockedAccountInfoRef.getDelegatorNodeID()
    let delegatorID = lockedAccountInfoRef.getDelegatorID()
    if (nodeID == nil || delegatorID == nil) {
        return nil
    }
    return FlowIDTableStaking.DelegatorInfo(nodeID: nodeID!, delegatorID: delegatorID!)
}
