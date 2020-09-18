import FungibleToken from 0xee82856bf20e2aa6

transaction {
    let account: AuthAccount
    prepare(account: AuthAccount) {
        self.account = account
        self.account.link<&Capability>(/public/vaultCapability, target: /storage/emptyVault)
    }
    post {
        self.account
            .getCapability(/public/vaultCapability)!
            .check<&Capability>() : "Capability link wasn't created"    
    }
}