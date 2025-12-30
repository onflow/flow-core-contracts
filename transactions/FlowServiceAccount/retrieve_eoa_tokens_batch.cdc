import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "EVM"
import "RetrieveFraudulentTokensEvents"
import "FlowServiceAccount"

/// Argument maps EOA addresses to amounts
/// All tokens are transferred from the EOA to the service account's COA

transaction(accounts: {String: UInt}) {

    // Add any accounts needed to these parameters
    prepare(serviceAccount: auth(Storage, Capabilities, BorrowValue) &Account) {

        // Get a reference to resource to emit events for retrieving tokens
        let eventAdmin = serviceAccount.storage.borrow<&RetrieveFraudulentTokensEvents.Admin>(from: RetrieveFraudulentTokensEvents.adminStoragePath)
            ?? panic("The service account does not store a RetrieveFraudulentTokensEvents.Admin object at the path \(RetrieveFraudulentTokensEvents.adminStoragePath)")

        let serviceAccountAdmin = serviceAccount.storage.borrow<&FlowServiceAccount.Administrator>(from: /storage/flowServiceAdmin)
			?? panic("Unable to borrow reference to administrator resource")

        // Get a reference to the service account's COA
        let serviceAccountCOA = serviceAccount.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("The service account does not store a CadenceOwnedAccount object at the path /storage/evm")

        for accountToRetrieveFrom in accounts.keys {
                
            let amount = accounts[accountToRetrieveFrom]!

            let balance = EVM.Balance(attoflow: amount)

            eventAdmin.emitRetrieveTokensEvent(typeIdentifier: "A.1654653399040a61.FlowToken.Vault", amount: balance.inFLOW(), fromAddress: accountToRetrieveFrom)

            serviceAccountAdmin.governanceDirectCall(from: accountToRetrieveFrom, to: serviceAccountCOA.address().toString(), amount: amount)
        }
    }
}
