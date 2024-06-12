import Crypto

transaction(key: String, signatureAlgorithm: UInt8, hashAlgorithm: UInt8, weight: UFix64) {
	prepare(signer: auth(BorrowValue, Storage) &Account) {
		pre {
			signatureAlgorithm >= 1 && signatureAlgorithm <= 3: "Must provide a signature algorithm raw value that is 1, 2, or 3"
			hashAlgorithm >= 1 && hashAlgorithm <= 6: "Must provide a hash algorithm raw value that is between 1 and 6"
			weight <= 1000.0: "The key weight must be between 0 and 1000"
		}

		let publicKey = PublicKey(
			publicKey: key.decodeHex(),
			signatureAlgorithm: SignatureAlgorithm(rawValue: signatureAlgorithm)!
		)

		let account = Account(payer: signer)

		account.keys.add(publicKey: publicKey, hashAlgorithm: HashAlgorithm(rawValue: hashAlgorithm)!, weight: weight)
	}
}