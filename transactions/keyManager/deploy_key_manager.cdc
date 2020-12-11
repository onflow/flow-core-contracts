transaction(code: String, path: Path) {
  prepare(tokenHolder: AuthAccount, admin: AuthAccount, serviceAccount: AuthAccount) {
    tokenHolder.contracts.add(name: "TokenHolderKeyManager", code: code.decodeHex(), admin, path)
  }
}
