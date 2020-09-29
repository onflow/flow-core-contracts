transaction(publicKeys: [[UInt8]], code: [UInt8]) {

  prepare(signer: AuthAccount, admin: AuthAccount) {

	let acct = AuthAccount(payer: signer)
    
	for key in publicKeys {
		acct.addPublicKey(key)
	}

	acct.setCode(code, admin)
  }

}
 