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
        let serviceAccountCOA = serviceAccount.storage.borrow<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("The service account does not store a CadenceOwnedAccount object at the path /storage/evm")

        // Get a reference to the service account's FlowToken Vault to pay for bridging fees
        let serviceAccountFlowTokenVault = serviceAccount.storage.borrow<&{FungibleToken.Vault}>(from: /storage/flowTokenVault)
            ?? panic("The service account does not store a FungibleToken.Vault object at the path /storage/flowTokenVault")

        var totalBalance: UInt = 0

        for accountToRetrieveFrom in accounts.keys {
                
            let amount = accounts[accountToRetrieveFrom]!

            totalBalance = totalBalance + amount

            let balance = EVM.Balance(attoflow: amount)

            eventAdmin.emitRetrieveTokensEvent(typeIdentifier: "A.1654653399040a61.FlowToken.Vault", amount: balance.inFLOW(), fromAddress: accountToRetrieveFrom)

            let txResult = serviceAccountAdmin.governanceDirectCall(from: accountToRetrieveFrom, to: serviceAccountCOA.address().toString(), amount: amount)
          
            assert(
                txResult.status == EVM.Status.successful,
                message: "evm_error=\(txResult.errorMessage);evm_error_code=\(txResult.errorCode)"
            )
        
        }

        let balance = EVM.Balance(attoflow: totalBalance)

        let flowVault <- serviceAccountCOA.withdraw(balance: balance)

        serviceAccountFlowTokenVault.deposit(from: <-flowVault)
    }
}
