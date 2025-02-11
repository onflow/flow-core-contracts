import Crypto
import "FlowStakingCollection"

/// Creates a machine account for a node that is already in the staking collection
/// and adds public keys to the new account

transaction(nodeID: String, 
            machineAccountKey: String, 
            machineAccountKeySignatureAlgorithm: UInt8, 
            machineAccountKeyHashAlgorithm: UInt8) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        pre {
			machineAccountKeySignatureAlgorithm == 1 || machineAccountKeySignatureAlgorithm == 2:
                "Cannot create machine account: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeySignatureAlgorithm.toString())
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
			machineAccountKeyHashAlgorithm == 1 || machineAccountKeyHashAlgorithm == 3:
                "Cannot create machine account: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeyHashAlgorithm.toString())
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
		}

        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic(FlowStakingCollection.getCollectionMissingError(nil))

        if let machineAccount = self.stakingCollectionRef.createMachineAccountForExistingNode(nodeID: nodeID, payer: account) {
            let sigAlgo = SignatureAlgorithm(rawValue: machineAccountKeySignatureAlgorithm)!

            let hashAlgo = HashAlgorithm(rawValue: machineAccountKeyHashAlgorithm)!
            
            let publicKey = PublicKey(
			    publicKey: machineAccountKey.decodeHex(),
			    signatureAlgorithm: sigAlgo
		    )
            machineAccount.keys.add(publicKey: publicKey, hashAlgorithm: hashAlgo, weight: 1000.0)
        } else {
            panic("Could not create a machine account for the node")
        }
    }
}
