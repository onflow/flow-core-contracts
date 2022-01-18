import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// Returns an array of DelegatorInfo objects that the account controls
// in its normal account and shared account
pub fun main(account: Address): [FlowIDTableStaking.DelegatorInfo] {

    let delegatorInfoArray: [FlowIDTableStaking.DelegatorInfo] = []

    // DelegatorInfo objects in its normal account
    if FlowStakingCollection.doesAccountHaveStakingCollection(address: account) {
        delegatorInfoArray.appendAll(FlowStakingCollection.getAllDelegatorInfo(address: account))
    }

    let lockedAccountInfoCap = getAccount(account)
        .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
            LockedTokens.LockedAccountInfoPublicPath
        )
    if let lockedAccountInfoRef = lockedAccountInfoCap.borrow() {
        // DelegatorInfo objects in its shared account
        if FlowStakingCollection.doesAccountHaveStakingCollection(address: lockedAccountInfoRef.getLockedAccountAddress()) {
            delegatorInfoArray.appendAll(FlowStakingCollection.getAllDelegatorInfo(address: lockedAccountInfoRef.getLockedAccountAddress()))
        }
    }

    return delegatorInfoArray
}
