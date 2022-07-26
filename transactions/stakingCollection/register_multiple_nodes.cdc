import Crypto
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Registers multiple nodes in the staking collection resource
/// for the specified node information

transaction(ids: [String],
            roles: [UInt8],
            networkingAddresses: [String],
            networkingKeys: [String],
            stakingKeys: [String],
            stakingKeyPoPs: [String],
            amounts: [UFix64],
            publicKeys: [[Crypto.KeyListEntry]?]) {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")

        var i = 0

        for id in ids {
            if let machineAccount = self.stakingCollectionRef.registerNode(
                id: id,
                role: roles[i],
                networkingAddress: networkingAddresses[i],
                networkingKey: networkingKeys[i],
                stakingKey: stakingKeys[i],
                stakingKeyPoP: stakingKeyPoPs[i],
                amount: amounts[i],
                payer: account) 
            {
                if publicKeys[i] == nil || publicKeys[i]!.length == 0 {
                    panic("Cannot provide zero keys for the machine account")
                }
                for key in publicKeys[i]! {
                    machineAccount.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
                }
            }
            i = i + 1
        }
    }
}
