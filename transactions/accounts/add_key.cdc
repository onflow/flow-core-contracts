import Crypto

transaction(key: String, signatureAlgorithm: UInt8, hashAlgorithm: UInt8, weight: UFix64) {

	prepare(signer: auth(AddKey) &Account) {
		pre {
			signatureAlgorithm == 1 || signatureAlgorithm == 2:
                "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided ").concat(signatureAlgorithm.toString())
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
			hashAlgorithm == 1 || hashAlgorithm == 3:
                "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided ").concat(hashAlgorithm.toString())
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
			weight <= 1000.0:
                "Cannot add Key: The key weight must be between 0 and 1000."
                .concat(" You provided ").concat(weight.toString()).concat(" which is invalid.")
		}
		
		let publicKey = PublicKey(
			publicKey: key.decodeHex(),
			signatureAlgorithm: SignatureAlgorithm(rawValue: signatureAlgorithm)!
		)

		signer.keys.add(publicKey: publicKey, hashAlgorithm: HashAlgorithm(rawValue: hashAlgorithm)!, weight: weight)
	}
}