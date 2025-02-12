import "FlowIDTableStaking"
import "FlowToken"
import "FungibleToken"


transaction(amount: UFix64) {

    // Local variable for a reference to the delegator object
    let delegatorRef: auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator

    let flowTokenRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the delegator object
        self.delegatorRef = acct.storage.borrow<auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath)
            ?? panic("Could not borrow reference to delegator")

        self.flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

    }

    execute {

        self.delegatorRef.delegateNewTokens(from: <-self.flowTokenRef.withdraw(amount: amount))

    }
}