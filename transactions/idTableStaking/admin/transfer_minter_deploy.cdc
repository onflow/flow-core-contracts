import FlowToken from 0xFLOWTOKENADDRESS

transaction(publicKeys: [[UInt8]], contractName: String, code: [UInt8], rewardAmount: UFix64, rewardCut: UFix64) {

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

    acct.contracts.add(name: contractName, code: code, rewardAmount, rewardCut)
  }

}
 
