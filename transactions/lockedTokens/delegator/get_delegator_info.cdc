import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Returns an array of DelegatorInfo objects that the account controls
// in its normal account and shared account

pub fun main(account: Address): [FlowIDTableStaking.DelegatorInfo] {

    let delegatorInfoArray: [FlowIDTableStaking.DelegatorInfo] = []

    let pubAccount = getAccount(account)

    let delegator = pubAccount.getCapability<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator)!
        .borrow()

    if let delegatorRef = delegator {
        delegatorInfoArray.append(FlowIDTableStaking.DelegatorInfo(nodeID: delegatorRef.nodeID, delegatorID: delegatorRef.id))
    }

    let lockedAccountInfoCap = pubAccount
        .getCapability
        <&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>
        (LockedTokens.LockedAccountInfoPublicPath)

    if lockedAccountInfoCap == nil || !(lockedAccountInfoCap!.check()) {
        return delegatorInfoArray
    }

    let lockedAccountInfo = lockedAccountInfoCap!.borrow()

    if let lockedAccountInfoRef = lockedAccountInfo {
        let nodeID = lockedAccountInfoRef.getDelegatorNodeID()
        let delegatorID = lockedAccountInfoRef.getDelegatorID()

        if (nodeID == nil || delegatorID == nil) {
            return delegatorInfoArray
        }

        delegatorInfoArray.append(FlowIDTableStaking.DelegatorInfo(nodeID: nodeID!, delegatorID: delegatorID!))
    }

    return delegatorInfoArray
}
