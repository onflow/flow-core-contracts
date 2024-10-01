transaction(keyIndex: Int) {
	prepare(signer: auth(RevokeKey) &Account) {
		if let key = signer.keys.get(keyIndex: keyIndex) {
			signer.keys.revoke(keyIndex: keyIndex)
		} else {
			panic("Cannot revoke key: No key with the index "
                .concat(keyIndex.toString())
                .concat(" exists on the authorizer's account."))
		}
	}
}