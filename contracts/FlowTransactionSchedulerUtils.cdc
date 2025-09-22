import "FlowTransactionScheduler"
import "FlowToken"

/// FlowTransactionSchedulerUtils provides utility functionality for working with scheduled transactions
/// on the Flow blockchain. Currently, it only includes a Manager resource for managing scheduled transactions.
///
/// In the future, this contract will be updated to include more functionality 
/// to make it more convenient for working with scheduled transactions for various use cases.
///
access(all) contract FlowTransactionSchedulerUtils {

    /// Storage path for Manager resources
    access(all) let managerStoragePath: StoragePath

    /// Public path for Manager resources
    access(all) let managerPublicPath: PublicPath

    /// Entitlements
    access(all) entitlement Owner

    /// HandlerInfo is a struct that stores information about a single transaction handler
    /// that has been used to schedule transactions.
    /// It is stored in the manager's handlerInfos dictionary.
    /// It stores the type identifier of the handler, the transaction IDs that have been scheduled for it,
    /// and a capability to the handler.
    /// The capability is used to borrow a reference to the handler when needed.
    /// The transaction IDs are used to track the transactions that have been scheduled for the handler.
    /// The type identifier is used to differentiate between handlers of the same type.
    access(all) struct HandlerInfo {
        /// The type identifier of the handler
        access(all) let typeIdentifier: String

        /// The transaction IDs that have been scheduled for the handler
        access(all) let transactionIDs: [UInt64]

        /// The capability to the handler
        access(contract) let capability: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>

        init(typeIdentifier: String, capability: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>) {
            self.typeIdentifier = typeIdentifier
            self.capability = capability
            self.transactionIDs = []
        }

        /// Add a transaction ID to the handler's transaction IDs
        /// @param id: The ID of the transaction to add
        access(contract) fun addTransactionID(id: UInt64) {
            self.transactionIDs.append(id)
        }

        /// Remove a transaction ID from the handler's transaction IDs
        /// @param id: The ID of the transaction to remove
        access(contract) fun removeTransactionID(id: UInt64) {
            let index = self.transactionIDs.firstIndex(of: id)
            if index != nil {
                self.transactionIDs.remove(at: index!)
            }
        }

        /// Borrow an un-entitled reference to the handler
        /// @return: A reference to the handler, or nil if not found
        access(contract) view fun borrow(): &{FlowTransactionScheduler.TransactionHandler}? {
            return self.capability.borrow() as? &{FlowTransactionScheduler.TransactionHandler}
        }
    }

    /// The Manager resource offers a convenient way for users and developers to
    /// group, schedule, cancel, and query scheduled transactions through a single resource.
    /// The Manager is defined as an interface to allow for multiple implementations of the manager
    /// and to support upgrades that may be needed in the future to add additional storage fields and functionality.
    /// 
    /// Key features:
    /// - Organizes scheduled and executed transactions by handler type and timestamp
    /// - Simplified scheduling interface that works with previously used transaction handlers
    /// - Transaction tracking and querying capabilities by handler, timestamp, and ID
    /// - Handler metadata and view resolution support
    access(all) resource interface Manager {

        /// Schedules a transaction by passing the arguments directly
        /// to the FlowTransactionScheduler schedule function
        /// This also should store the information about the transaction
        /// and handler in the manager's fields
        access(Owner) fun schedule(
            handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64

        /// Schedules a transaction that uses a previously used handler
        /// This should also store the information about the transaction
        /// and handler in the manager's fields
        access(Owner) fun scheduleByHandler(
            handlerTypeIdentifier: String,
            handlerUUID: UInt64?,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64

        /// Cancels a scheduled transaction by its ID
        /// This should also remove the information about the transaction from the manager's fields
        access(Owner) fun cancel(id: UInt64): @FlowToken.Vault
        
        access(all) view fun getTransactionData(_ id: UInt64): FlowTransactionScheduler.TransactionData?
        access(all) view fun borrowTransactionHandlerForID(_ id: UInt64): &{FlowTransactionScheduler.TransactionHandler}?
        access(all) fun getHandlerTypeIdentifiers(): {String: [UInt64]}
        access(all) view fun borrowHandler(handlerTypeIdentifier: String, handlerUUID: UInt64?): &{FlowTransactionScheduler.TransactionHandler}?
        access(all) fun getHandlerViews(handlerTypeIdentifier: String, handlerUUID: UInt64?): [Type] 
        access(all) fun resolveHandlerView(handlerTypeIdentifier: String, handlerUUID: UInt64?, viewType: Type): AnyStruct?      
        access(all) fun getHandlerViewsFromTransactionID(_ id: UInt64): [Type]
        access(all) fun resolveHandlerViewFromTransactionID(_ id: UInt64, viewType: Type): AnyStruct? 
        access(all) view fun getTransactionIDs(): [UInt64]
        access(all) view fun getTransactionIDsByHandler(handlerTypeIdentifier: String, handlerUUID: UInt64?): [UInt64]
        access(all) view fun getTransactionIDsByTimestamp(_ timestamp: UFix64): [UInt64]
        access(all) fun getTransactionIDsByTimestampRange(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: [UInt64]}
        access(all) view fun getTransactionStatus(id: UInt64): FlowTransactionScheduler.Status?
    }

    /// Manager resource is meant to provide users and developers with a simple way
    /// to group the scheduled transactions that they own into one place to make it more
    /// convenient to schedule/cancel transactions and get information about the transactions
    /// that are managed.
    /// It stores ScheduledTransaction resources in a dictionary and has other fields
    /// to track the scheduled transactions by timestamp and handler
    ///
    access(all) resource ManagerV1: Manager {
        /// Dictionary storing scheduled transactions by their ID
        access(self) var scheduledTransactions: @{UInt64: FlowTransactionScheduler.ScheduledTransaction}

        /// Sorted array of timestamps that this manager has transactions scheduled at
        access(self) var sortedTimestamps: FlowTransactionScheduler.SortedTimestamps

        /// Dictionary storing the IDs of the transactions scheduled at a given timestamp
        access(self) let idsByTimestamp: {UFix64: [UInt64]}

        /// Dictionary storing the handler UUIDs for transaction IDs
        access(self) let handlerUUIDsByTransactionID: {UInt64: UInt64}

        /// Dictionary storing the handlers that this manager has scheduled transactions for at one point
        /// The field differentiates between handlers of the same type by their UUID because there can be multiple handlers of the same type
        /// that perform the same functionality but maybe do it for different purposes
        /// so it is important to differentiate between them in case the user needs to retrieve a specific handler
        /// The metadata for each handler that potentially includes information about the handler's purpose
        /// can be retrieved from the handler's reference via the getViews() and resolveView() functions
        access(self) let handlerInfos: {String: {UInt64: HandlerInfo}}

        init() {
            self.scheduledTransactions <- {}
            self.sortedTimestamps = FlowTransactionScheduler.SortedTimestamps()
            self.idsByTimestamp = {}
            self.handlerUUIDsByTransactionID = {}
            self.handlerInfos = {}
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
            handlerUUID: UInt64?,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64 {
            pre {
                self.handlerInfos.containsKey(handlerTypeIdentifier): "Invalid handler type identifier: Handler with type identifier \(handlerTypeIdentifier) not found in manager"
                handlerUUID == nil || self.handlerInfos[handlerTypeIdentifier]!.containsKey(handlerUUID!): "Invalid handler UUID: Handler with type identifier \(handlerTypeIdentifier) and UUID \(handlerUUID!) not found in manager"
            }
            let handlers = self.handlerInfos[handlerTypeIdentifier]!
            var id = handlerUUID
            if handlerUUID == nil {
                assert (
                    handlers.keys.length == 1,
                    message: "Invalid handler UUID: Handler with type identifier \(handlerTypeIdentifier) has more than one UUID, but no UUID was provided"
                )
                id = handlers.keys[0]
            }
            return self.schedule(handlerCap: handlers[id!]!.capability, data: data, timestamp: timestamp, priority: priority, executionEffort: executionEffort, fees: <-fees)
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

            // Store the handler capability in our dictionary for later retrieval
            let id = scheduledTransaction.id
            let handlerRef = handlerCap.borrow()
                ?? panic("Invalid transaction handler: Could not borrow a reference to the transaction handler")
            let handlerTypeIdentifier = handlerRef.getType().identifier
            let handlerUUID = handlerRef.uuid

            self.handlerUUIDsByTransactionID[id] = handlerUUID

            // Store the handler capability in the handlers dictionary for later retrieval
            if let handlers = self.handlerInfos[handlerTypeIdentifier] {
                if let handlerInfo = handlers[handlerUUID] {
                    handlerInfo.addTransactionID(id: id)
                    handlers[handlerUUID] = handlerInfo
                } else {
                    let handlerInfo = HandlerInfo(typeIdentifier: handlerTypeIdentifier, capability: handlerCap)
                    handlerInfo.addTransactionID(id: id)
                    handlers[handlerUUID] = handlerInfo
                }
                self.handlerInfos[handlerTypeIdentifier] = handlers
            } else {
                let handlerInfo = HandlerInfo(typeIdentifier: handlerTypeIdentifier, capability: handlerCap)
                handlerInfo.addTransactionID(id: id)
                let uuidDictionary: {UInt64: HandlerInfo} = {handlerUUID: handlerInfo}
                self.handlerInfos[handlerTypeIdentifier] = uuidDictionary
            }

            // Store the transaction in the transactions dictionary
            self.scheduledTransactions[scheduledTransaction.id] <-! scheduledTransaction

            // Add the transaction to the sorted timestamps array
            self.sortedTimestamps.add(timestamp: timestamp)

            // Store the transaction in the ids by timestamp dictionary
            if let ids = self.idsByTimestamp[timestamp] {
                ids.append(id)
                self.idsByTimestamp[timestamp] = ids
            } else {
                self.idsByTimestamp[timestamp] = [id]
            }

            return id
        }

        /// Cancel a scheduled transaction by its ID
        /// @param id: The ID of the transaction to cancel
        /// @return: A FlowToken vault containing the refunded fees
        access(Owner) fun cancel(id: UInt64): @FlowToken.Vault {
            // Remove the transaction from the transactions dictionary
            let tx <- self.scheduledTransactions.remove(key: id)
                ?? panic("Invalid ID: Transaction with ID \(id) not found in manager")

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

            let handlerUUID = self.handlerUUIDsByTransactionID.remove(key: id)
                ?? panic("Invalid ID: Transaction with ID \(id) not found in manager")

            // Remove the transaction ID from the handler info array
            if let handlers = self.handlerInfos[handlerTypeIdentifier] {
                if let handlerInfo = handlers[handlerUUID] {
                    handlerInfo.removeTransactionID(id: id)
                    handlers[handlerUUID] = handlerInfo
                }
                self.handlerInfos[handlerTypeIdentifier] = handlers
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

        /// Remove a handler capability from the manager
        /// The specified handler must not have any transactions scheduled for it
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param handlerUUID: The UUID of the handler
        access(Owner) fun removeHandler(handlerTypeIdentifier: String, handlerUUID: UInt64?) {
            // Make sure the handler exists
            if let handlers = self.handlerInfos[handlerTypeIdentifier] {
                var id = handlerUUID
                // If no UUID is provided, there must be only one handler of the type
                if handlerUUID == nil {
                    if handlers.keys.length > 1 {
                        // No-op if we don't know which UUID to remove
                        return
                    } else if handlers.keys.length == 0 {
                        self.handlerInfos.remove(key: handlerTypeIdentifier)
                        return
                    }
                    id = handlers.keys[0]
                }
                // Make sure the handler has no transactions scheduled for it
                if let handlerInfo = handlers[id!] {
                    if handlerInfo.transactionIDs.length > 0 {
                        return
                    }
                }
                // Remove the handler uuid from the handlers dictionary
                handlers.remove(key: id!)

                // If there are no more handlers of the type, remove the type from the handlers dictionary
                if handlers.keys.length == 0 {
                    self.handlerInfos.remove(key: handlerTypeIdentifier)
                } else {
                    self.handlerInfos[handlerTypeIdentifier] = handlers
                }
            }
        }

        /// Get transaction data by its ID
        /// @param id: The ID of the transaction to retrieve
        /// @return: The transaction data from FlowTransactionScheduler, or nil if not found
        access(all) view fun getTransactionData(_ id: UInt64): FlowTransactionScheduler.TransactionData? {
            if self.scheduledTransactions.containsKey(id) {
                return FlowTransactionScheduler.getTransactionData(id: id)
            }
            return nil
        }

        /// Get an un-entitled reference to a transaction handler of a given ID
        /// @param id: The ID of the transaction to retrieve
        /// @return: A reference to the transaction handler, or nil if not found
        access(all) view fun borrowTransactionHandlerForID(_ id: UInt64): &{FlowTransactionScheduler.TransactionHandler}? {
            let txData = self.getTransactionData(id)
            return txData?.borrowHandler()
        }

        /// Get all the handler type identifiers that the manager has scheduled transactions for
        /// @return: A dictionary of all handler type identifiers and their UUIDs
        access(all) fun getHandlerTypeIdentifiers(): {String: [UInt64]} {
            var handlerTypeIdentifiers: {String: [UInt64]} = {}
            for handlerTypeIdentifier in self.handlerInfos.keys {
                let handlerUUIDs: [UInt64] = []
                let handlerTypes = self.handlerInfos[handlerTypeIdentifier]!
                for uuid in handlerTypes.keys {
                    let handlerInfo = handlerTypes[uuid]!
                    if !handlerInfo.capability.check() {
                        continue
                    }
                    handlerUUIDs.append(uuid)
                }
                handlerTypeIdentifiers[handlerTypeIdentifier] = handlerUUIDs
            }
            return handlerTypeIdentifiers
        }

        /// Get an un-entitled reference to a handler by a given type identifier
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param handlerUUID: The UUID of the handler, if nil, there must be only one handler of the type, otherwise nil will be returned
        /// @return: An un-entitled reference to the handler, or nil if not found
        access(all) view fun borrowHandler(handlerTypeIdentifier: String, handlerUUID: UInt64?): &{FlowTransactionScheduler.TransactionHandler}? {
            if let handlers = self.handlerInfos[handlerTypeIdentifier] {
                if handlerUUID != nil {
                    if let handlerInfo = handlers[handlerUUID!] {
                        return handlerInfo.borrow()
                    } 
                } else if handlers.keys.length == 1 {
                    // If no uuid is provided, we can just default to the only handler uuid
                    return handlers[handlers.keys[0]]!.borrow()
                }
            }
            return nil
        }

        /// Get all the views that a handler implements
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param handlerUUID: The UUID of the handler, if nil, there must be only one handler of the type, otherwise nil will be returned
        /// @return: An array of all views
        access(all) fun getHandlerViews(handlerTypeIdentifier: String, handlerUUID: UInt64?): [Type] {
            if let handler = self.borrowHandler(handlerTypeIdentifier: handlerTypeIdentifier, handlerUUID: handlerUUID) {
                return handler.getViews()
            }
            return []
        }

        /// Resolve a view for a handler by a given type identifier
        /// @param handlerTypeIdentifier: The type identifier of the handler
        /// @param handlerUUID: The UUID of the handler, if nil, there must be only one handler of the type, otherwise nil will be returned
        /// @param viewType: The type of the view to resolve
        /// @return: The resolved view, or nil if not found
        access(all) fun resolveHandlerView(handlerTypeIdentifier: String, handlerUUID: UInt64?, viewType: Type): AnyStruct? {
            if let handler = self.borrowHandler(handlerTypeIdentifier: handlerTypeIdentifier, handlerUUID: handlerUUID) {
                return handler.resolveView(viewType)
            }
            return nil
        }

        /// Get all the views that a handler implements from a given transaction ID
        /// @param transactionId: The ID of the transaction
        /// @return: An array of all views
        access(all) fun getHandlerViewsFromTransactionID(_ id: UInt64): [Type] {
            if let handler = self.borrowTransactionHandlerForID(id) {
                return handler.getViews()
            }
            return []
        }

        /// Resolve a view for a handler from a given transaction ID
        /// @param transactionId: The ID of the transaction
        /// @param viewType: The type of the view to resolve
        /// @return: The resolved view, or nil if not found
        access(all) fun resolveHandlerViewFromTransactionID(_ id: UInt64, viewType: Type): AnyStruct? {
            if let handler = self.borrowTransactionHandlerForID(id) {
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
        access(all) view fun getTransactionIDsByHandler(handlerTypeIdentifier: String, handlerUUID: UInt64?): [UInt64] {
            if let handlers = self.handlerInfos[handlerTypeIdentifier] {
                if handlerUUID != nil {
                    if let handlerInfo = handlers[handlerUUID!] {
                        return handlerInfo.transactionIDs
                    } 
                } else if handlers.keys.length == 1 {
                    // If no uuid is provided, we can just default to the only handler uuid
                    return handlers[handlers.keys[0]]!.transactionIDs
                }
            }
            return []
        }

        /// Get all transaction IDs stored in the manager by a given timestamp
        /// @param timestamp: The timestamp
        /// @return: An array of all transaction IDs
        access(all) view fun getTransactionIDsByTimestamp(_ timestamp: UFix64): [UInt64] {
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
    access(all) fun createManager(): @{Manager} {
        return <-create ManagerV1()
    }

    access(all) init() {
        self.managerStoragePath = /storage/flowTransactionSchedulerManager
        self.managerPublicPath = /public/flowTransactionSchedulerManager
    }

    /// Get a public reference to a manager at the given address
    /// @param address: The address of the manager
    /// @return: A public reference to the manager
    access(all) view fun borrowManager(at: Address): &{Manager}? {
        return getAccount(at).capabilities.borrow<&{Manager}>(self.managerPublicPath)
    }

    /********************************************
    
    Scheduled Transactions Metadata Views
    
    ***********************************************/

}