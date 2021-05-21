import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowFees from 0xFLOWFEESADDRESS
import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

pub contract FlowServiceAccount {

    pub event TransactionFeeUpdated(newFee: UFix64)

    pub event AccountCreationFeeUpdated(newFee: UFix64)

    pub event AccountCreatorAdded(accountCreator: Address)

    pub event AccountCreatorRemoved(accountCreator: Address)

    /// A fixed-rate fee charged to execute a transaction
    pub var transactionFee: UFix64

    /// A fixed-rate fee charged to create a new account
    pub var accountCreationFee: UFix64

    // The list of account addresses that have permission to create accounts
    pub var accountCreators: {Address: Bool}

    /// Initialize an account with a FlowToken Vault and publish capabilities.
    pub fun initDefaultToken(_ acct: AuthAccount) {
        // Create a new FlowToken Vault and save it in storage
        acct.save(<-FlowToken.createEmptyVault(), to: /storage/flowTokenVault)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        acct.link<&FlowToken.Vault{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: /storage/flowTokenVault
        )

        // Create a public capability to the Vault that only exposes
        // the balance field through the Balance interface
        acct.link<&FlowToken.Vault{FungibleToken.Balance}>(
            /public/flowTokenBalance,
            target: /storage/flowTokenVault
        )
    }

    /// Get the default token balance on an account
    pub fun defaultTokenBalance(_ acct: PublicAccount): UFix64 {
        let balanceRef = acct
            .getCapability(/public/flowTokenBalance)
            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()!

        return balanceRef.balance
    }

    /// Return a reference to the default token vault on an account
    pub fun defaultTokenVault(_ acct: AuthAccount): &FlowToken.Vault {
        return acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")
    }

    /// Called when a transaction is submitted to deduct the fee
    /// from the AuthAccount that submitted it
    pub fun deductTransactionFee(_ acct: AuthAccount) {
        if self.transactionFee == UFix64(0) {
            return
        }

        let tokenVault = self.defaultTokenVault(acct)
        let feeVault <- tokenVault.withdraw(amount: self.transactionFee)

        FlowFees.deposit(from: <-feeVault)
    }

    /// - Deducts the account creation fee from a payer account.
    /// - Inits the default token.
    /// - Inits account storage capacity.
    pub fun setupNewAccount(newAccount: AuthAccount, payer: AuthAccount) {
        if self.accountCreationFee < FlowStorageFees.minimumStorageReservation {
            panic("Account creation fees setup incorrectly")
        }

        let tokenVault = self.defaultTokenVault(payer)
        let feeVault <- tokenVault.withdraw(amount: self.accountCreationFee)
        let storageFeeVault <- (feeVault.withdraw(amount: FlowStorageFees.minimumStorageReservation) as! @FlowToken.Vault)
        FlowFees.deposit(from: <-feeVault)

        FlowServiceAccount.initDefaultToken(newAccount)

        let vaultRef = FlowServiceAccount.defaultTokenVault(newAccount)

        vaultRef.deposit(from: <-storageFeeVault)
    }

    /// Returns true if the given address is permitted to create accounts, false otherwise
    pub fun isAccountCreator(_ address: Address): Bool {
        return self.accountCreators[address] ?? false
    }

    // Authorization resource to change the fields of the contract
    pub resource Administrator {

        /// Sets the transaction fee
        pub fun setTransactionFee(_ newFee: UFix64) {
            FlowServiceAccount.transactionFee = newFee
            emit TransactionFeeUpdated(newFee: newFee)
        }

        /// Sets the account creation fee
        pub fun setAccountCreationFee(_ newFee: UFix64) {
            FlowServiceAccount.accountCreationFee = newFee
            emit AccountCreationFeeUpdated(newFee: newFee)
        }

        /// Adds an account address as an authorized account creator
        pub fun addAccountCreator(_ accountCreator: Address) {
            FlowServiceAccount.accountCreators[accountCreator] = true
            emit AccountCreatorAdded(accountCreator: accountCreator)
        }

        /// Removes an account address as an authorized account creator
        pub fun removeAccountCreator(_ accountCreator: Address) {
            FlowServiceAccount.accountCreators.remove(key: accountCreator)
            emit AccountCreatorRemoved(accountCreator: accountCreator)
        }
    }

    init() {
        self.transactionFee = 0.0
        self.accountCreationFee = 0.0

        self.accountCreators = {}

        let admin <- create Administrator()
        admin.addAccountCreator(self.account.address)

        self.account.save(<-admin, to: /storage/flowServiceAdmin)
    }
}
