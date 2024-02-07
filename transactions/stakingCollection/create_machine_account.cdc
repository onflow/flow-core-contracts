import Crypto
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Creates a machine account for a node that is already in the staking collection
/// and adds public keys to the new account

transaction(nodeID: String, publicKeys: [Crypto.KeyListEntry]) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow a reference to a StakingCollection in the primary user's account")

        if let machineAccount = self.stakingCollectionRef.createMachineAccountForExistingNode(nodeID: nodeID, payer: account) {
            if publicKeys == nil || publicKeys!.length == 0 {
                panic("Cannot provide zero keys for the machine account")
            }
            for key in publicKeys {
                machineAccount.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
            }
        } else {
            panic("Could not create a machine account for the node")
        }
    }
}
