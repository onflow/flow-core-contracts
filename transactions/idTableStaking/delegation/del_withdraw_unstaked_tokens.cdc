import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"


transaction(amount: UFix64) {

    // Local variable for a reference to the delegator object
    let delegatorRef: auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator

    let flowTokenRef: &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the delegator object
        self.delegatorRef = acct.storage.borrow<auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath)
            ?? panic("Could not borrow reference to staking admin")

        self.flowTokenRef = acct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

    }

    execute {

        self.flowTokenRef.deposit(from: <-self.delegatorRef.withdrawUnstakedTokens(amount: amount))

    }
}