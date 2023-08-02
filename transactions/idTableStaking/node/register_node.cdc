import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"

// This transaction creates a new node struct object
// and updates the proposed Identity Table

transaction(
    id: String,
    role: UInt8,
    networkingAddress: String,
    networkingKey: String,
    stakingKey: String,
    amount: UFix64
) {

    let flowTokenRef: auth(FungibleToken.Withdrawable) &FlowToken.Vault

    prepare(acct: AuthAccount) {

        self.flowTokenRef = acct.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let nodeStaker <- FlowIDTableStaking.addNodeRecord(
            id: id,
            role: role,
            networkingAddress: networkingAddress,
            networkingKey: networkingKey,
            stakingKey: stakingKey,
            tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount)
        )

        if acct.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {

            acct.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)

            acct.link<&{FlowIDTableStaking.NodeStakerPublic}>(
                FlowIDTableStaking.NodeStakerPublicPath,
                target: FlowIDTableStaking.NodeStakerStoragePath
            )
        } else {
            destroy nodeStaker
        }
    }
}