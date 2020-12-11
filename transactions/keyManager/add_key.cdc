import KeyManager from 0xKEYMANAGERADDRESS

// This transaction adds a public key to a token holder account
// using a KeyAdder resource.
//
// Each token holder provides a single KeyAdder resource to the administrator
// stored at a unique path in the administrator account.
transaction(address: Address, publicKey: String, path: Path) {

  let keyAdder: &AnyResource{KeyManager.KeyAdder}

  prepare(admin: AuthAccount) {
    self.keyAdder = admin.borrow<&AnyResource{KeyManager.KeyAdder}>(from: path)!
  }

  pre {
    self.keyAdder.address == address : "Incorrect account address"
  }

  execute {
    self.keyAdder.addPublicKey(publicKey.decodeHex())
  }
}
