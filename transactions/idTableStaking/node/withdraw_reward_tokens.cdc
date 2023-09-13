import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"


transaction(amount: UFix64) {

    // Local variable for a reference to the node object
    let stakerRef: auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker

    let flowTokenRef: &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the node object
        self.stakerRef = acct.storage.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow reference to staking admin")

        self.flowTokenRef = acct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")
    }

    execute {
        self.flowTokenRef.deposit(from: <-self.stakerRef.withdrawRewardedTokens(amount: amount))
    }
}
