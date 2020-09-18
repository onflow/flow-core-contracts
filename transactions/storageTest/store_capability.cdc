import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

transaction {
    prepare(node: AuthAccount) {
        log(node.address)
        // Create new account
        let newAccount = AuthAccount(payer: node)
        // Create empty vault
        let emptyVault <- FlowToken.createEmptyVault()
        // Save empty vault into new account storage     
        newAccount.save<@FungibleToken.Vault>(<- emptyVault, to: /storage/emptyVault)
        // Create link to storage object
        newAccount.link<&FungibleToken.Vault>(/private/VaultRef, target: /storage/emptyVault)    
        let capability = newAccount.getCapability(/private/VaultRef)
        // Clear storage, so we can reuse this transaction
        node.load<Capability>(from: /storage/emptyVault)
        // Save Capability to storage
        node.save(capability!, to: /storage/emptyVault)
        // Now we can access it from here or another transaction
        let vaultRef = node
            .copy<Capability>(from:/storage/emptyVault)!
            .borrow<&FungibleToken.Vault>()!
        log("Vault Balance:".concat(vaultRef.balance.toString()))
    }
}