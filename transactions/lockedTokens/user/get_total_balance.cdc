import "FungibleToken"
import "FlowToken"
import "FlowIDTableStaking"
import "LockedTokens"

// This script gets the TOTAL number of FLOW an account owns, across unlocked, locked, and staking.

// Adds up these numbers:

// tokens in normal account
// tokens in normal account staking
// tokens in normal account delegating
// tokens in shared account
// tokens in shared account staking
// tokens in shared account delegating


access(all) fun main(address: Address): UFix64 {

    var sum = 0.0

    let account = getAccount(address)

    if let vaultRef = account.capabilities.borrow<&FlowToken.Vault>(/public/flowTokenBalance) {
        sum = sum + vaultRef.balance
    }

    // Get token balance from the unlocked account's node staking pools
    let optionalNodeStakerRef = account
        .capabilities.borrow<&{FlowIDTableStaking.NodeStakerPublic}>(
            FlowIDTableStaking.NodeStakerPublicPath
        )

    if let nodeStakerRef = optionalNodeStakerRef {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStakerRef.id)
        sum = sum + nodeInfo.totalTokensInRecord()
    }

    // Get token balance from the unlocked account's delegator staking pools
    let optionalDelegatorRef = account
        .capabilities.borrow<&{FlowIDTableStaking.NodeDelegatorPublic}>(
            /public/flowStakingDelegator
        )

    if let delegatorRef = optionalDelegatorRef {
        let delegatorInfo = FlowIDTableStaking.DelegatorInfo(
            nodeID: delegatorRef.nodeID,
            delegatorID: delegatorRef.id
        )
        sum = sum + delegatorInfo.totalTokensInRecord()
 
    }

    // Get the locked account public capability
    let optionalLockedAccountInfoRef = account
        .capabilities.borrow<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )

    if let lockedAccountInfoRef = optionalLockedAccountInfoRef {
        // Add the locked account balance
        sum = sum + lockedAccountInfoRef.getLockedAccountBalance()

        // Add the balance of all the node staking pools from the locked account
        if let nodeID = lockedAccountInfoRef.getNodeID() {
            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            sum = sum + nodeInfo.totalTokensInRecord()
        }

        // Add the balance of all the delegator staking pools from the locked account
        if let delegatorID = lockedAccountInfoRef.getDelegatorID() {
            if let nodeID = lockedAccountInfoRef.getDelegatorNodeID() {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
                sum = sum + delegatorInfo.totalTokensInRecord()
            }
        }
    }

    return sum
}
