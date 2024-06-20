import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"
import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

access(all) contract FlowFees {

    // Event that is emitted when tokens are deposited to the fee vault
    access(all) event TokensDeposited(amount: UFix64)

    // Event that is emitted when tokens are withdrawn from the fee vault
    access(all) event TokensWithdrawn(amount: UFix64)

    // Event that is emitted when fees are deducted
    access(all) event FeesDeducted(amount: UFix64, inclusionEffort: UFix64, executionEffort: UFix64)

    // Event that is emitted when fee parameters change
    access(all) event FeeParametersChanged(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64)

    // Private vault with public deposit function
    access(self) var vault: @FlowToken.Vault

    access(all) fun deposit(from: @{FungibleToken.Vault}) {
        let from <- from as! @FlowToken.Vault
        let balance = from.balance
        self.vault.deposit(from: <-from)
        emit TokensDeposited(amount: balance)
    }

    /// Get the balance of the Fees Vault
    access(all) fun getFeeBalance(): UFix64 {
        return self.vault.balance
    }

    access(all) resource Administrator {
        // withdraw
        //
        // Allows the administrator to withdraw tokens from the fee vault
        access(all) fun withdrawTokensFromFeeVault(amount: UFix64): @{FungibleToken.Vault} {
            let vault <- FlowFees.vault.withdraw(amount: amount)
            emit TokensWithdrawn(amount: amount)
            return <-vault
        }

        /// Allows the administrator to change all the fee parameters at once
        access(all) fun setFeeParameters(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64) {
            let newParameters = FeeParameters(surgeFactor: surgeFactor, inclusionEffortCost: inclusionEffortCost, executionEffortCost: executionEffortCost)
            FlowFees.setFeeParameters(newParameters)
        }

        /// Allows the administrator to change the fee surge factor
        access(all) fun setFeeSurgeFactor(_ surgeFactor: UFix64) {
            let oldParameters = FlowFees.getFeeParameters()
            let newParameters = FeeParameters(surgeFactor: surgeFactor, inclusionEffortCost: oldParameters.inclusionEffortCost, executionEffortCost: oldParameters.executionEffortCost)
            FlowFees.setFeeParameters(newParameters)
        }
    }

    /// A struct holding the fee parameters needed to calculate the fees
    access(all) struct FeeParameters {
        /// The surge factor is used to make transaction fees respond to high loads on the network
        access(all) var surgeFactor: UFix64
        /// The FLOW cost of one unit of inclusion effort. The FVM is responsible for metering inclusion effort.
        access(all) var inclusionEffortCost: UFix64
        /// The FLOW cost of one unit of execution effort. The FVM is responsible for metering execution effort.
        access(all) var executionEffortCost: UFix64

        init(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64){
            self.surgeFactor = surgeFactor
            self.inclusionEffortCost = inclusionEffortCost
            self.executionEffortCost = executionEffortCost
        }
    }

    // VerifyPayerBalanceResult is returned by the verifyPayersBalanceForTransactionExecution function
    access(all) struct VerifyPayerBalanceResult {
        // True if the payer has sufficient balance for the transaction execution to continue
        access(all) let canExecuteTransaction: Bool
        // The minimum payer balance required for the transaction execution to continue.
        // This value is defined by verifyPayersBalanceForTransactionExecution.
        access(all) let requiredBalance: UFix64
        // The maximum transaction fees (inclusion fees + execution fees) the transaction can incur
        // (if all available execution effort is used)
        access(all) let maximumTransactionFees: UFix64

        init(canExecuteTransaction: Bool, requiredBalance: UFix64,  maximumTransactionFees: UFix64){
            self.canExecuteTransaction = canExecuteTransaction
            self.requiredBalance = requiredBalance
            self.maximumTransactionFees = maximumTransactionFees
        }

    }

    // verifyPayersBalanceForTransactionExecution is called by the FVM before executing a transaction.
    // It verifies that the transaction payer's balance is high enough to continue transaction execution,
    // and returns the maximum possible transaction fees.
    // (according to the inclusion effort and maximum execution effort of the transaction).
    //
    // The requiredBalance balance is defined as the minimum account balance +
    //  maximum transaction fees (inclusion fees + execution fees at max execution effort).
    access(all) fun verifyPayersBalanceForTransactionExecution(
        _ payerAcct: auth(BorrowValue) &Account,
        inclusionEffort: UFix64,
        maxExecutionEffort: UFix64
    ): VerifyPayerBalanceResult {
        // Get the maximum fees required for the transaction.
        var maxTransactionFee = self.computeFees(inclusionEffort: inclusionEffort, executionEffort: maxExecutionEffort)

        // Get the minimum required payer's balance for the transaction.
        let minimumRequiredBalance = FlowStorageFees.defaultTokenReservedBalance(payerAcct.address)

        if minimumRequiredBalance == UFix64(0) {
            // If the required balance is zero exit early.
            return VerifyPayerBalanceResult(
                canExecuteTransaction: true,
                requiredBalance: minimumRequiredBalance,
                maximumTransactionFees: maxTransactionFee
            )
        }

        // Get the balance of the payers default vault.
        // In the edge case where the payer doesnt have a vault, treat the balance as 0.
        var balance = 0.0
        if let tokenVault = payerAcct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) {
            balance = tokenVault.balance
        }

        return VerifyPayerBalanceResult(
            // The transaction can be executed it the payers balance is greater than the minimum required balance.
            canExecuteTransaction: balance >= minimumRequiredBalance,
            requiredBalance: minimumRequiredBalance,
            maximumTransactionFees: maxTransactionFee)
    }

    /// Called when a transaction is submitted to deduct the fee
    /// from the AuthAccount that submitted it
    access(all) fun deductTransactionFee(_ acct: auth(BorrowValue) &Account, inclusionEffort: UFix64, executionEffort: UFix64) {
        var feeAmount = self.computeFees(inclusionEffort: inclusionEffort, executionEffort: executionEffort)

        if feeAmount == UFix64(0) {
            // If there are no fees to deduct, do not continue,
            // so that there are no unnecessarily emitted events
            return
        }

        let tokenVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")


        if feeAmount > tokenVault.balance {
            // In the future this code path will never be reached,
            // as payers that are under account minimum balance will not have their transactions included in a collection
            //
            // Currently this is not used to fail the transaction (as that is the responsibility of the minimum account balance logic),
            // But is used to reduce the balance of the vault to 0.0, if the vault has less available balance than the transaction fees.
            feeAmount = tokenVault.balance
        }

        let feeVault <- tokenVault.withdraw(amount: feeAmount)
        self.vault.deposit(from: <-feeVault)

        // The fee calculation can be reconstructed using the data from this event and the FeeParameters at the block when the event happened
        emit FeesDeducted(amount: feeAmount, inclusionEffort: inclusionEffort, executionEffort: executionEffort)
    }

    access(all) fun getFeeParameters(): FeeParameters {
        return self.account.storage.copy<FeeParameters>(from: /storage/FlowTxFeeParameters) ?? panic("Error getting tx fee parameters. They need to be initialized first!")
    }

    access(self) fun setFeeParameters(_ feeParameters: FeeParameters) {
        // empty storage before writing new FeeParameters to it
        self.account.storage.load<FeeParameters>(from: /storage/FlowTxFeeParameters)
        self.account.storage.save(feeParameters,to: /storage/FlowTxFeeParameters)
        emit FeeParametersChanged(surgeFactor: feeParameters.surgeFactor, inclusionEffortCost: feeParameters.inclusionEffortCost, executionEffortCost: feeParameters.executionEffortCost)
    }


    // compute the transaction fees with the current fee parameters and the given inclusionEffort and executionEffort
    access(all) fun computeFees(inclusionEffort: UFix64, executionEffort: UFix64): UFix64 {
        let params = self.getFeeParameters()

        let totalFees = params.surgeFactor * ( inclusionEffort * params.inclusionEffortCost + executionEffort * params.executionEffortCost )
        return totalFees
    }

    init() {
        // Create a new FlowToken Vault and save it in storage
        self.vault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault

        let admin <- create Administrator()
        self.account.storage.save(<-admin, to: /storage/flowFeesAdmin)
    }
}