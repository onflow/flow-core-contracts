import Crypto

transaction(key: String, signatureAlgorithm: UInt8, hashAlgorithm: UInt8) {
	prepare(signer: auth(BorrowValue, Storage) &Account) {
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
		}

		let publicKey = PublicKey(
			publicKey: key.decodeHex(),
			signatureAlgorithm: SignatureAlgorithm(rawValue: signatureAlgorithm)!
		)

		let account = Account(payer: signer)

		account.keys.add(publicKey: publicKey, hashAlgorithm: HashAlgorithm(rawValue: hashAlgorithm)!, weight: 1000.0)
	}
}