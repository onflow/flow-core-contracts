import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// Returns an array of NodeInfo objects that the account controls
// in its normal account and shared account

pub fun main(account: Address): [FlowIDTableStaking.NodeInfo] {

    let nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

    // NodeInfo objects in its normal account
    if FlowStakingCollection.doesAccountHaveStakingCollection(address: account) {
        nodeInfoArray.appendAll(FlowStakingCollection.getAllNodeInfo(address: account))
    }

    let lockedAccountInfoCap = getAccount(account)
        .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
            LockedTokens.LockedAccountInfoPublicPath
        )
    if let lockedAccountInfoRef = lockedAccountInfoCap.borrow() {
        // NodeInfo objects in its shared account
        if FlowStakingCollection.doesAccountHaveStakingCollection(address: lockedAccountInfoRef.getLockedAccountAddress()) {
            nodeInfoArray.appendAll(FlowStakingCollection.getAllNodeInfo(address: lockedAccountInfoRef.getLockedAccountAddress()))
        }
    }

    return nodeInfoArray
}
