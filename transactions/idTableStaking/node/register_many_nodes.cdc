import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

transaction(ids: [String], 
            roles: [UInt8], 
            networkingAddresses: [String], 
            networkingKeys: [String], 
            stakingKeys: [String], 
            amounts: [UFix64], 
            paths: [Path]) {

    prepare(acct: AuthAccount) {

        var i = 0

        for path in paths {

            let flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to FLOW Vault")

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: ids[i], 
                                    role: roles[i], 
                                    networkingAddress: networkingAddresses[i], 
                                    networkingKey: networkingKeys[i], 
                                    stakingKey: stakingKeys[i], 
                                    tokensCommitted: <-flowTokenRef.withdraw(amount: amounts[i]))

            // Store the node object
            acct.save(<-nodeStaker, to: path)

            i = i + 1
        }
    }

}