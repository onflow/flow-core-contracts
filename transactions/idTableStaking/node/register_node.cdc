import "FlowIDTableStaking"
import "FlowToken"
import "FungibleToken"

// This transaction creates a new node struct object
// and updates the proposed Identity Table

transaction(
    id: String,
    role: UInt8,
    networkingAddress: String,
    networkingKey: String,
    stakingKey: String,
    stakingKeyPoP: String,
    amount: UFix64
) {

    let flowTokenRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(acct: auth(Storage, Capabilities) &Account) {

        self.flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let nodeStaker <- FlowIDTableStaking.addNodeRecord(
            id: id,
            role: role,
            networkingAddress: networkingAddress,
            networkingKey: networkingKey,
            stakingKey: stakingKey,
            stakingKeyPoP: stakingKeyPoP,
            tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount)
        )

        if acct.storage.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {

            acct.storage.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)

            let nodeStakerCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeStakerPublic}>(
                FlowIDTableStaking.NodeStakerStoragePath
            )

            acct.capabilities.publish(
                nodeStakerCap,
                at: FlowIDTableStaking.NodeStakerPublicPath
            )
        } else {
            destroy nodeStaker
        }
    }
}