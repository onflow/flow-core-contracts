import FlowToken from 0x0ae53cb6e3f42a79

transaction(publicKeys: [[UInt8]], code: [UInt8]) {

  prepare(signer: AuthAccount) {

	let acct = AuthAccount(payer: signer)
    
	for key in publicKeys {
		acct.addPublicKey(key)
	}

    /// Borrow a reference to the Flow Token Admin in the account storage
    let flowTokenAdmin = signer.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
        ?? panic("Could not borrow a reference to the Flow Token Admin resource")

    /// Create a flowTokenMinterResource
    let flowTokenMinter <- flowTokenAdmin.createNewMinter(allowedAmount: 1000000000.0)

    acct.save(<-flowTokenMinter, to: /storage/flowTokenMinter)

	acct.setCode(code)
  }

}
 