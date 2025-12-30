import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"

transaction(ftTypeIdentifier: String, amount: UFix64) {

    prepare(serviceAccount: auth(Storage, Capabilities, BorrowValue) &Account, accountToRetrieveFrom: auth(BorrowValue) &Account) {

        // Get the path and type data for the provided token type identifier
        let vaultData = MetadataViews.resolveContractViewFromTypeIdentifier(
            resourceTypeIdentifier: ftTypeIdentifier,
            viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
        ) as? FungibleTokenMetadataViews.FTVaultData
            ?? panic("Could not construct valid FT type and view from identifier \(ftTypeIdentifier)")

        // Check if the service account has a vault for this token type at the correct storage path
        if serviceAccount.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: vaultData.storagePath) == nil {
            // Create a new vault of this type for the service account and save it in storage
            let emptyVault <-vaultData.createEmptyVault()
            serviceAccount.storage.save(<-emptyVault, to: vaultData.storagePath)

            // Create a public capability for the vault for metadata
            let vaultCap = serviceAccount.capabilities.storage.issue<&{FungibleToken.Vault}>(vaultData.storagePath)
            serviceAccount.capabilities.publish(vaultCap, at: vaultData.metadataPath)

            // Create a public capability for the vault for deposits
            let receiverCap = serviceAccount.capabilities.storage.issue<&{FungibleToken.Vault}>(vaultData.storagePath)
            serviceAccount.capabilities.publish(receiverCap, at: vaultData.receiverPath)
        }

        // Get a reference to the service account's stored vault
        let serviceAccountVaultRef = serviceAccount.storage.borrow<&{FungibleToken.Vault}>(from: vaultData.storagePath)
			?? panic("The serviceAccount does not store a FungibleToken.Vault object at the path "
                .concat(" \(vaultData.storagePath.toString())."))

        // Get a reference to the other account's stored vault
        let otherAccountVaultRef = accountToRetrieveFrom.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(from: vaultData.storagePath)
			?? panic("The account to retrieve from does not store a FungibleToken.Vault object at the path "
                .concat(" \(vaultData.storagePath.toString())."))

        // Withdraw tokens from the other account's vault
        let vault <- otherAccountVaultRef.withdraw(amount: amount)

        // Deposit the tokens into the service account's vault
        serviceAccountVaultRef.deposit(from: <-vault)

    }
}
