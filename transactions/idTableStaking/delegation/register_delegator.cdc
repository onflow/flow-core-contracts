import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

transaction(nodeID: String, amount: UFix64) {

    prepare(acct: AuthAccount) {

        let flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Create a new delegator object for the node
        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-flowTokenRef.withdraw(amount: amount))

        // Store the delegator object
        acct.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        acct.link<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator, target: FlowIDTableStaking.DelegatorStoragePath)
    }

}