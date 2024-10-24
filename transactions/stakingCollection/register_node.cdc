import Crypto
import FlowStakingCollection from "FlowStakingCollection"

/// Registers a delegator in the staking collection resource
/// for the specified node information and the amount of tokens to commit

transaction(id: String,
            role: UInt8,
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            stakingKeyPoP: String,
            amount: UFix64,
            machineAccountKey: String, 
            machineAccountKeySignatureAlgorithm: UInt8, 
            machineAccountKeyHashAlgorithm: UInt8) {

    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        pre {
			machineAccountKeySignatureAlgorithm == 1 || machineAccountKeySignatureAlgorithm == 2:
                "Cannot register node with provided machine account key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeySignatureAlgorithm.toString())
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
			machineAccountKeyHashAlgorithm == 1 || machineAccountKeyHashAlgorithm == 3:
                "Cannot register node with provided machine account key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeyHashAlgorithm.toString())
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
		}

        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic(FlowStakingCollection.getCollectionMissingError(nil))

        if let machineAccount = self.stakingCollectionRef.registerNode(
            id: id,
            role: role,
            networkingAddress: networkingAddress,
            networkingKey: networkingKey,
            stakingKey: stakingKey,
            stakingKeyPoP: stakingKeyPoP,
            amount: amount,
            payer: account
        ) {
            let sigAlgo = SignatureAlgorithm(rawValue: machineAccountKeySignatureAlgorithm)!

            let hashAlgo = HashAlgorithm(rawValue: machineAccountKeyHashAlgorithm)!
            
            let publicKey = PublicKey(
			    publicKey: machineAccountKey.decodeHex(),
			    signatureAlgorithm: sigAlgo
		    )
            machineAccount.keys.add(publicKey: publicKey, hashAlgorithm: hashAlgo, weight: 1000.0)
        }
    }
}
