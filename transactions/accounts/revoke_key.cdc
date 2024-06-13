transaction(keyIndex: Int) {
	prepare(signer: auth(RevokeKey) &Account) {
		if let key = signer.keys.get(keyIndex: keyIndex) {
			signer.keys.revoke(keyIndex: keyIndex)
		} else {
			panic("No key with the given index exists on the authorizer's account")
		}
	}
}