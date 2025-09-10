import "FlowTransactionScheduler"
import "FlowToken"
import "FungibleToken"

// ⚠️  WARNING: UNSAFE FOR PRODUCTION ⚠️
// This is a TEST CONTRACT ONLY and should NEVER be used in production!
// This contract is designed solely for testing FlowTransactionScheduler functionality
// and contains unsafe implementations that could lead to loss of funds or security vulnerabilities.
//
// DO NOT DEPLOY THIS CONTRACT OR A SIMILAR CONTRACT TO MAINNET OR ANY PRODUCTION ENVIRONMENT
// UNLESS YOU ARE SURE WHAT YOU ARE DOING!
//
// TestFlowScheduledTransactionHandler is a simplified test contract for testing FlowTransactionScheduler
access(all) contract TestFlowScheduledTransactionHandler {
    access(all) var scheduledTransactions: @{UInt64: FlowTransactionScheduler.ScheduledTransaction}
    access(all) var succeededTransactions: [UInt64]

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {

        access(all) let name: String
        access(all) let description: String

        init(name: String, description: String) {
            self.name = name
            self.description = description
        }
        
        access(FlowTransactionScheduler.Execute) 
        fun executeTransaction(id: UInt64, data: AnyStruct?) {
            // Most transactions will have string data
            if let dataString = data as? String {
                // intentional failure test case
                if dataString == "fail" {
                    panic("Transaction \(id) failed")
                } else if dataString == "cancel" {
                    // This should always fail because the transaction can't cancel itself during execution
                    destroy <-TestFlowScheduledTransactionHandler.cancelTransaction(id: id)
                } else {
                    // All other regular test cases should succeed
                    TestFlowScheduledTransactionHandler.succeededTransactions.append(id)
                }
            } else if let dataCap = data as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                // Testing scheduling a transaction with a transaction
                let scheduledTransaction <- FlowTransactionScheduler.schedule(
                    handlerCap: dataCap,
                    data: "test data",
                    timestamp: getCurrentBlock().timestamp + 10.0,
                    priority: FlowTransactionScheduler.Priority.High,
                    executionEffort: UInt64(1000),
                    fees: <-TestFlowScheduledTransactionHandler.getFeeFromVault(amount: 1.0)
                )
                TestFlowScheduledTransactionHandler.addScheduledTransaction(scheduledTx: <-scheduledTransaction)
            } else {
                panic("TestFlowScheduledTransactionHandler.executeTransaction: Invalid data type for transaction with id \(id). Type is \(data.getType().identifier)")
            }
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler(name: "Test FlowTransactionHandler Resource", description: "Executes a variety of transactions for different test cases")
    }

    // ⚠️  WARNING: UNSAFE FOR PRODUCTION ⚠️
    // This function is part of a TEST CONTRACT and should NEVER be used in production!
    // It contains unsafe implementations that could lead to loss of funds or security vulnerabilities.
    access(all) fun addScheduledTransaction(scheduledTx: @FlowTransactionScheduler.ScheduledTransaction) {
        let status = scheduledTx.status()
        if status == nil {
            panic("Invalid status for transaction with id \(scheduledTx.id)")
        }
        self.scheduledTransactions[scheduledTx.id] <-! scheduledTx
    }

    // ⚠️  WARNING: UNSAFE FOR PRODUCTION ⚠️
    // This function is part of a TEST CONTRACT and should NEVER be used in production!
    // It contains unsafe implementations that could lead to loss of funds or security vulnerabilities.
    access(all) fun cancelTransaction(id: UInt64): @FlowToken.Vault {
        let scheduledTx <- self.scheduledTransactions.remove(key: id)
            ?? panic("Invalid ID: \(id) transaction not found")
        return <-FlowTransactionScheduler.cancel(scheduledTx: <-scheduledTx!)
    }

    access(all) fun getSucceededTransactions(): [UInt64] {
        return self.succeededTransactions
    }

    access(contract) fun getFeeFromVault(amount: UFix64): @FlowToken.Vault {
        // borrow a reference to the vault that will be used for fees
        let vault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        return <- vault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) init() {
        self.scheduledTransactions <- {}
        self.succeededTransactions = []

        self.HandlerStoragePath = /storage/testTransactionHandler
        self.HandlerPublicPath = /public/testTransactionHandler
    }
} 