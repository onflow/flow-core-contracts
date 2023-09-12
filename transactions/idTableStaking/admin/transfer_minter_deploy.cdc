import Crypto
import FlowToken from "FlowToken"

transaction(publicKeys: [Crypto.KeyListEntry], contractName: String, code: [UInt8], rewardAmount: UFix64, rewardCut: UFix64, candidateNodeLimits: [UInt64]) {

  prepare(signer: auth(AddKey, SaveValue, BorrowValue) &Account) {

    let acct = Account(payer: signer)
    
    for key in publicKeys {
        acct.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
    }

    /// Borrow a reference to the Flow Token Admin in the account storage
    let flowTokenAdmin = signer.storage.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
        ?? panic("Could not borrow a reference to the Flow Token Admin resource")

    /// Create a flowTokenMinterResource
    let flowTokenMinter <- flowTokenAdmin.createNewMinter(allowedAmount: 1000000000.0)

    acct.storage.save(<-flowTokenMinter, to: /storage/flowTokenMinter)

    assert(candidateNodeLimits.length == 5,
           message: "Candidate Node Limit list but have a length of 5")

    let candidateNodeLimitsDict: {UInt8: UInt64} = {}
    var role: UInt8 = 1

    for limit in candidateNodeLimits {
      candidateNodeLimitsDict[role] = limit
      role = role + 1
    }

    acct.contracts.add(name: contractName, code: code, rewardAmount, rewardCut, candidateNodeLimitsDict)
  }

}
 
