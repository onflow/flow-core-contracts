transaction(code: String, publicKeys: [[UInt8]]) {
  prepare(admin: AuthAccount) {
    let lockedTokens = AuthAccount(payer: admin)
    lockedTokens.setCode(code.decodeHex(), admin)

    for key in publicKeys {
      lockedTokens.addPublicKey(key)
    }
  }
}
