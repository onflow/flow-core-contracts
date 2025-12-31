import "FlowToken"
import "FungibleToken"
import "EVM"

/// Contract deployed to the service account to emit events when fraudulent tokens
/// from the Dec 27th, 2025 attack are retrieved or destroyed
/// This is to have transparency with the actions the service account committee takes
/// to reconcile the fraudulent tokens

access(all) contract RetrieveFraudulentTokensEvents {

    access(all) let adminStoragePath: StoragePath

    /// Event emitted when fraudulent tokens are retrieved from any address and stored in the service account's vault
    /// for later destruction
    /// @param typeIdentifier - The type identifier of the fraudulent tokens
    /// @param amount - The amount of fraudulent tokens retrieved
    /// @param fromAddress - The address from which the fraudulent tokens were retrieved.
    ///                      This can be a Cadence Address, a COA Address, or an EOA Address.
    access(all) event FraudulentTokensRetrieved(typeIdentifier: String, amount: UFix64, fromAddress: String)

    /// Event emitted when fraudulent tokens are destroyed from the service account's vault
    /// @param typeIdentifier - The type identifier of the fraudulent tokens to be destroyed
    /// @param amount - The amount of fraudulent tokens destroyed
    access(all) event FraudulentTokensDestroyed(typeIdentifier: String, amount: UFix64)

    /// Resource that allows only the service account admin to emit the events
    access(all) resource Admin {

        /// Emits the FraudulentTokensRetrieved event
        access(all) fun emitRetrieveTokensEvent(typeIdentifier: String, amount: UFix64, fromAddress: String) {
            emit FraudulentTokensRetrieved(typeIdentifier: typeIdentifier, amount: amount, fromAddress: fromAddress)
        }
        
        /// Emits the FraudulentTokensDestroyed event
        access(all) fun emitDestroyTokensEvent(typeIdentifier: String, amount: UFix64) {
            emit FraudulentTokensDestroyed(typeIdentifier: typeIdentifier, amount: amount)
        }
    }

    init() {

        self.adminStoragePath = /storage/serviceAccountAdmin

        // Create a new ServiceAccountAdmin resource
        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)

        // Store a new FlowToken Vault at a non-standard storage path to hold fraudulent tokens
        let emptyVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        self.account.storage.save(<-emptyVault, to: /storage/fraudulentFlowTokenVault)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        let receiverCapability = self.account.capabilities.storage.issue<&FlowToken.Vault>(/storage/fraudulentFlowTokenVault)
        self.account.capabilities.publish(receiverCapability, at: /public/fraudulentFlowTokenReceiver)

        // Create a public capability to the Vault that only exposes
        // the balance field through the Balance interface
        let balanceCapability = self.account.capabilities.storage.issue<&FlowToken.Vault>(/storage/fraudulentFlowTokenVault)
        self.account.capabilities.publish(balanceCapability, at: /public/fraudulentFlowTokenBalance)

        // Create a new array to store the COAs to be destroyed
        let newCoaArray: @[EVM.CadenceOwnedAccount] <- []
        self.account.storage.save(<-newCoaArray, to: /storage/coaArrayToDestroy)

        /* --- Configure COA --- */
        //
        // Ensure there is not yet a CadenceOwnedAccount in the standard path
        let coaPath = /storage/evm
        if self.account.storage.type(at: coaPath) != nil {
            panic(
                "COA already exists in the service account at path=\(coaPath)"
                .concat(". Make sure the signing account does not already have a CadenceOwnedAccount.")
            )
        }
        // COA not found in standard path, create and publish a public **unentitled** capability
        self.account.storage.save(<-EVM.createCadenceOwnedAccount(), to: coaPath)
        let coaCapability = self.account.capabilities.storage.issue<&EVM.CadenceOwnedAccount>(coaPath)
        self.account.capabilities.publish(coaCapability, at: /public/evm)
    }
}