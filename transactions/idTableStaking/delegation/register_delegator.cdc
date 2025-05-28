import "FlowIDTableStaking"
import "FlowToken"
import "FungibleToken"

transaction(nodeID: String, amount: UFix64) {

    prepare(acct: auth(Storage, Capabilities) &Account) {

        let flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Create a new delegator object for the node
        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-flowTokenRef.withdraw(amount: amount))

        // Store the delegator object
        acct.storage.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        let delegatorCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeDelegatorPublic}>(FlowIDTableStaking.DelegatorStoragePath)
        acct.capabilities.publish(delegatorCap, at: /public/flowStakingDelegator)
    }
}