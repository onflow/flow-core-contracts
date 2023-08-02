import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"

transaction(nodeID: String, amount: UFix64) {

    prepare(acct: AuthAccount) {

        let flowTokenRef = acct.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Create a new delegator object for the node
        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-flowTokenRef.withdraw(amount: amount))

        // Store the delegator object
        acct.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        acct.link<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator, target: FlowIDTableStaking.DelegatorStoragePath)
    }

}