import "FlowIDTableStaking"
import "FlowToken"
import "FungibleToken"

transaction(amount: UFix64) {

    // Local variable for a reference to the node object
    let stakerRef: auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker

    let flowTokenRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the node object
        self.stakerRef = acct.storage.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow reference to staking admin")

        self.flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")
    }

    execute {
        self.stakerRef.stakeNewTokens(<-self.flowTokenRef.withdraw(amount: amount))
    }
}
