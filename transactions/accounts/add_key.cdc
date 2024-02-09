import Crypto

transaction(key: Crypto.KeyListEntry) {
	prepare(signer: AuthAccount) {
		signer.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
	}
}