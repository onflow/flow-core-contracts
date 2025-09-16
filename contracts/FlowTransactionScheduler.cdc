import "FungibleToken"
import "FlowToken"
import "FlowFees"
import "FlowStorageFees"
import "ViewResolver"

/// FlowTransactionScheduler enables smart contracts to schedule autonomous execution in the future.
///
/// This contract implements FLIP 330's scheduled transaction system, allowing contracts to "wake up" and execute
/// logic at predefined times without external triggers. 
///
/// Scheduled transactions are prioritized (High/Medium/Low) with different execution guarantees and fee multipliers: 
///   - High priority guarantees first-block execution,
///   - Medium priority provides best-effort scheduling,
///   - Low priority executes opportunistically when capacity allows after the time it was scheduled. 
///
/// The system uses time slots with execution effort limits to manage network resources,
/// ensuring predictable performance while enabling novel autonomous blockchain patterns like recurring
/// payments, automated arbitrage, and time-based contract logic.
access(all) contract FlowTransactionScheduler {

    /// singleton instance used to store all scheduled transaction data
    /// and route all scheduled transaction functionality
    access(self) var sharedScheduler: Capability<auth(Cancel) &SharedScheduler>

    /// storage path for the singleton scheduler resource
    access(all) let storagePath: StoragePath

    /// Enums

    /// Priority
    access(all) enum Priority: UInt8 {
        access(all) case High
        access(all) case Medium
        access(all) case Low
    }

    /// Status
    access(all) enum Status: UInt8 {
        /// unknown statuses are used for handling historic scheduled transactions with null statuses
        access(all) case Unknown
        /// mutable status
        access(all) case Scheduled
        /// finalized statuses
        access(all) case Executed
        access(all) case Canceled
    }

    /// Events

    /// Emitted when a transaction is scheduled
    access(all) event Scheduled(
        id: UInt64,
        priority: UInt8,
        timestamp: UFix64,
        executionEffort: UInt64,
        fees: UFix64,
        transactionHandlerOwner: Address,
        transactionHandlerTypeIdentifier: String
    )

    /// Emitted when a scheduled transaction's scheduled timestamp is reached and it is ready for execution
    access(all) event PendingExecution(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        fees: UFix64,
        transactionHandlerOwner: Address,
        transactionHandlerTypeIdentifier: String
    )

    /// Emitted when a scheduled transaction is executed by the FVM
    access(all) event Executed(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        transactionHandlerOwner: Address,
        transactionHandlerTypeIdentifier: String
    )

    /// Emitted when a scheduled transaction is canceled by the creator of the transaction
    access(all) event Canceled(
        id: UInt64,
        priority: UInt8,
        feesReturned: UFix64,
        feesDeducted: UFix64,
        transactionHandlerOwner: Address,
        transactionHandlerTypeIdentifier: String
    )

    /// Emitted when a collection limit is reached
    /// The limit that was reached is non-nil and is the limit that was reached
    /// The other limit that was not reached is nil
    access(all) event CollectionLimitReached(
        collectionEffortLimit: UInt64?,
        collectionTransactionsLimit: Int?
    )

    // Emitted when one or more of the configuration details fields are updated
    // Event listeners can listen to this and query the new configuration
    // if they need to
    access(all) event ConfigUpdated()

    /// Entitlements
    access(all) entitlement Execute
    access(all) entitlement Process
    access(all) entitlement Cancel
    access(all) entitlement UpdateConfig

    /// Interfaces

    /// TransactionHandler is an interface that defines a single method executeTransaction that 
    /// must be implemented by the resource that contains the logic to be executed by the scheduled transaction.
    /// An authorized capability to this resource is provided when scheduling a transaction.
    /// The transaction scheduler uses this capability to execute the transaction when its scheduled timestamp arrives.
    access(all) resource interface TransactionHandler: ViewResolver.Resolver {

        access(all) view fun getViews(): [Type] {
            return []
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }

        /// Executes the implemented transaction logic
        ///
        /// @param id: The id of the scheduled transaction (this can be useful for any internal tracking)
        /// @param data: The data that was passed when the transaction was originally scheduled
        /// that may be useful for the execution of the transaction logic
        access(Execute) fun executeTransaction(id: UInt64, data: AnyStruct?)
    }

    /// Structs

    /// ScheduledTransaction is the resource that the user receives after scheduling a transaction.
    /// It allows them to get the status of their transaction and can be passed back
    /// to the scheduler contract to cancel the transaction if it has not yet been executed. 
    access(all) resource ScheduledTransaction {
        access(all) let id: UInt64
        access(all) let timestamp: UFix64
        access(all) let handlerTypeIdentifier: String

        access(all) view fun status(): Status? {
            return FlowTransactionScheduler.sharedScheduler.borrow()!.getStatus(id: self.id)
        }

        init(
            id: UInt64, 
            timestamp: UFix64,
            handlerTypeIdentifier: String
        ) {
            self.id = id
            self.timestamp = timestamp
            self.handlerTypeIdentifier = handlerTypeIdentifier
        }

        // event emitted when the resource is destroyed
        access(all) event ResourceDestroyed(id: UInt64 = self.id, timestamp: UFix64 = self.timestamp, handlerTypeIdentifier: String = self.handlerTypeIdentifier)
    }

    /// EstimatedScheduledTransaction contains data for estimating transaction scheduling.
    access(all) struct EstimatedScheduledTransaction {
        /// flowFee is the estimated fee in Flow for the transaction to be scheduled
        access(all) let flowFee: UFix64?
        /// timestamp is estimated timestamp that the transaction will be executed at
        access(all) let timestamp: UFix64?
        /// error is an optional error message if the transaction cannot be scheduled
        access(all) let error: String?

        access(contract) view init(flowFee: UFix64?, timestamp: UFix64?, error: String?) {
            self.flowFee = flowFee
            self.timestamp = timestamp
            self.error = error
        }
    }

    /// Transaction data is a representation of a scheduled transaction
    /// It is the source of truth for an individual transaction and stores the
    /// capability to the handler that contains the logic that will be executed by the transaction.
    access(all) struct TransactionData {
        access(all) let id: UInt64
        access(all) let priority: Priority
        access(all) let executionEffort: UInt64
        access(all) var status: Status

        /// Fee amount to pay for the transaction
        access(all) let fees: UFix64

        /// The timestamp that the transaction is scheduled for
        /// For medium priority transactions, it may be different than the requested timestamp
        /// For low priority transactions, it is the requested timestamp,
        /// but the timestamp where the transaction is actually executed may be different
        access(all) var scheduledTimestamp: UFix64

        /// Capability to the logic that the transaction will execute
        access(contract) let handler: Capability<auth(Execute) &{TransactionHandler}>

        /// Type identifier of the transaction handler
        access(all) let handlerTypeIdentifier: String
        access(all) let handlerAddress: Address

        /// Optional data that can be passed to the handler
        access(contract) let data: AnyStruct?

        access(contract) init(
            id: UInt64,
            handler: Capability<auth(Execute) &{TransactionHandler}>,
            scheduledTimestamp: UFix64,
            data: AnyStruct?,
            priority: Priority,
            executionEffort: UInt64,
            fees: UFix64,
        ) {
            self.id = id
            self.handler = handler
            self.data = data
            self.priority = priority
            self.executionEffort = executionEffort
            self.fees = fees
            self.status = Status.Scheduled
            let handlerRef = handler.borrow()
                ?? panic("Invalid transaction handler: Could not borrow a reference to the transaction handler")
            self.handlerAddress = handler.address
            self.handlerTypeIdentifier = handlerRef.getType().identifier
            self.scheduledTimestamp = scheduledTimestamp
        }

        /// setStatus updates the status of the transaction.
        /// It panics if the transaction status is already finalized.
        access(contract) fun setStatus(newStatus: Status) {
            pre {
                newStatus != Status.Unknown: "Invalid status: New status cannot be Unknown"
                self.status != Status.Executed && self.status != Status.Canceled:
                    "Invalid status: Transaction with id \(self.id) is already finalized"
                newStatus == Status.Executed ? self.status == Status.Scheduled : true:
                    "Invalid status: Transaction with id \(self.id) can only be set as Executed if it is Scheduled"
                newStatus == Status.Canceled ? self.status == Status.Scheduled : true:
                    "Invalid status: Transaction with id \(self.id) can only be set as Canceled if it is Scheduled"
            }

            self.status = newStatus
        }

        /// setScheduledTimestamp updates the scheduled timestamp of the transaction.
        /// It panics if the transaction status is already finalized.
        access(contract) fun setScheduledTimestamp(newTimestamp: UFix64) {
            pre {
                self.status != Status.Executed && self.status != Status.Canceled:
                    "Invalid status: Transaction with id \(self.id) is already finalized"
            }
            self.scheduledTimestamp = newTimestamp
        }

        /// payAndRefundFees withdraws fees from the transaction based on the refund multiplier.
        /// It deposits any leftover fees to the FlowFees vault to be used to pay node operator rewards
        /// like any other transaction on the Flow network.
        access(contract) fun payAndRefundFees(refundMultiplier: UFix64): @FlowToken.Vault {
            pre {
                refundMultiplier >= 0.0 && refundMultiplier <= 1.0:
                    "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got \(refundMultiplier)"
            }
            if refundMultiplier == 0.0 {
                FlowFees.deposit(from: <-FlowTransactionScheduler.withdrawFees(amount: self.fees))
                return <-FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            } else {
                let amountToReturn = self.fees * refundMultiplier
                let amountToKeep = self.fees - amountToReturn
                let feesToReturn <- FlowTransactionScheduler.withdrawFees(amount: amountToReturn)
                FlowFees.deposit(from: <-FlowTransactionScheduler.withdrawFees(amount: amountToKeep))
                return <-feesToReturn
            }
        }

        /// getData copies and returns the data field
        access(contract) view fun getData(): AnyStruct? {
            return self.data
        }
    }

    /// Struct interface representing all the base configuration details in the Scheduler contract
    /// that is used for governing the protocol
    /// This is an interface to allow for the configuration details to be updated in the future
    access(all) struct interface SchedulerConfig {

        /// maximum effort that can be used for any transaction
        access(all) var maximumIndividualEffort: UInt64

        /// minimum execution effort is the minimum effort that can be 
        /// used for any transaction
        access(all) var minimumExecutionEffort: UInt64

        /// slot total effort limit is the maximum effort that can be 
        /// cumulatively allocated to one timeslot by all priorities
        access(all) var slotTotalEffortLimit: UInt64

        /// slot shared effort limit is the maximum effort 
        /// that can be allocated to high and medium priority 
        /// transactions combined after their exclusive effort reserves have been filled
        access(all) var slotSharedEffortLimit: UInt64

        /// priority effort reserve is the amount of effort that is 
        /// reserved exclusively for each priority
        access(all) var priorityEffortReserve: {Priority: UInt64}

        /// priority effort limit is the maximum cumulative effort per priority in a timeslot
        access(all) var priorityEffortLimit: {Priority: UInt64}

        /// max data size is the maximum data size that can be stored for a transaction
        access(all) var maxDataSizeMB: UFix64

        /// priority fee multipliers are values we use to calculate the added 
        /// processing fee for each priority
        access(all) var priorityFeeMultipliers: {Priority: UFix64}

        /// refund multiplier is the portion of the fees that are refunded when any transaction is cancelled
        access(all) var refundMultiplier: UFix64

        /// canceledTransactionsLimit is the maximum number of canceled transactions
        /// to keep in the canceledTransactions array
        access(all) var canceledTransactionsLimit: UInt

        /// collectionEffortLimit is the maximum effort that can be used for all transactions in a collection
        access(all) var collectionEffortLimit: UInt64

        /// collectionTransactionsLimit is the maximum number of transactions that can be processed in a collection
        access(all) var collectionTransactionsLimit: Int

        access(all) init(
            maximumIndividualEffort: UInt64,
            minimumExecutionEffort: UInt64,
            slotSharedEffortLimit: UInt64,
            priorityEffortReserve: {Priority: UInt64},
            priorityEffortLimit: {Priority: UInt64},
            maxDataSizeMB: UFix64,
            priorityFeeMultipliers: {Priority: UFix64},
            refundMultiplier: UFix64,
            canceledTransactionsLimit: UInt,
            collectionEffortLimit: UInt64,
            collectionTransactionsLimit: Int
        ) {
            pre {
                refundMultiplier >= 0.0 && refundMultiplier <= 1.0:
                    "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got \(refundMultiplier)"
                priorityFeeMultipliers[Priority.Low]! >= 1.0:
                    "Invalid priority fee multiplier: Low priority multiplier must be greater than or equal to 1.0 but got \(priorityFeeMultipliers[Priority.Low]!)"
                priorityFeeMultipliers[Priority.Medium]! > priorityFeeMultipliers[Priority.Low]!:
                    "Invalid priority fee multiplier: Medium priority multiplier must be greater than or equal to \(priorityFeeMultipliers[Priority.Low]!) but got \(priorityFeeMultipliers[Priority.Medium]!)"
                priorityFeeMultipliers[Priority.High]! > priorityFeeMultipliers[Priority.Medium]!:
                    "Invalid priority fee multiplier: High priority multiplier must be greater than or equal to \(priorityFeeMultipliers[Priority.Medium]!) but got \(priorityFeeMultipliers[Priority.High]!)"
                priorityEffortLimit[Priority.High]! >= priorityEffortReserve[Priority.High]!:
                    "Invalid priority effort limit: High priority effort limit must be greater than or equal to the priority effort reserve of \(priorityEffortReserve[Priority.High]!)"
                priorityEffortLimit[Priority.Medium]! >= priorityEffortReserve[Priority.Medium]!:
                    "Invalid priority effort limit: Medium priority effort limit must be greater than or equal to the priority effort reserve of \(priorityEffortReserve[Priority.Medium]!)"
                priorityEffortLimit[Priority.Low]! >= priorityEffortReserve[Priority.Low]!:
                    "Invalid priority effort limit: Low priority effort limit must be greater than or equal to the priority effort reserve of \(priorityEffortReserve[Priority.Low]!)"
                collectionTransactionsLimit >= 0:
                    "Invalid collection transactions limit: Collection transactions limit must be greater than or equal to 0 but got \(collectionTransactionsLimit)"
                canceledTransactionsLimit >= 1:
                    "Invalid canceled transactions limit: Canceled transactions limit must be greater than or equal to 1 but got \(canceledTransactionsLimit)"
            }
            post {
                self.collectionEffortLimit > self.slotTotalEffortLimit:
                    "Invalid collection effort limit: Collection effort limit must be greater than \(self.slotTotalEffortLimit) but got \(self.collectionEffortLimit)"
            }
        }
    }

    /// Concrete implementation of the SchedulerConfig interface
    /// This struct is used to store the configuration details in the Scheduler contract
    access(all) struct Config: SchedulerConfig {
        access(all) var maximumIndividualEffort: UInt64
        access(all) var minimumExecutionEffort: UInt64
        access(all) var slotTotalEffortLimit: UInt64
        access(all) var slotSharedEffortLimit: UInt64
        access(all) var priorityEffortReserve: {Priority: UInt64}
        access(all) var priorityEffortLimit: {Priority: UInt64}
        access(all) var maxDataSizeMB: UFix64
        access(all) var priorityFeeMultipliers: {Priority: UFix64}
        access(all) var refundMultiplier: UFix64
        access(all) var canceledTransactionsLimit: UInt
        access(all) var collectionEffortLimit: UInt64
        access(all) var collectionTransactionsLimit: Int

        access(all) init(   
            maximumIndividualEffort: UInt64,
            minimumExecutionEffort: UInt64,
            slotSharedEffortLimit: UInt64,
            priorityEffortReserve: {Priority: UInt64},
            priorityEffortLimit: {Priority: UInt64},
            maxDataSizeMB: UFix64,
            priorityFeeMultipliers: {Priority: UFix64},
            refundMultiplier: UFix64,
            canceledTransactionsLimit: UInt,
            collectionEffortLimit: UInt64,
            collectionTransactionsLimit: Int
        ) {
            self.maximumIndividualEffort = maximumIndividualEffort
            self.minimumExecutionEffort = minimumExecutionEffort
            self.slotTotalEffortLimit = slotSharedEffortLimit + priorityEffortReserve[Priority.High]! + priorityEffortReserve[Priority.Medium]!
            self.slotSharedEffortLimit = slotSharedEffortLimit
            self.priorityEffortReserve = priorityEffortReserve
            self.priorityEffortLimit = priorityEffortLimit
            self.maxDataSizeMB = maxDataSizeMB
            self.priorityFeeMultipliers = priorityFeeMultipliers
            self.refundMultiplier = refundMultiplier
            self.canceledTransactionsLimit = canceledTransactionsLimit
            self.collectionEffortLimit = collectionEffortLimit
            self.collectionTransactionsLimit = collectionTransactionsLimit
        }
    }


    /// SortedTimestamps maintains timestamps sorted in ascending order for efficient processing
    /// It encapsulates all operations related to maintaining and querying sorted timestamps
    access(all) struct SortedTimestamps {
        /// Internal sorted array of timestamps
        access(self) var timestamps: [UFix64]

        access(all) init() {
            self.timestamps = []
        }

        /// Add a timestamp to the sorted array maintaining sorted order
        access(all) fun add(timestamp: UFix64) {

            var insertIndex = 0
            for i, ts in self.timestamps {
                if timestamp < ts {
                    insertIndex = i
                    break
                } else if timestamp == ts {
                    return
                }
                insertIndex = i + 1
            }
            self.timestamps.insert(at: insertIndex, timestamp)
        }

        /// Remove a timestamp from the sorted array
        access(all) fun remove(timestamp: UFix64) {

            let index = self.timestamps.firstIndex(of: timestamp)
            if index != nil {
                self.timestamps.remove(at: index!)
            }
        }

        /// Get all timestamps that are in the past (less than or equal to current timestamp)
        access(all) fun getBefore(current: UFix64): [UFix64] {
            let pastTimestamps: [UFix64] = []
            for timestamp in self.timestamps {
                if timestamp <= current {
                    pastTimestamps.append(timestamp)
                } else {
                    break  // No need to check further since array is sorted
                }
            }
            return pastTimestamps
        }

        /// Check if there are any timestamps that need processing
        /// Returns true if processing is needed, false for early exit
        access(all) fun hasBefore(current: UFix64): Bool {
            return self.timestamps.length > 0 && self.timestamps[0] <= current
        }

        /// Get the whole array of timestamps
        access(all) fun getAll(): [UFix64] {
            return self.timestamps
        }
    }

    /// Resources

    /// Shared scheduler is a resource that is used as a singleton in the scheduler contract and contains 
    /// all the functionality to schedule, process and execute transactions as well as the internal state. 
    access(all) resource SharedScheduler {
        /// nextID contains the next transaction ID to be assigned
        /// This the ID is monotonically increasing and is used to identify each transaction
        access(contract) var nextID: UInt64

        /// transactions is a map of transaction IDs to TransactionData structs
        access(contract) var transactions: {UInt64: TransactionData}

        /// slot queue is a map of timestamps to Priorities to transaction IDs and their execution efforts
        access(contract) var slotQueue: {UFix64: {Priority: {UInt64: UInt64}}}

        /// slot used effort is a map of timestamps map of priorities and 
        /// efforts that has been used for the timeslot
        access(contract) var slotUsedEffort: {UFix64: {Priority: UInt64}}

        /// sorted timestamps manager for efficient processing
        access(contract) var sortedTimestamps: SortedTimestamps
    
        /// canceled transactions keeps a record of canceled transaction IDs up to a canceledTransactionsLimit
        access(contract) var canceledTransactions: [UInt64]

        /// Struct that contains all the configuration details for the transaction scheduler protocol
        /// Can be updated by the owner of the contract
        access(contract) var config: {SchedulerConfig}

        access(all) init() {
            self.nextID = 1
            self.canceledTransactions = [0 as UInt64]
            
            self.transactions = {}
            self.slotUsedEffort = {}
            self.slotQueue = {}
            self.sortedTimestamps = SortedTimestamps()
            
            /* Default slot efforts and limits look like this:

                Timestamp Slot (35kee)
                ┌─────────────────────────┐
                │ ┌─────────────┐         │ 
                │ │ High Only   │         │ High: 30kee max
                │ │   20kee     │         │ (20 exclusive + 10 shared)
                │ └─────────────┘         │
                | ┌───────────────┐       |
                │ |  Shared Pool  │       |
                | │ (High+Medium) │       |
                | │     10kee     │       |
                | └───────────────┘       |
                │ ┌─────────────┐         │ Medium: 15kee max  
                │ │ Medium Only │         │ (5 exclusive + 10 shared)
                │ │   5kee      │         │
                │ └─────────────┘         │
                │ ┌─────────────────────┐ │ Low: 5kee max
                │ │ Low (if space left) │ │ (execution time only)
                │ │       5kee          │ │
                │ └─────────────────────┘ │
                └─────────────────────────┘
            */

            let sharedEffortLimit: UInt64 = 10_000
            let highPriorityEffortReserve: UInt64 = 20_000
            let mediumPriorityEffortReserve: UInt64 = 5_000

            self.config = Config(
                maximumIndividualEffort: 9999,
                minimumExecutionEffort: 10,
                slotSharedEffortLimit: sharedEffortLimit,
                priorityEffortReserve: {
                    Priority.High: highPriorityEffortReserve,
                    Priority.Medium: mediumPriorityEffortReserve,
                    Priority.Low: 0
                },
                priorityEffortLimit: {
                    Priority.High: highPriorityEffortReserve + sharedEffortLimit,
                    Priority.Medium: mediumPriorityEffortReserve + sharedEffortLimit,
                    Priority.Low: 5_000
                },
                maxDataSizeMB: 3.0,
                priorityFeeMultipliers: {
                    Priority.High: 10.0,
                    Priority.Medium: 5.0,
                    Priority.Low: 2.0
                },
                refundMultiplier: 0.5,
                canceledTransactionsLimit: 1000,
                collectionEffortLimit: 500_000, // Maximum effort for all transactions in a collection
                collectionTransactionsLimit: 150 // Maximum number of transactions in a collection
            )
        }

        /// Gets a copy of the struct containing all the configuration details
        /// of the Scheduler resource
        access(contract) view fun getConfig(): {SchedulerConfig} {
            return self.config
        }

        /// sets all the configuration details for the Scheduler resource
        access(UpdateConfig) fun setConfig(newConfig: {SchedulerConfig}) {
            self.config = newConfig
            emit ConfigUpdated()
        }

        /// getTransaction returns a copy of the specified transaction
        access(contract) view fun getTransaction(id: UInt64): TransactionData? {
            return self.transactions[id]
        }

        /// borrowTransaction borrows a reference to the specified transaction
        access(contract) view fun borrowTransaction(id: UInt64): &TransactionData? {
            return &self.transactions[id]
        }

        /// getCanceledTransactions returns a copy of the canceled transactions array
        access(contract) view fun getCanceledTransactions(): [UInt64] {
            return self.canceledTransactions
        }

        /// getTransactionsForTimeframe returns a dictionary of transactions scheduled within a specified time range,
        /// organized by timestamp and priority with arrays of transaction IDs.
        /// WARNING: If you provide a time range that is too large, the function will likely fail to complete
        /// because the function will run out of gas. Keep the time range small.
        ///
        /// @param startTimestamp: The start timestamp (inclusive) for the time range
        /// @param endTimestamp: The end timestamp (inclusive) for the time range
        /// @return {UFix64: {Priority: [UInt64]}}: A dictionary mapping timestamps to priorities to arrays of transaction IDs
        access(contract) fun getTransactionsForTimeframe(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: {UInt8: [UInt64]}} {
            var transactionsInTimeframe: {UFix64: {UInt8: [UInt64]}} = {}
            
            // Validate input parameters
            if startTimestamp > endTimestamp {
                return transactionsInTimeframe
            }
            
            // Get all timestamps that fall within the specified range
            let allTimestampsBeforeEnd = self.sortedTimestamps.getBefore(current: endTimestamp)
            
            for timestamp in allTimestampsBeforeEnd {
                // Check if this timestamp falls within our range
                if timestamp < startTimestamp { continue }
                
                let transactionPriorities = self.slotQueue[timestamp] ?? {}
                
                var timestampTransactions: {UInt8: [UInt64]} = {}
                
                for priority in transactionPriorities.keys {
                    let transactionIDs = transactionPriorities[priority] ?? {}
                    var priorityTransactions: [UInt64] = []
                        
                    for id in transactionIDs.keys {
                        priorityTransactions.append(id)
                    }
                        
                    if priorityTransactions.length > 0 {
                        timestampTransactions[priority.rawValue] = priorityTransactions
                    }
                }
                
                if timestampTransactions.keys.length > 0 {
                    transactionsInTimeframe[timestamp] = timestampTransactions
                }
                
            }
            
            return transactionsInTimeframe
        }

        /// calculate fee by converting execution effort to a fee in Flow tokens.
        /// @param executionEffort: The execution effort of the transaction
        /// @param priority: The priority of the transaction
        /// @param dataSizeMB: The size of the data that was passed when the transaction was originally scheduled
        /// @return UFix64: The fee in Flow tokens that is required to pay for the transaction
        access(contract) fun calculateFee(executionEffort: UInt64, priority: Priority, dataSizeMB: UFix64): UFix64 {
            // Use the official FlowFees calculation
            let baseFee = FlowFees.computeFees(inclusionEffort: 1.0, executionEffort: UFix64(executionEffort)/100000000.0)
            
            // Scale the execution fee by the multiplier for the priority
            let scaledExecutionFee = baseFee * self.config.priorityFeeMultipliers[priority]!

            // Calculate the FLOW required to pay for storage of the transaction data
            let storageFee = FlowStorageFees.storageCapacityToFlow(dataSizeMB)
            
            return scaledExecutionFee + storageFee
        }

        /// getNextIDAndIncrement returns the next ID and increments the ID counter
        access(self) fun getNextIDAndIncrement(): UInt64 {
            let nextID = self.nextID
            self.nextID = self.nextID + 1
            return nextID
        }

        /// get status of the scheduled transaction
        /// @param id: The ID of the transaction to get the status of
        /// @return Status: The status of the transaction, if the transaction is not found Unknown is returned.
        access(contract) view fun getStatus(id: UInt64): Status? {
            // if the transaction ID is greater than the next ID, it is not scheduled yet and has never existed
            if id == 0 as UInt64 || id >= self.nextID {
                return nil
            }

            // This should always return Scheduled or Executed
            if let tx = self.borrowTransaction(id: id) {
                return tx.status
            }

            // if the transaction was canceled and it is still not pruned from 
            // list return canceled status
            if self.canceledTransactions.contains(id) {
                return Status.Canceled
            }

            // if transaction ID is after first canceled ID it must be executed 
            // otherwise it would have been canceled and part of this list
            let firstCanceledID = self.canceledTransactions[0]
            if id > firstCanceledID {
                return Status.Executed
            }

            // the transaction list was pruned and the transaction status might be 
            // either canceled or execute so we return unknown
            return Status.Unknown
        }

        /// schedule is the primary entry point for scheduling a new transaction within the scheduler contract. 
        /// If scheduling the transaction is not possible either due to invalid arguments or due to 
        /// unavailable slots, the function panics. 
        //
        /// The schedule function accepts the following arguments:
        /// @param: transaction: A capability to a resource in storage that implements the transaction handler 
        ///    interface. This handler will be invoked at execution time and will receive the specified data payload.
        /// @param: timestamp: Specifies the earliest block timestamp at which the transaction is eligible for execution 
        ///    (Unix timestamp so fractional seconds values are ignored). It must be set in the future.
        /// @param: priority: An enum value (`High`, `Medium`, or `Low`) that influences the scheduling behavior and determines 
        ///    how soon after the timestamp the transaction will be executed.
        /// @param: executionEffort: Defines the maximum computational resources allocated to the transaction. This also determines 
        ///    the fee charged. Unused execution effort is not refunded.
        /// @param: fees: A Vault resource containing sufficient funds to cover the required execution effort.
        access(contract) fun schedule(
            handlerCap: Capability<auth(Execute) &{TransactionHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): @ScheduledTransaction {

            // Use the estimate function to validate inputs
            let estimate = self.estimate(
                data: data,
                timestamp: timestamp,
                priority: priority,
                executionEffort: executionEffort
            )

            // Estimate returns an error for low priority transactions
            // so need to check that the error is fine
            // because low priority transactions are allowed in schedule
            if estimate.error != nil && estimate.timestamp == nil {
                panic(estimate.error!)
            }

            assert (
                fees.balance >= estimate.flowFee!,
                message: "Insufficient fees: The Fee balance of \(fees.balance) is not sufficient to pay the required amount of \(estimate.flowFee!) for execution of the transaction."
            )

            let transactionID = self.getNextIDAndIncrement()
            let transactionData = TransactionData(
                id: transactionID,
                handler: handlerCap,
                scheduledTimestamp: estimate.timestamp!,
                data: data,
                priority: priority,
                executionEffort: executionEffort,
                fees: fees.balance,
            )

            // Deposit the fees to the service account's vault
            FlowTransactionScheduler.depositFees(from: <-fees)

            emit Scheduled(
                id: transactionData.id,
                priority: transactionData.priority.rawValue,
                timestamp: transactionData.scheduledTimestamp,
                executionEffort: transactionData.executionEffort,
                fees: transactionData.fees,
                transactionHandlerOwner: transactionData.handler.address,
                transactionHandlerTypeIdentifier: transactionData.handlerTypeIdentifier
            )

            // Add the transaction to the slot queue and update the internal state
            self.addTransaction(slot: estimate.timestamp!, txData: transactionData)
            
            return <-create ScheduledTransaction(
                id: transactionID, 
                timestamp: estimate.timestamp!,
                handlerTypeIdentifier: transactionData.handlerTypeIdentifier
            )
        }

        /// The estimate function calculates the required fee in Flow and expected execution timestamp for 
        /// a transaction based on the requested timestamp, priority, and execution effort. 
        //
        /// If the provided arguments are invalid or the transaction cannot be scheduled (e.g., due to 
        /// insufficient computation effort or unavailable time slots) the estimate function
        /// returns an EstimatedScheduledTransaction struct with a non-nil error message.
        ///        
        /// This helps developers ensure sufficient funding and preview the expected scheduling window, 
        /// reducing the risk of unnecessary cancellations.
        ///
        /// @param data: The data that was passed when the transaction was originally scheduled
        /// @param timestamp: The requested timestamp for the transaction
        /// @param priority: The priority of the transaction
        /// @param executionEffort: The execution effort of the transaction
        /// @return EstimatedScheduledTransaction: A struct containing the estimated fee, timestamp, and error message
        access(contract) fun estimate(
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64
        ): EstimatedScheduledTransaction {
            // Remove fractional values from the timestamp
            let sanitizedTimestamp = UFix64(UInt64(timestamp))

            if sanitizedTimestamp <= getCurrentBlock().timestamp {
                return EstimatedScheduledTransaction(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid timestamp: \(sanitizedTimestamp) is in the past, current timestamp: \(getCurrentBlock().timestamp)"
                        )
            }

            if executionEffort > self.config.maximumIndividualEffort {
                return EstimatedScheduledTransaction(
                    flowFee: nil,
                    timestamp: nil,
                    error: "Invalid execution effort: \(executionEffort) is greater than the maximum transaction effort of \(self.config.maximumIndividualEffort)"
                )
            }

            if executionEffort > self.config.priorityEffortLimit[priority]! {
                return EstimatedScheduledTransaction(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is greater than the priority's max effort of \(self.config.priorityEffortLimit[priority]!)"
                        )
            }

            if executionEffort < self.config.minimumExecutionEffort {
                return EstimatedScheduledTransaction(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is less than the minimum execution effort of \(self.config.minimumExecutionEffort)"
                        )
            }

            let dataSizeMB = FlowTransactionScheduler.getSizeOfData(data)
            if dataSizeMB > self.config.maxDataSizeMB {
                return EstimatedScheduledTransaction(
                    flowFee: nil,
                    timestamp: nil,
                    error: "Invalid data size: \(dataSizeMB) is greater than the maximum data size of \(self.config.maxDataSizeMB)MB"
                )
            }

            let fee = self.calculateFee(executionEffort: executionEffort, priority: priority, dataSizeMB: dataSizeMB)

            let scheduledTimestamp = self.calculateScheduledTimestamp(
                timestamp: sanitizedTimestamp, 
                priority: priority, 
                executionEffort: executionEffort
            )

            if scheduledTimestamp == nil {
                return EstimatedScheduledTransaction(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort for the requested timestamp."
                        )
            }

            if priority == Priority.Low {
                return EstimatedScheduledTransaction(
                            flowFee: fee,
                            timestamp: scheduledTimestamp,
                            error: "Invalid Priority: Cannot estimate for Low Priority transactions. They will be included in the first block with available space after their requested timestamp."
                        )
            }

            return EstimatedScheduledTransaction(flowFee: fee, timestamp: scheduledTimestamp, error: nil)
        }

        /// calculateScheduledTimestamp calculates the timestamp at which a transaction 
        /// can be scheduled. It takes into account the priority of the transaction and 
        /// the execution effort.
        /// - If the transaction is high priority, it returns the timestamp if there is enough 
        ///    space or nil if there is no space left.
        /// - If the transaction is medium or low priority and there is space left in the requested timestamp,
        ///   it returns the requested timestamp. If there is not enough space, it finds the next timestamp with space.
        ///
        /// @param timestamp: The requested timestamp for the transaction
        /// @param priority: The priority of the transaction
        /// @param executionEffort: The execution effort of the transaction
        /// @return UFix64?: The timestamp at which the transaction can be scheduled, or nil if there is no space left for a high priority transaction
        access(contract) view fun calculateScheduledTimestamp(
            timestamp: UFix64, 
            priority: Priority, 
            executionEffort: UInt64
        ): UFix64? {

            let used = self.slotUsedEffort[timestamp]
            // if nothing is scheduled at this timestamp, we can schedule at provided timestamp
            if used == nil { 
                return timestamp
            }
            
            let available = self.getSlotAvailableEffort(timestamp: timestamp, priority: priority)
            // if theres enough space, we can tentatively schedule at provided timestamp
            if executionEffort <= available {
                return timestamp
            }
            
            if priority == Priority.High {
                // high priority demands scheduling at exact timestamp or failing
                return nil
            }

            // if there is no space left for medium or low priority we search for next available timestamp
            // todo: check how big the callstack can grow and if we should avoid recursion
            // todo: we should refactor this into loops, because we could need to recurse 100s of times
            return self.calculateScheduledTimestamp(
                timestamp: timestamp + 1.0, 
                priority: priority, 
                executionEffort: executionEffort
            )
        }

        /// slot available effort returns the amount of effort that is available for a given timestamp and priority.
        access(contract) view fun getSlotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {

            // Remove fractional values from the timestamp
            let sanitizedTimestamp = UFix64(UInt64(timestamp))

            // Get the theoretical maximum allowed for the priority including shared
            let priorityLimit = self.config.priorityEffortLimit[priority]!
            
            // If nothing has been claimed for the requested timestamp,
            // return the full amount
            if !self.slotUsedEffort.containsKey(sanitizedTimestamp) {
                return priorityLimit
            }

            // Get the mapping of how much effort has been used
            // for each priority for the timestamp
            let slotPriorityEffortsUsed = self.slotUsedEffort[sanitizedTimestamp]!

            // Get the exclusive reserves for each priority
            let highReserve = self.config.priorityEffortReserve[Priority.High]!
            let mediumReserve = self.config.priorityEffortReserve[Priority.Medium]!

            // Get how much effort has been used for each priority
            let highUsed = slotPriorityEffortsUsed[Priority.High] ?? 0
            let mediumUsed = slotPriorityEffortsUsed[Priority.Medium] ?? 0

            // If it is low priority, return whatever effort is remaining
            // under 5000, subtracting the currently used effort for low priority
            if priority == Priority.Low {
                let highPlusMediumUsed = highUsed + mediumUsed
                let totalEffortRemaining = self.config.slotTotalEffortLimit.saturatingSubtract(highPlusMediumUsed)
                let lowEffortRemaining = totalEffortRemaining < priorityLimit ? totalEffortRemaining : priorityLimit
                let lowUsed = slotPriorityEffortsUsed[Priority.Low] ?? 0
                return lowEffortRemaining.saturatingSubtract(lowUsed)
            }
            
            // Get how much shared effort has been used for each priority
            // Ensure the results are always zero or positive
            let highSharedUsed: UInt64 = highUsed.saturatingSubtract(highReserve)
            let mediumSharedUsed: UInt64 = mediumUsed.saturatingSubtract(mediumReserve)

            // Get the theoretical total shared amount between priorities
            let totalShared = (self.config.slotTotalEffortLimit.saturatingSubtract(highReserve)).saturatingSubtract(mediumReserve)

            // Get the amount of shared effort currently available
            let highPlusMediumSharedUsed = highSharedUsed + mediumSharedUsed
            // prevent underflow
            let sharedAvailable = totalShared.saturatingSubtract(highPlusMediumSharedUsed)

            // we calculate available by calculating available shared effort and 
            // adding any unused reserves for that priority
            let reserve = self.config.priorityEffortReserve[priority]!
            let used = slotPriorityEffortsUsed[priority] ?? 0
            let unusedReserve: UInt64 = reserve.saturatingSubtract(used)
            let available = sharedAvailable + unusedReserve
            
            return available
        }

         /// add transaction to the queue and updates all the internal state as well as emit an event
        access(self) fun addTransaction(slot: UFix64, txData: TransactionData) {

            // If nothing is in the queue for this slot, initialize the slot
            if self.slotQueue[slot] == nil {
                self.slotQueue[slot] = {}

                // This also means that the used effort record for this slot has not been initialized
                self.slotUsedEffort[slot] = {
                    Priority.High: 0,
                    Priority.Medium: 0,
                    Priority.Low: 0
                }

                self.sortedTimestamps.add(timestamp: slot)
            }

            // Add this transaction id to the slot
            let slotQueue = self.slotQueue[slot]!
            if let priorityQueue = slotQueue[txData.priority] {
                priorityQueue[txData.id] = txData.executionEffort
                slotQueue[txData.priority] = priorityQueue
            } else {
                slotQueue[txData.priority] = {
                    txData.id: txData.executionEffort
                }
            }

            self.slotQueue[slot] = slotQueue

            // Add the execution effort for this transaction to the total for the slot's priority
            let slotEfforts = self.slotUsedEffort[slot]!
            var newPriorityEffort = slotEfforts[txData.priority]! + txData.executionEffort
            slotEfforts[txData.priority] = newPriorityEffort
            var newTotalEffort: UInt64 = 0
            for priority in slotEfforts.keys {
                newTotalEffort = newTotalEffort.saturatingAdd(slotEfforts[priority]!)
            }
            self.slotUsedEffort[slot] = slotEfforts
            
            // Need to potentially reschedule low priority transactions to make room for the new transaction
            // Iterate through them and record which ones to reschedule until the total effort is less than the limit
            let lowTransactionsToReschedule: [UInt64] = []
            if newTotalEffort > self.config.slotTotalEffortLimit {
                let lowPriorityTransactions = slotQueue[Priority.Low]!
                for id in lowPriorityTransactions.keys {
                    if newTotalEffort <= self.config.slotTotalEffortLimit {
                        break
                    }
                    lowTransactionsToReschedule.append(id)
                    newTotalEffort = newTotalEffort.saturatingSubtract(lowPriorityTransactions[id]!)
                }
            }

            // Store the transaction in the transactions map
            self.transactions[txData.id] = txData

            // Reschedule low priority transactions if needed
            self.rescheduleLowPriorityTransactions(slot: slot, transactions: lowTransactionsToReschedule)
        }

        /// rescheduleLowPriorityTransactions reschedules low priority transactions to make room for a new transaction
        /// @param slot: The slot that the transactions are currently scheduled at
        /// @param transactions: The transactions to reschedule
        access(self) fun rescheduleLowPriorityTransactions(slot: UFix64, transactions: [UInt64]) {
            for id in transactions {
                let tx = self.borrowTransaction(id: id)
                    ?? panic("Invalid ID: \(id) transaction not found") // critical bug

                assert (
                    tx.priority == Priority.Low,
                    message: "Invalid Priority: Cannot reschedule transaction with id \(id) because it is not low priority"
                )

                assert (
                    tx.scheduledTimestamp == slot,
                    message: "Invalid Timestamp: Cannot reschedule transaction with id \(id) because it is not scheduled at the same slot as the new transaction"
                )
                
                let newTimestamp = self.calculateScheduledTimestamp(
                    timestamp: slot + 1.0,
                    priority: Priority.Low,
                    executionEffort: tx.executionEffort
                )!

                let effort = tx.executionEffort

                let transactionData = self.removeTransaction(txData: tx)

                // Subtract the execution effort for this transaction from the slot's priority
                let slotEfforts = self.slotUsedEffort[slot]!
                slotEfforts[Priority.Low] = slotEfforts[Priority.Low]!.saturatingSubtract(effort)
                self.slotUsedEffort[slot] = slotEfforts

                // Update the transaction's scheduled timestamp and add it back to the slot queue
                transactionData.setScheduledTimestamp(newTimestamp: newTimestamp)
                self.addTransaction(slot: newTimestamp, txData: transactionData)
            }
        }

        /// remove the transaction from the slot queue.
        access(self) fun removeTransaction(txData: &TransactionData): TransactionData {

            let transactionID = txData.id
            let slot = txData.scheduledTimestamp
            let transactionPriority = txData.priority

            // remove transaction object
            let transactionObject = self.transactions.remove(key: transactionID)!
            
            // garbage collect slots 
            if let transactionQueue = self.slotQueue[slot] {

                if let priorityQueue = transactionQueue[transactionPriority] {
                    priorityQueue[transactionID] = nil
                    if priorityQueue.keys.length == 0 {
                        transactionQueue.remove(key: transactionPriority)
                    } else {
                        transactionQueue[transactionPriority] = priorityQueue
                    }

                    self.slotQueue[slot] = transactionQueue
                }

                // if the slot is now empty remove it from the maps
                if transactionQueue.keys.length == 0 {
                    self.slotQueue.remove(key: slot)
                    self.slotUsedEffort.remove(key: slot)

                    self.sortedTimestamps.remove(timestamp: slot)
                }
            }

            return transactionObject
        }

        /// pendingQueue creates a list of transactions that are ready for execution.
        /// For transaction to be ready for execution it must be scheduled.
        ///
        /// The queue is sorted by timestamp and then by priority (high, medium, low).
        /// The queue will contain transactions from all timestamps that are in the past.
        /// Low priority transactions will only be added if there is effort available in the slot.  
        /// The return value can be empty if there are no transactions ready for execution.
        access(Process) fun pendingQueue(): [&TransactionData] {
            let currentTimestamp = getCurrentBlock().timestamp
            var pendingTransactions: [&TransactionData] = []

            // total effort across different timestamps guards collection being over the effort limit
            var collectionAvailableEffort = self.config.collectionEffortLimit
            var transactionsAvailableCount = self.config.collectionTransactionsLimit

            // Collect past timestamps efficiently from sorted array
            let pastTimestamps = self.sortedTimestamps.getBefore(current: currentTimestamp)

            for timestamp in pastTimestamps {
                let transactionPriorities = self.slotQueue[timestamp] ?? {}
                var high: [&TransactionData] = []
                var medium: [&TransactionData] = []
                var low: [&TransactionData] = []

                for priority in transactionPriorities.keys {
                    let transactionIDs = transactionPriorities[priority] ?? {}
                    for id in transactionIDs.keys {
                        let tx = self.borrowTransaction(id: id)
                            ?? panic("Invalid ID: \(id) transaction not found during initial processing") // critical bug

                        // Only add scheduled transactions to the queue
                        if tx.status != Status.Scheduled {
                            continue
                        }

                        // this is safeguard to prevent collection growing too large in case of block production slowdown
                        if tx.executionEffort >= collectionAvailableEffort || transactionsAvailableCount == 0 {
                            emit CollectionLimitReached(
                                collectionEffortLimit: transactionsAvailableCount == 0 ? nil : self.config.collectionEffortLimit,
                                collectionTransactionsLimit: transactionsAvailableCount == 0 ? self.config.collectionTransactionsLimit : nil
                            )
                            break
                        }

                        collectionAvailableEffort = collectionAvailableEffort.saturatingSubtract(tx.executionEffort)
                        transactionsAvailableCount = transactionsAvailableCount - 1
                    
                        switch tx.priority {
                            case Priority.High:
                                high.append(tx)
                            case Priority.Medium:
                                medium.append(tx)
                            case Priority.Low:
                                low.append(tx)
                        }
                    }
                }

                pendingTransactions = pendingTransactions
                    .concat(high)
                    .concat(medium)
                    .concat(low)
            }

            return pendingTransactions
        }

        /// removeExecutedTransactions removes all transactions that are marked as executed.
        access(self) fun removeExecutedTransactions(_ currentTimestamp: UFix64) {
            let pastTimestamps = self.sortedTimestamps.getBefore(current: currentTimestamp)

            for timestamp in pastTimestamps {
                let transactionPriorities = self.slotQueue[timestamp] ?? {}
                
                for priority in transactionPriorities.keys {
                    let transactionIDs = transactionPriorities[priority] ?? {}
                    for id in transactionIDs.keys {
                        let tx = self.borrowTransaction(id: id)
                            ?? panic("Invalid ID: \(id) transaction not found during initial processing") // critical bug

                        // Only remove executed transactions
                        if tx.status != Status.Executed {
                            continue
                        }

                        // charge the full fee for transaction execution
                        destroy tx.payAndRefundFees(refundMultiplier: 0.0)

                        self.removeTransaction(txData: tx)
                    }
                }
            }
        }

        /// process scheduled transactions and prepare them for execution. 
        ///
        /// First, it removes transactions that have already been executed. 
        /// Then, it iterates over past timestamps in the queue and processes the transactions that are 
        /// eligible for execution. It also emits an event for each transaction that is processed.
        ///
        /// This function is only called by the FVM to process transactions.
        access(Process) fun process() {
            let currentTimestamp = getCurrentBlock().timestamp
            // Early exit if no timestamps need processing
            if !self.sortedTimestamps.hasBefore(current: currentTimestamp) {
                return
            }

            self.removeExecutedTransactions(currentTimestamp)

            let pendingTransactions = self.pendingQueue()
            
            if pendingTransactions.length == 0 {
                return
            }

            for tx in pendingTransactions {
                // Only emit the pending execution event if the transaction handler capability is borrowable
                // This is to prevent a situation where the transaction handler is not available
                // In that case, the transaction is no longer valid because it cannot be executed
                if let transactionHandler = tx.handler.borrow() {
                    emit PendingExecution(
                        id: tx.id,
                        priority: tx.priority.rawValue,
                        executionEffort: tx.executionEffort,
                        fees: tx.fees,
                        transactionHandlerOwner: tx.handler.address,
                        transactionHandlerTypeIdentifier: transactionHandler.getType().identifier
                    )
                }

                // after pending execution event is emitted we set the transaction as executed because we 
                // must rely on execution node to actually execute it. Execution of the transaction is 
                // done in a separate transaction that calls executeTransaction(id) function.
                // Executing the transaction can not update the status of transaction or any other shared state,
                // since that blocks concurrent transaction execution.
                // Therefore an optimistic update to executed is made here to avoid race condition.
                tx.setStatus(newStatus: Status.Executed)
            }
        }

        /// cancel a scheduled transaction and return a portion of the fees that were paid.
        ///
        /// @param id: The ID of the transaction to cancel
        /// @return: The fees to be returned to the caller
        access(Cancel) fun cancel(id: UInt64): @FlowToken.Vault {
            let tx = self.borrowTransaction(id: id) ?? 
                panic("Invalid ID: \(id) transaction not found")

            assert(
                tx.status == Status.Scheduled,
                message: "Transaction must be in a scheduled state in order to be canceled"
            )
            
            // Subtract the execution effort for this transaction from the slot's priority
            let slotEfforts = self.slotUsedEffort[tx.scheduledTimestamp]!
            slotEfforts[tx.priority] = slotEfforts[tx.priority]!.saturatingSubtract(tx.executionEffort)
            self.slotUsedEffort[tx.scheduledTimestamp] = slotEfforts

            let totalFees = tx.fees
            let refundedFees <- tx.payAndRefundFees(refundMultiplier: self.config.refundMultiplier)

            // if the transaction was canceled, add it to the canceled transactions array
            // maintain sorted order by inserting at the correct position
            var insertIndex = 0
            for i, canceledID in self.canceledTransactions {
                if id < canceledID {
                    insertIndex = i
                    break
                }
                insertIndex = i + 1
            }
            self.canceledTransactions.insert(at: insertIndex, id)
            
            // keep the array under the limit
            if UInt(self.canceledTransactions.length) > self.config.canceledTransactionsLimit {
                self.canceledTransactions.remove(at: 0)
            }

            emit Canceled(
                id: tx.id,
                priority: tx.priority.rawValue,
                feesReturned: refundedFees.balance,
                feesDeducted: totalFees - refundedFees.balance,
                transactionHandlerOwner: tx.handler.address,
                transactionHandlerTypeIdentifier: tx.handlerTypeIdentifier
            )

            self.removeTransaction(txData: tx)
            
            return <-refundedFees
        }

        /// execute transaction is a system function that is called by FVM to execute a transaction by ID.
        /// The transaction must be found and in correct state or the function panics and this is a fatal error
        ///
        /// This function is only called by the FVM to execute transactions.
        /// WARNING: this function should not change any shared state, it will be run concurrently and it must not be blocking.
        access(Execute) fun executeTransaction(id: UInt64) {
            let tx = self.borrowTransaction(id: id) ?? 
                panic("Invalid ID: Transaction with id \(id) not found")

            assert (
                tx.status == Status.Executed,
                message: "Invalid ID: Cannot execute transaction with id \(id) because it has incorrect status \(tx.status.rawValue)"
            )

            let transactionHandler = tx.handler.borrow()
                ?? panic("Invalid transaction handler: Could not borrow a reference to the transaction handler")

            emit Executed(
                id: tx.id,
                priority: tx.priority.rawValue,
                executionEffort: tx.executionEffort,
                transactionHandlerOwner: tx.handler.address,
                transactionHandlerTypeIdentifier: transactionHandler.getType().identifier
            )
            
            transactionHandler.executeTransaction(id: id, data: tx.getData())
        }
    }
    
    /// Deposit fees to this contract's account's vault
    access(contract) fun depositFees(from: @FlowToken.Vault) {
        let vaultRef = self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")
        vaultRef.deposit(from: <-from)
    }

    /// Withdraw fees from this contract's account's vault
    access(contract) fun withdrawFees(amount: UFix64): @FlowToken.Vault {
        let vaultRef = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Unable to borrow reference to the default token vault")
            
        return <-vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) fun schedule(
        handlerCap: Capability<auth(Execute) &{TransactionHandler}>,
        data: AnyStruct?,
        timestamp: UFix64,
        priority: Priority,
        executionEffort: UInt64,
        fees: @FlowToken.Vault
    ): @ScheduledTransaction {
        return <-self.sharedScheduler.borrow()!.schedule(
            handlerCap: handlerCap, 
            data: data, 
            timestamp: timestamp, 
            priority: priority, 
            executionEffort: executionEffort, 
            fees: <-fees
        )
    }

    access(all) fun estimate(
        data: AnyStruct?,
        timestamp: UFix64,
        priority: Priority,
        executionEffort: UInt64
    ): EstimatedScheduledTransaction {
        return self.sharedScheduler.borrow()!
            .estimate(
                data: data, 
                timestamp: timestamp, 
                priority: priority, 
                executionEffort: executionEffort,
            )
    }

    access(all) fun cancel(scheduledTx: @ScheduledTransaction): @FlowToken.Vault {
        let id = scheduledTx.id
        destroy scheduledTx
        return <-self.sharedScheduler.borrow()!.cancel(id: id)
    }

    /// getTransactionData returns the transaction data for a given ID
    /// This function can only get the data for a transaction that is currently scheduled or pending execution
    /// because finalized transaction metadata is not stored in the contract
    /// @param id: The ID of the transaction to get the data for
    /// @return: The transaction data for the given ID
    access(all) view fun getTransactionData(id: UInt64): TransactionData? {
        return self.sharedScheduler.borrow()!.getTransaction(id: id)
    }

    access(all) view fun getCanceledTransactions(): [UInt64] {
        return self.sharedScheduler.borrow()!.getCanceledTransactions()
    }

    access(all) view fun getStatus(id: UInt64): Status? {
        return self.sharedScheduler.borrow()!.getStatus(id: id)
    }

    /// getTransactionsForTimeframe returns the IDs of the transactions that are scheduled for a given timeframe
    /// @param startTimestamp: The start timestamp to get the IDs for
    /// @param endTimestamp: The end timestamp to get the IDs for
    /// @return: The IDs of the transactions that are scheduled for the given timeframe
    access(all) fun getTransactionsForTimeframe(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: {UInt8: [UInt64]}} {
        return self.sharedScheduler.borrow()!.getTransactionsForTimeframe(startTimestamp: startTimestamp, endTimestamp: endTimestamp)
    }

    access(all) view fun getSlotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {
        return self.sharedScheduler.borrow()!.getSlotAvailableEffort(timestamp: timestamp, priority: priority)
    }

    access(all) fun getConfig(): {SchedulerConfig} {
        return self.sharedScheduler.borrow()!.getConfig()
    }
    
    /// getSizeOfData takes a transaction's data
    /// argument and stores it in the contract account's storage, 
    /// checking storage used before and after to see how large the data is in MB
    /// If data is nil, the function returns 0.0
    access(all) fun getSizeOfData(_ data: AnyStruct?): UFix64 {
        if data == nil {
            return 0.0
        } else {
            let type = data!.getType()
            if type.isSubtype(of: Type<Number>()) 
            || type.isSubtype(of: Type<Bool>()) 
            || type.isSubtype(of: Type<Address>())
            || type.isSubtype(of: Type<Character>())
            || type.isSubtype(of: Type<Capability>())
            {
                return 0.0
            }
        }
        let storagePath = /storage/dataTemp
        let storageUsedBefore = self.account.storage.used
        self.account.storage.save(data!, to: storagePath)
        let storageUsedAfter = self.account.storage.used
        self.account.storage.load<AnyStruct>(from: storagePath)

        return FlowStorageFees.convertUInt64StorageBytesToUFix64Megabytes(storageUsedAfter.saturatingSubtract(storageUsedBefore))
    }

    access(all) init() {
        self.storagePath = /storage/sharedScheduler
        let scheduler <- create SharedScheduler()
        let oldScheduler <- self.account.storage.load<@AnyResource>(from: self.storagePath)
        destroy oldScheduler
        self.account.storage.save(<-scheduler, to: self.storagePath)
        
        self.sharedScheduler = self.account.capabilities.storage
            .issue<auth(Cancel) &SharedScheduler>(self.storagePath)
    }
}