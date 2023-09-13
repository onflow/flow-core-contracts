import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"

transaction(nodeID: String, amount: UFix64) {

    prepare(acct: auth(Storage) &Account) {

        let flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Create a new delegator object for the node
        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-flowTokenRef.withdraw(amount: amount))

        // Store the delegator object
        acct.storage.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        let delegatorCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeDelegatorPublic}>(FlowIDTableStaking.DelegatorStoragePath)
        acct.capabilities.storage.issue(delegatorCap, at: /public/flowStakingDelegator)
    }
}