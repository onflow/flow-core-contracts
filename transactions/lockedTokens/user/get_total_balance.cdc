import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xTOKENADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS


pub fun main(address: Address): UFix64 {

    var sum = 0.0

    let account = getAccount(address)

    let vaultRef = account
        .getCapability(/public/flowTokenBalance)!
        .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
        ?? panic("Could not borrow Balance reference to the Vault")

    sum = sum + vaultRef.balance

    let lockedAccountInfoCap = account
        .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
            LockedTokens.LockedAccountInfoPublicPath
        )!

    if let lockedAccountInfoRef = lockedAccountInfoCap.borrow() {
        sum = sum + lockedAccountInfoRef.getLockedAccountBalance()

        if let nodeID = lockedAccountInfoRef.getNodeID() {
            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            sum = sum + nodeInfo.tokensStaked + nodeInfo.totalTokensStaked + nodeInfo.tokensCommitted + nodeInfo.tokensUnstaking + nodeInfo.tokensUnstaked + nodeInfo.tokensRewarded
        }

        if let delegatorID = lockedAccountInfoRef.getDelegatorID() {
            if let nodeID = lockedAccountInfoRef.getDelegatorNodeID() {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                sum = sum + delegatorInfo.tokensStaked + delegatorInfo.tokensCommitted + delegatorInfo.tokensUnstaking + delegatorInfo.tokensUnstaked + delegatorInfo.tokensRewarded
            }
        }
    }

    return sum
}
