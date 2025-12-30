import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "EVM"
import "RetrieveFraudulentTokensEvents"

/// Argument maps account addresses to a map of token type identifiers to amounts
/// If the account address is a Cadence Address, the tokens are withdrawn from the COA at that account's COA Path.
/// All tokens are deposited into the service account's vault for that token type
/// Flow Tokens are deposited to a non-standard storage path at /storage/fraudulentFlowTokenVault
/// so they do not get mixed up with the legitimate Flow Tokens
/// and can be easily identified and destroyed later

transaction(accounts: {String: {String: UFix64}}) {

    // Add any accounts needed to these parameters
    prepare(serviceAccount: auth(Storage, Capabilities, BorrowValue) &Account, acct1: auth(BorrowValue, Storage) &Account, acct2: auth(BorrowValue, Storage) &Account) {

        // add the same account names in prepare() to this list
        let acctsToRetrieveFrom = [acct1, acct2]

        // Get a reference to resource to emit events for retrieving tokens
        let eventAdmin = serviceAccount.storage.borrow<&RetrieveFraudulentTokensEvents.Admin>(from: RetrieveFraudulentTokensEvents.adminStoragePath)
            ?? panic("The service account does not store a RetrieveFraudulentTokensEvents.Admin object at the path \(RetrieveFraudulentTokensEvents.adminStoragePath)")

        // Get a reference to the array of COAs to be destroyed. COAs will be added to this array in this transaction and destroyed later
        var coaArrayRef = serviceAccount.storage.borrow<auth(Mutate) &[EVM.CadenceOwnedAccount]>(from: /storage/coaArrayToDestroy)
                        ?? panic("The service account does not store a @[EVM.CadenceOwnedAccount] object at the path "
                                .concat("/storage/coaArrayToDestroy"))

        // Get a reference to the service account's COA
        let serviceAccountCOA = serviceAccount.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("The service account does not store a CadenceOwnedAccount object at the path /storage/evm")

        for accountToRetrieveFrom in acctsToRetrieveFrom {
            if accounts[accountToRetrieveFrom.address.toString()] == nil {
                panic("The account \(accountToRetrieveFrom.address.toString()) is not in the accounts map")
            }

            for ftTypeIdentifier in accounts[accountToRetrieveFrom.address.toString()]!.keys {

                let coa <- accountToRetrieveFrom.storage.load<@EVM.CadenceOwnedAccount>(from: /storage/evm)
                    ?? panic("The account \(accountToRetrieveFrom.address.toString()) does not have a COA to retrieve")

                let coaAddress = coa.address().toString()

                coaArrayRef.append(<-coa)
                
                let amount = accounts[accountToRetrieveFrom.address]![ftTypeIdentifier]!

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
    }
}
