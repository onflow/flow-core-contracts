import Crypto
import FlowStakingCollection from "FlowStakingCollection"

/// Registers a delegator in the staking collection resource
/// for the specified node information and the amount of tokens to commit

transaction(id: String,
            role: UInt8,
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            amount: UFix64,
            machineAccountKey: String, 
            machineAccountKeySignatureAlgorithm: UInt8, 
            machineAccountKeyHashAlgorithm: UInt8) {

    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("The signer does not store a Staking Collection object at the path "
                    .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                    .concat(". The signer must initialize their account with this object first in order to register!"))

        if let machineAccount = self.stakingCollectionRef.registerNode(
            id: id,
            role: role,
            networkingAddress: networkingAddress,
            networkingKey: networkingKey,
            stakingKey: stakingKey,
            amount: amount,
            payer: account
        ) {
            let sigAlgo = SignatureAlgorithm(rawValue: machineAccountKeySignatureAlgorithm)
                ?? panic("Cannot register node with provided machine account key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeySignatureAlgorithm.toString())
                .concat(" but the options are either 1 (ECDSA_P256), 2 (ECDSA_secp256k1), or 3 (BLS_BLS12_381)."))

            let hashAlgo = HashAlgorithm(rawValue: machineAccountKeyHashAlgorithm)
                ?? panic("Cannot register node with the provided machine account key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided ").concat(machineAccountKeyHashAlgorithm.toString())
                .concat(" but the options are 1 (SHA2_256), 2 (SHA2_384), 3 (SHA3_256), ")
                .concat("4 (SHA3_384), 5 (KMAC128_BLS_BLS12_381), or 6 (KECCAK_256)."))
            
            let publicKey = PublicKey(
			    publicKey: machineAccountKey.decodeHex(),
			    signatureAlgorithm: sigAlgo
		    )
            machineAccount.keys.add(publicKey: publicKey, hashAlgorithm: hashAlgo, weight: 1000.0)
        }
    }
}
