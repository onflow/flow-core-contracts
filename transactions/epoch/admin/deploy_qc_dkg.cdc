// Deploys two contracts to an account in one transaction
 
transaction(qcName: String, qcCode: [UInt8], dkgName: String, dkgCode: [UInt8]) {

  prepare(signer: auth(AddContract) &Account) {

    signer.contracts.add(name: qcName, code: qcCode)

    signer.contracts.add(name: dkgName, code: dkgCode)
  }

}
 
