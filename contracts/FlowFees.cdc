import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowFees {

    // Event that is emitted when tokens are deposited to the fee vault
    pub event TokensDeposited(amount: UFix64)

    // Event that is emitted when tokens are withdrawn from the fee vault
    pub event TokensWithdrawn(amount: UFix64)

    // Event that is emitted when fees are deducted
    pub event FeesDeducted(amount: UFix64, inclusionEffort: UFix64, executionEffort: UFix64)

    // Private vault with public deposit function
    access(self) var vault: @FlowToken.Vault

    pub fun deposit(from: @FungibleToken.Vault) {
        let from <- from as! @FlowToken.Vault
        let balance = from.balance
        self.vault.deposit(from: <-from)
        emit TokensDeposited(amount: balance)
    }

    /// Get the balance of the Fees Vault
    pub fun getFeeBalance(): UFix64 {
        return self.vault.balance
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

        pub fun setFeeParameters(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64) {
            let newParameters = FeeParameters(surgeFactor: surgeFactor, inclusionEffortCost: inclusionEffortCost, executionEffortCost: executionEffortCost)
            FlowFees.storeFeeParameters(newParameters)
        }
    }

    pub struct FeeParameters {
        pub var surgeFactor: UFix64
        pub var inclusionEffortCost: UFix64
        pub var executionEffortCost: UFix64

        init(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64){
            self.surgeFactor = surgeFactor
            self.inclusionEffortCost = inclusionEffortCost
            self.executionEffortCost = executionEffortCost
        }
    }

    init(adminAccount: AuthAccount) {
        // Create a new FlowToken Vault and save it in storage
        self.vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/flowFeesAdmin)
    }

    /// Called when a transaction is submitted to deduct the fee
    /// from the AuthAccount that submitted it
    pub fun deductTransactionFee(_ acct: AuthAccount, inclusionEffort: UFix64, executionEffort: UFix64) {
        var feeAmount = self.computeFees(inclusionEffort: inclusionEffort, executionEffort: executionEffort)

        if feeAmount == UFix64(0) {
            return
        }


        let tokenVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")
        if feeAmount > tokenVault.balance {
            feeAmount = tokenVault.balance
        }
        
        let feeVault <- tokenVault.withdraw(amount: feeAmount)
        self.vault.deposit(from: <-feeVault)
        emit FeesDeducted(amount: feeAmount, inclusionEffort: inclusionEffort, executionEffort: executionEffort)
    }

    access(self) fun computeFees(inclusionEffort: UFix64, executionEffort: UFix64): UFix64 {
        let params = self.readFeeParameters()
        
        let totalFees = params.surgeFactor * ( inclusionEffort * params.inclusionEffortCost + executionEffort * params.executionEffortCost )
        return totalFees
    }

    access(self) fun readFeeParameters(): &FeeParameters {
        return self.account.borrow<&FeeParameters>(from: /storage/FeeParameters)!
    }
    
    access(self) fun storeFeeParameters(_ feeParameters: FeeParameters) {
        self.account.load<FeeParameters>(from: /storage/FeeParameters)
        self.account.save(feeParameters,to: /storage/FeeParameters)
    }
}
