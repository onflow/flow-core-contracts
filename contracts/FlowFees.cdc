import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowFees {

    // Event that is emitted when tokens are deposited to the fee vault
    pub event TokensDeposited(amount: UFix64)

    // Event that is emitted when transaction fees are deducted
    pub event TransactionFeesDeducted(
                computationEffort: UInt64, 
                inclusionEffort: UInt64,
                transactionFees: UFix64)

    // Event that is emitted when the inclusion fee factor changes
    pub event InclusionFeeFactorChanged(newAmount: UFix64, oldAmount: UFix64)

    // Event that is emitted when the computation fee factor changes
    pub event ComputationFeeFactorChanged(newAmount: UFix64, oldAmount: UFix64)

    // Event that is emitted when tokens are withdrawn from the fee vault
    pub event TokensWithdrawn(amount: UFix64)

    // Private vault with public deposit function
    access(self) var vault: @FlowToken.Vault

    // Inclusion Fee Factor is used to calculate inclusion fee cost from inclusion effort
    pub var inclusionFeeFactor: UFix64

    // Computation Fee Factor is used to calculate computation fee cost from computation effort
    pub var computationFeeFactor: UFix64

    pub fun deposit(from: @FungibleToken.Vault) {
        let from <- from as! @FlowToken.Vault
        let balance = from.balance
        self.vault.deposit(from: <-from)
        emit TokensDeposited(amount: balance)
    }

    // Called when a transaction is submitted to deduct the transaction fees
    // from the AuthAccount that submitted it
    pub fun deductTransactionFees(
        account: AuthAccount, 
        computationEffort: UInt64, 
        inclusionEffort: UInt64, 
        transactionFees: UFix64) {


        let tokenVault = account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")
        let tokenVaultBalance = tokenVault.balance

        var fees = transactionFees
        if tokenVaultBalance < transactionFees {
            // this shouldn't happen, as the transaction will not be included in a collection,
            // but if it does happen we want to handle it gracefully
            fees = tokenVaultBalance
        }

        let feeVault <- tokenVault.withdraw(amount: fees)
        emit TransactionFeesDeducted(
            computationEffort: computationEffort, 
            inclusionEffort: inclusionEffort,
            transactionFees: transactionFees
        )

        self.deposit(from: <-feeVault)
    }

    pub resource Administrator {
        // withdraw
        //
        // Allows the administrator to withdraw tokens from the fee vault
        pub fun withdrawTokensFromFeeVault(amount: UFix64): @FungibleToken.Vault {
            let vault <- FlowFees.vault.withdraw(amount: amount)
            emit TokensWithdrawn(amount: amount)
            return <-vault
        }
        // Set the inclusion fee factor to a new value
        pub fun setInclusionFeeFactor(_ amount: UFix64) {
            if amount == FlowFees.inclusionFeeFactor {
                return
            }
            emit InclusionFeeFactorChanged(newAmount: amount, oldAmount: FlowFees.inclusionFeeFactor)
            FlowFees.inclusionFeeFactor = amount
        }
        // Set the computation fee factor to a new value
        pub fun setComputationFeeFactor(_ amount: UFix64) {
            if amount == FlowFees.computationFeeFactor {
                return
            }
            emit ComputationFeeFactorChanged(newAmount: amount, oldAmount: FlowFees.computationFeeFactor)
            FlowFees.computationFeeFactor = amount
        }
    }

    init(adminAccount: AuthAccount) {
        // Create a new FlowToken Vault and save it in storage
        self.vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/flowFeesAdmin)

        self.inclusionFeeFactor = UFix64(1.0)
        self.computationFeeFactor = UFix64(1.0)
    }
}
