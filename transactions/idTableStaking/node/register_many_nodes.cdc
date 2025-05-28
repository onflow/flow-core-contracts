import "FlowIDTableStaking"
import "FlowToken"
import "FungibleToken"

transaction(
    ids: [String],
    roles: [UInt8],
    networkingAddresses: [String],
    networkingKeys: [String],
    stakingKeys: [String],
    stakingKeyPoPs: [String],
    amounts: [UFix64],
    paths: [StoragePath]
) {

    prepare(acct: auth(Storage) &Account) {

        var i = 0

        for path in paths {

            let flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to FLOW Vault")

            let tokensCommitted <- flowTokenRef.withdraw(amount: amounts[i])

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: ids[i],
                role: roles[i],
                networkingAddress: networkingAddresses[i],
                networkingKey: networkingKeys[i],
                stakingKey: stakingKeys[i],
                stakingKeyPoP: stakingKeyPoPs[i],
                tokensCommitted: <-tokensCommitted
            )

            // Store the node object
            acct.storage.save(<-nodeStaker, to: path)

            i = i + 1
        }
    }

}