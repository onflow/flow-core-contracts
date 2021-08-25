import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowFees {

    // Event that is emitted when tokens are deposited to the fee vault
    pub event TokensDeposited(amount: UFix64)

    // Event that is emitted when tokens are withdrawn from the fee vault
    pub event TokensWithdrawn(amount: UFix64)

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
    }

    init(adminAccount: AuthAccount) {
        // Create a new FlowToken Vault and save it in storage
        self.vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/flowFeesAdmin)
    }
}
