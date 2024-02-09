transaction(keyIndex: Int) {
	prepare(signer: AuthAccount) {
		signer.keys.revoke(keyIndex: keyIndex)
	}
}