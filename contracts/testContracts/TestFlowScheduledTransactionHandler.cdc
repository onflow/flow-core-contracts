import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "MetadataViews"

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

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>(), Type<MetadataViews.Display>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return TestFlowScheduledTransactionHandler.HandlerStoragePath
                case Type<PublicPath>():
                    return TestFlowScheduledTransactionHandler.HandlerPublicPath
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: ""
                        )
                    )
                default:
                    return nil
            }
        }
        
        /// executeTransaction executes the transaction logic
        /// This executeTransaction function only exists to test the transaction scheduler
        /// and doesn't do anything meaningful besides having a few different cases for testing
        /// The regular success case simply appends the transaction ID to the succeededTransactions array
        access(FlowTransactionScheduler.Execute) 
        fun executeTransaction(id: UInt64, data: AnyStruct?) {
            // Most test transactions will have string data
            // though transactions can be scheduled with any data type
            if let dataString = data as? String {
                // intentional failure test case
                if dataString == "fail" {
                    panic("Transaction \(id) failed")
                } else if dataString == "cancel" {
                    let manager = TestFlowScheduledTransactionHandler.borrowManager()
                    // This should always fail because the callback can't cancel itself during execution
                    destroy <-manager.cancel(id: id)
                } else {
                    // All other regular test cases should succeed
                    TestFlowScheduledTransactionHandler.succeededTransactions.append(id)
                }
            } else if let dataCap = data as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                // Testing scheduling a transaction with a transaction
                let manager = TestFlowScheduledTransactionHandler.borrowManager()
                manager.schedule(
                    handlerCap: dataCap,
                    data: "test data",
                    timestamp: getCurrentBlock().timestamp + 10.0,
                    priority: FlowTransactionScheduler.Priority.High,
                    executionEffort: UInt64(1000),
                    fees: <-TestFlowScheduledTransactionHandler.getFeeFromVault(amount: 1.0)
                )
            } else {
                panic("TestFlowScheduledTransactionHandler.executeTransaction: Invalid data type for transaction with id \(id). Type is \(data.getType().identifier)")
            }
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler(name: "Test FlowTransactionHandler Resource", description: "Executes a variety of transactions for different test cases")
    }

    /** ---------------------------------------------------------------------------------
     Reentrant handler for testing the reentrancy protection in FlowTransactionScheduler.schedule()
     --------------------------------------------------------------------------------- */

    access(all) let ReentrantHandlerStoragePath: StoragePath
    access(all) let ReentrantHandlerPublicPath: PublicPath

    /// The timestamp that the reentrant schedule attempt targets.
    /// A constant far-future timestamp is used so tests can schedule the outer transaction
    /// at the exact same slot without depending on the block time.
    access(all) let reentrantScheduleTimestamp: UFix64

    /// The execution effort used for the reentrant schedule attempt
    access(all) let reentrantScheduleEffort: UInt64

    /// Whether the reentrant schedule has already been attempted.
    /// Used to only attempt the reentrant schedule once to avoid infinite recursion.
    access(all) var reentrantScheduleAttempted: Bool

    /// ReentrantHandler is a malicious handler used to test that schedule() cannot be
    /// reentered to bypass the per-slot effort limit.
    /// Its resolveView() attempts to schedule another high-priority transaction for the
    /// same slot while the outer schedule() call is still in flight.
    access(all) resource ReentrantHandler: FlowTransactionScheduler.TransactionHandler {

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath
                case Type<PublicPath>():
                    // Malicious behavior: attempt to reenter schedule() while the outer
                    // schedule() call that triggered this resolveView() is still in flight.
                    // Only attempt once to avoid infinite recursion.
                    if !TestFlowScheduledTransactionHandler.reentrantScheduleAttempted {
                        TestFlowScheduledTransactionHandler.reentrantScheduleAttempted = true
                        TestFlowScheduledTransactionHandler.attemptReentrantSchedule()
                    }
                    return TestFlowScheduledTransactionHandler.ReentrantHandlerPublicPath
                default:
                    return nil
            }
        }

        access(FlowTransactionScheduler.Execute)
        fun executeTransaction(id: UInt64, data: AnyStruct?) {
            // The reentrant transactions are never meant to be executed in tests
        }
    }

    access(all) fun createReentrantHandler(): @ReentrantHandler {
        return <- create ReentrantHandler()
    }

    /// Attempts to schedule a high-priority transaction for the same slot as the
    /// outer schedule() call that is currently in flight.
    /// With the reentrancy fix in place, the outer call has already reserved its slot
    /// capacity, so this nested schedule fails the effort estimate and panics.
    access(contract) fun attemptReentrantSchedule() {
        let manager = self.borrowManager()

        // Find the entitled capability for the reentrant handler
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        for controller in self.account.capabilities.storage.getControllers(forPath: self.ReentrantHandlerStoragePath) {
            if let cap = controller.capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
                break
            }
        }

        manager.schedule(
            handlerCap: handlerCap ?? panic("Could not find an entitled capability for the reentrant transaction handler"),
            data: nil,
            timestamp: self.reentrantScheduleTimestamp,
            priority: FlowTransactionScheduler.Priority.High,
            executionEffort: self.reentrantScheduleEffort,
            fees: <-self.getFeeFromVault(amount: 10.0)
        )
    }

    access(all) fun getSucceededTransactions(): [UInt64] {
        return self.succeededTransactions
    }

    access(contract) fun borrowManager(): auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager} {
        return self.account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Callback manager not set")
    }

    access(contract) fun getFeeFromVault(amount: UFix64): @FlowToken.Vault {
        // borrow a reference to the vault that will be used for fees
        let vault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        return <- vault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) init() {
        self.succeededTransactions = []

        self.HandlerStoragePath = /storage/testTransactionHandler
        self.HandlerPublicPath = /public/testTransactionHandler

        self.ReentrantHandlerStoragePath = /storage/testReentrantTransactionHandler
        self.ReentrantHandlerPublicPath = /public/testReentrantTransactionHandler
        self.reentrantScheduleTimestamp = 4_000_000_000.0
        self.reentrantScheduleEffort = 9_000
        self.reentrantScheduleAttempted = false
    }
} 