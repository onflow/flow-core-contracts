import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

transaction(
    ids: [String],
    roles: [UInt8],
    networkingAddresses: [String],
    networkingKeys: [String],
    stakingKeys: [String],
    amounts: [UFix64],
    paths: [StoragePath]
) {

    prepare(acct: AuthAccount) {

        var i = 0

        for path in paths {

            let flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to FLOW Vault")

            let tokensCommitted <- flowTokenRef.withdraw(amount: amounts[i])

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: ids[i],
                role: roles[i],
                networkingAddress: networkingAddresses[i],
                networkingKey: networkingKeys[i],
                stakingKey: stakingKeys[i],
                tokensCommitted: <-tokensCommitted
            )

            // Store the node object
            acct.save(<-nodeStaker, to: path)

            i = i + 1
        }
    }

}