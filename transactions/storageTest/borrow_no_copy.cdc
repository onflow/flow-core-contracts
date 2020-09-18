import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

transaction {
    prepare(node: AuthAccount) {
        let vaultRef = node
            .borrow<&Capability>(from: /storage/emptyVault)!
            .borrow<&FungibleToken.Vault>()!

        log("Vault Balance:".concat(vaultRef.balance.toString()))
    }
}