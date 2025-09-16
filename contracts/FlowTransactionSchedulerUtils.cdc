import "FlowTransactionScheduler"
import "FlowToken"

access(all) contract FlowTransactionSchedulerUtils {

    /// Storage path for Manager resources
    access(all) let managerStoragePath: StoragePath

    /// Public path for Manager resources
    access(all) let managerPublicPath: PublicPath

    /// Entitlements
    access(all) entitlement Owner

    /// Manager resource is meant to provide users and developers with a simple way
    /// to group the scheduled transactions that they own into one place to make it more
    /// convenient to schedule/cancel transactions and get information about the transactions
    /// that are managed.
    /// It stores ScheduledTransaction resources in a dictionary and has other fields
    /// to track the scheduled transactions by timestamp and handler
    ///
    access(all) resource Manager {
        /// Dictionary storing scheduled transactions by their ID
        access(self) var scheduledTransactions: @{UInt64: FlowTransactionScheduler.ScheduledTransaction}

        /// Sorted array of timestamps that this manager has transactions scheduled at
        access(self) var sortedTimestamps: FlowTransactionScheduler.SortedTimestamps

        /// Dictionary storing the IDs of the transactions scheduled at a given timestamp
        access(self) let idsByTimestamp: {UFix64: [UInt64]}

        /// Dictionary storing the IDs of the transactions scheduled using a given handler
        access(self) let idsByHandler: {String: [UInt64]}

        /// Dictionary storing the handlers that this manager has scheduled transactions for at one point
        access(self) let handlers: {String: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>}

        init() {
            self.scheduledTransactions <- {}
            self.sortedTimestamps = FlowTransactionScheduler.SortedTimestamps()
            self.idsByTimestamp = {}
            self.idsByHandler = {}
            self.handlers = {}
        }

        /// scheduleByHandler schedules a transaction by a given handler that has been used before
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param data: Optional data to pass to the transaction when executed
        /// @param timestamp: The timestamp when the transaction should be executed
        /// @param priority: The priority of the transaction (High, Medium, or Low)
        /// @param executionEffort: The execution effort for the transaction
        /// @param fees: A FlowToken vault containing sufficient fees
        /// @return: The ID of the scheduled transaction
        access(Owner) fun scheduleByHandler(
            handlerTypeIdentifier: String,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64 {
            pre {
                self.handlers.containsKey(handlerTypeIdentifier): "Invalid handler type identifier: Handler with type identifier \(handlerTypeIdentifier) not found in manager"
            }
            return self.schedule(handlerCap: self.handlers[handlerTypeIdentifier]!, data: data, timestamp: timestamp, priority: priority, executionEffort: executionEffort, fees: <-fees)
        }

        /// Schedule a transaction and store it in the manager's dictionary
        /// @param handlerCap: A capability to a resource that implements the TransactionHandler interface
        /// @param data: Optional data to pass to the transaction when executed
        /// @param timestamp: The timestamp when the transaction should be executed
        /// @param priority: The priority of the transaction (High, Medium, or Low)
        /// @param executionEffort: The execution effort for the transaction
        /// @param fees: A FlowToken vault containing sufficient fees
        /// @return: The ID of the scheduled transaction
        access(Owner) fun schedule(
            handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64 {
            // Clean up any stale transactions before scheduling a new one
            self.cleanup()

            // Route to the main FlowTransactionScheduler
            let scheduledTransaction <- FlowTransactionScheduler.schedule(
                handlerCap: handlerCap,
                data: data,
                timestamp: timestamp,
                priority: priority,
                executionEffort: executionEffort,
                fees: <-fees
            )

            let id = scheduledTransaction.id
            let handlerRef = handlerCap.borrow()
                ?? panic("Invalid transaction handler: Could not borrow a reference to the transaction handler")
            let handlerTypeIdentifier = handlerRef.getType().identifier

            self.handlers[handlerTypeIdentifier] = handlerCap

            // Store the transaction in our dictionary
            self.scheduledTransactions[scheduledTransaction.id] <-! scheduledTransaction

            self.sortedTimestamps.add(timestamp: timestamp)

            if let ids = self.idsByTimestamp[timestamp] {
                ids.append(id)
                self.idsByTimestamp[timestamp] = ids
            } else {
                self.idsByTimestamp[timestamp] = [id]
            }

            if let ids = self.idsByHandler[handlerTypeIdentifier] {
                ids.append(id)
                self.idsByHandler[handlerTypeIdentifier] = ids
            } else {
                self.idsByHandler[handlerTypeIdentifier] = [id]
            }

            return id
        }

        /// Cancel a scheduled transaction by its ID
        /// @param id: The ID of the transaction to cancel
        /// @return: A FlowToken vault containing the refunded fees
        access(Owner) fun cancel(id: UInt64): @FlowToken.Vault {
            // Remove the transaction from our dictionary
            let tx <- self.scheduledTransactions.remove(key: id)
                ?? panic("Invalid ID: Transaction with ID \(id) not found in manager")

            let transactionData = FlowTransactionScheduler.getTransactionData(id: id)
                ?? panic("Invalid ID: Transaction with ID \(id) not found in scheduler")

            self.removeID(id: id, timestamp: tx.timestamp, handlerTypeIdentifier: tx.handlerTypeIdentifier)

            // Cancel the transaction through the main scheduler
            let refundedFees <- FlowTransactionScheduler.cancel(scheduledTx: <-tx!)

            return <-refundedFees
        }

        /// Remove an ID from the manager's fields
        /// @param id: The ID of the transaction to remove
        /// @param timestamp: The timestamp of the transaction to remove
        /// @param handlerTypeIdentifier: The type identifier of the handler of the transaction to remove
        access(self) fun removeID(id: UInt64, timestamp: UFix64, handlerTypeIdentifier: String) {
            if let ids = self.idsByTimestamp[timestamp] {
                let index = ids.firstIndex(of: id)
                ids.remove(at: index!)
                if ids.length == 0 {
                    self.idsByTimestamp.remove(key: timestamp)
                } else {
                    self.idsByTimestamp[timestamp] = ids
                }
            }

            if let ids = self.idsByHandler[handlerTypeIdentifier] {
                let index = ids.firstIndex(of: id)
                ids.remove(at: index!)
                self.idsByHandler[handlerTypeIdentifier] = ids
            }
        }

        /// Clean up transactions that are no longer valid (return nil or Unknown status)
        /// This removes and destroys transactions that have been executed, canceled, or are otherwise invalid
        /// @return: The transactions that were cleaned up (removed from the manager)
        access(Owner) fun cleanup(): [UInt64] {
            let currentTimestamp = getCurrentBlock().timestamp
            var transactionsToRemove: [UInt64] = []

            let pastTimestamps = self.sortedTimestamps.getBefore(current: currentTimestamp)
            for timestamp in pastTimestamps {
                let ids = self.idsByTimestamp[timestamp] ?? []
                for id in ids {
                    let status = FlowTransactionScheduler.getStatus(id: id)
                    if status == nil || status == FlowTransactionScheduler.Status.Unknown {
                        transactionsToRemove.append(id)
                    }
                }
            }

            // Then remove and destroy the identified transactions
            for id in transactionsToRemove {
                if let tx <- self.scheduledTransactions.remove(key: id) {
                    self.removeID(id: id, timestamp: tx.timestamp, handlerTypeIdentifier: tx.handlerTypeIdentifier)
                    destroy tx
                }
            }

            return transactionsToRemove
        }

        /// Get transaction data by its ID
        /// @param id: The ID of the transaction to retrieve
        /// @return: The transaction data from FlowTransactionScheduler, or nil if not found
        access(all) view fun getTransactionData(id: UInt64): FlowTransactionScheduler.TransactionData? {
            if self.scheduledTransactions.containsKey(id) {
                return FlowTransactionScheduler.getTransactionData(id: id)
            }
            return nil
        }

        /// Get an un-entitled reference to a transaction handler of a given ID
        /// @param id: The ID of the transaction to retrieve
        /// @return: A reference to the transaction handler, or nil if not found
        access(all) view fun getTransactionHandler(id: UInt64): &{FlowTransactionScheduler.TransactionHandler}? {
            let txData = self.getTransactionData(id: id)
            return txData?.getUnentitledHandlerReference()
        }

        /// Get all the handler type identifiers that the manager has transactions scheduled for
        /// @return: An array of all handler type identifiers
        access(all) view fun getHandlerTypeIdentifiers(): [String] {
            return self.handlers.keys
        }

        /// Get an un-entitled reference to a handler by a given type identifier
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @return: An un-entitled reference to the handler, or nil if not found
        access(all) view fun getHandlerByTypeIdentifier(handlerTypeIdentifier: String): &{FlowTransactionScheduler.TransactionHandler}? {
            return self.handlers[handlerTypeIdentifier]?.borrow() as? &{FlowTransactionScheduler.TransactionHandler}
        }

        /// Get all the views that a handler implements
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @return: An array of all views
        access(all) fun getHandlerViews(handlerTypeIdentifier: String): [Type] {
            if let handler = self.handlers[handlerTypeIdentifier]?.borrow() {
                if let ref = handler {
                    return ref.getViews()
                }
            }
            return []
        }

        /// Resolve a view for a handler by a given type identifier
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param viewType: The type of the view to resolve
        /// @return: The resolved view, or nil if not found
        access(all) fun resolveHandlerView(handlerTypeIdentifier: String, viewType: Type): AnyStruct? {
            if let handler = self.handlers[handlerTypeIdentifier]?.borrow() {
                if let ref = handler {
                    return ref.resolveView(viewType)
                }
            }
            return nil
        }

        /// Get all the views that a handler implements from a given transaction ID
        /// @param transactionId: The ID of the transaction
        /// @return: An array of all views
        access(all) fun getHandlerViewsFromTransactionID(transactionId: UInt64): [Type] {
            if let handler = self.getTransactionHandler(id: transactionId) {
                return handler.getViews()
            }
            return []
        }

        /// Resolve a view for a handler from a given transaction ID
        /// @param transactionId: The ID of the transaction
        /// @param viewType: The type of the view to resolve
        /// @return: The resolved view, or nil if not found
        access(all) fun resolveHandlerViewFromTransactionID(transactionId: UInt64, viewType: Type): AnyStruct? {
            if let handler = self.getTransactionHandler(id: transactionId) {
                return handler.resolveView(viewType)
            }
            return nil
        }

        /// Get all transaction IDs stored in the manager
        /// @return: An array of all transaction IDs
        access(all) view fun getTransactionIDs(): [UInt64] {
            return self.scheduledTransactions.keys
        }

        /// Get all transaction IDs stored in the manager by a given handler
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @return: An array of all transaction IDs
        access(all) view fun getTransactionIDsByHandler(handlerTypeIdentifier: String): [UInt64] {
            return self.idsByHandler[handlerTypeIdentifier] ?? []
        }

        /// Get all transaction IDs stored in the manager by a given timestamp
        /// @param timestamp: The timestamp
        /// @return: An array of all transaction IDs
        access(all) view fun getTransactionIDsByTimestamp(timestamp: UFix64): [UInt64] {
            return self.idsByTimestamp[timestamp] ?? []
        }

        /// Get all the timestamps and IDs from a given range of timestamps
        /// @param startTimestamp: The start timestamp
        /// @param endTimestamp: The end timestamp
        /// @return: A dictionary of timestamps and IDs
        access(all) fun getTransactionIDsByTimestampRange(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: [UInt64]} {
            var transactionsInTimeframe: {UFix64: [UInt64]} = {}
            
            // Validate input parameters
            if startTimestamp > endTimestamp {
                return transactionsInTimeframe
            }
            
            // Get all timestamps that fall within the specified range
            let allTimestampsBeforeEnd = self.sortedTimestamps.getBefore(current: endTimestamp)
            
            for timestamp in allTimestampsBeforeEnd {
                // Check if this timestamp falls within our range
                if timestamp < startTimestamp { continue }
                
                var timestampTransactions: [UInt64] = self.idsByTimestamp[timestamp] ?? []
                
                if timestampTransactions.length > 0 {
                    transactionsInTimeframe[timestamp] = timestampTransactions
                }
            }
            
            return transactionsInTimeframe
        }

        /// Get the status of a transaction by its ID
        /// @param id: The ID of the transaction
        /// @return: The status of the transaction, or Status.Unknown if not found in manager
        access(all) view fun getTransactionStatus(id: UInt64): FlowTransactionScheduler.Status? {
            if self.scheduledTransactions.containsKey(id) {
                return FlowTransactionScheduler.getStatus(id: id)
            }
            return FlowTransactionScheduler.Status.Unknown
        }
    }

    /// Create a new Manager instance
    /// @return: A new Manager resource
    access(all) fun createManager(): @Manager {
        return <-create Manager()
    }

    access(all) init() {
        self.managerStoragePath = /storage/flowTransactionSchedulerManager
        self.managerPublicPath = /public/flowTransactionSchedulerManager
    }

    /// Get a public reference to a manager at the given address
    /// @param address: The address of the manager
    /// @return: A public reference to the manager
    access(all) view fun getManager(address: Address): &Manager? {
        return getAccount(address).capabilities.borrow<&Manager>(self.managerPublicPath)
    }

    /********************************************
    
    Scheduled Transactions Metadata Views
    
    ***********************************************/

    /// HandlerData is a struct that contains the important data for a handler
    /// that is used to identify the handler and its capabilities
    /// The scheduled transactions smart contract will use this data to identify the handler
    /// and its capabilities when scheduling a transaction and executing the transaction
    /// The information from this view will be used in the events so it is very important that it is accurate
    access(all) struct HandlerData {

        // short name of the handler
        access(all) let name: String

        // description of what the handler does
        access(all) let description: String

        // path where this handler should be stored in storage
        access(all) let storagePath: StoragePath

        // path where this handler's public capability should be found
        access(all) let publicPath: PublicPath

        init(
            name: String,
            description: String,
            storagePath: StoragePath,
            publicPath: PublicPath
        ) {
            self.name = name
            self.description = description
            self.storagePath = storagePath
            self.publicPath = publicPath
        }
    }
}