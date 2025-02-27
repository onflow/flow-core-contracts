import "FungibleToken"
import "FlowToken"

import "LockedTokens"

transaction(to: Address, amount: UFix64) {

    // The Vault resource that holds the tokens that are being transferred
    let sentVault: @{FungibleToken.Vault}

    prepare(admin: auth(BorrowValue) &Account) {

        // Get a reference to the admin's stored vault
        let vaultRef = admin.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        let adminRef = admin.storage
            .borrow<&LockedTokens.TokenAdminCollection>(
                from: LockedTokens.LockedTokenAdminCollectionStoragePath
            )
            ?? panic("Could not borrow a reference to the locked token admin collection")

        assert(
            adminRef.getAccount(address: to) != nil,
            message: "The specified account is not a locked account! Cannot send locked tokens"
        )

        // Withdraw tokens from the admin's stored vault
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {

        // Get the recipient's public account object
        let recipient = getAccount(to)

        // Get a reference to the recipient's Receiver
        let receiverRef = recipient
            .capabilities.borrow<&{FungibleToken.Receiver}>(
                /public/lockedFlowTokenReceiver
            )
			?? panic("Could not borrow receiver reference to the recipient's locked Vault")

        // Deposit the withdrawn tokens in the recipient's receiver
        receiverRef.deposit(from: <-self.sentVault)
    }
}
