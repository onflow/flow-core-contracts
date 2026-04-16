import FlowTransactionScheduler from 0xe467b9dd11fa00df
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import EVM from 0xe467b9dd11fa00df
import MetadataViews from 0x1d7e57aa55817448

/// FlowTransactionSchedulerUtils provides utility functionality for working with scheduled transactions
/// on the Flow blockchain.
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
        access(all) view fun getSortedTimestamps(): FlowTransactionScheduler.SortedTimestamps
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
            let actualTimestamp = scheduledTransaction.timestamp
            let handlerRef = handlerCap.borrow()
                ?? panic("Invalid transaction handler: Could not borrow a reference to the transaction handler")
            let handlerTypeIdentifier = handlerRef.getType().identifier
            let handlerUUID = handlerRef.uuid

            self.handlerUUIDsByTransactionID[id] = handlerUUID

            // Store the handler capability in the handlers dictionary for later retrieval
            if self.handlerInfos[handlerTypeIdentifier] != nil {
                let handlers = &self.handlerInfos[handlerTypeIdentifier]! as auth(Mutate) &{UInt64: HandlerInfo}
                if let handlerInfo = handlers[handlerUUID] {
                    handlerInfo.addTransactionID(id: id)
                } else {
                    let handlerInfo = HandlerInfo(typeIdentifier: handlerTypeIdentifier, capability: handlerCap)
                    handlerInfo.addTransactionID(id: id)
                    handlers[handlerUUID] = handlerInfo
                }
            } else {
                let handlerInfo = HandlerInfo(typeIdentifier: handlerTypeIdentifier, capability: handlerCap)
                handlerInfo.addTransactionID(id: id)
                let uuidDictionary: {UInt64: HandlerInfo} = {handlerUUID: handlerInfo}
                self.handlerInfos[handlerTypeIdentifier] = uuidDictionary
            }

            // Store the transaction in the transactions dictionary
            self.scheduledTransactions[scheduledTransaction.id] <-! scheduledTransaction

            // Add the transaction to the sorted timestamps array
            self.sortedTimestamps.add(timestamp: actualTimestamp)

            // Store the transaction in the ids by timestamp dictionary
            if self.idsByTimestamp[actualTimestamp] != nil {
                let ids = &self.idsByTimestamp[actualTimestamp]! as auth(Mutate) &[UInt64]
                ids.append(id)
            } else {
                self.idsByTimestamp[actualTimestamp] = [id]
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
            pre {
                self.handlerInfos.containsKey(handlerTypeIdentifier): "Invalid handler type identifier: Handler with type identifier \(handlerTypeIdentifier) not found in manager"
            }

            if self.idsByTimestamp.containsKey(timestamp) {
                let ids = &self.idsByTimestamp[timestamp]! as auth(Mutate) &[UInt64]
                let index = ids.firstIndex(of: id)
                ids.remove(at: index!)
                if ids.length == 0 {
                    self.idsByTimestamp.remove(key: timestamp)
                    self.sortedTimestamps.remove(timestamp: timestamp)
                }
            }

            if let handlerUUID = self.handlerUUIDsByTransactionID.remove(key: id) {
                // Remove the transaction ID from the handler info array
                let handlers = &self.handlerInfos[handlerTypeIdentifier]! as auth(Mutate) &{UInt64: HandlerInfo}
                if let handlerInfo = handlers[handlerUUID] {
                    handlerInfo.removeTransactionID(id: id)
                }
            }
        }

        /// Clean up transactions that are no longer valid (return nil or Unknown status)
        /// This removes and destroys transactions that have been executed, canceled, or are otherwise invalid
        /// @return: The transactions that were cleaned up (removed from the manager)
        access(Owner) fun cleanup(): [UInt64] {
            let currentTimestamp = getCurrentBlock().timestamp
            var transactionsToRemove: {UInt64: UFix64} = {}

            let pastTimestamps = self.sortedTimestamps.getBefore(current: currentTimestamp)
            for timestamp in pastTimestamps {
                let ids = self.idsByTimestamp[timestamp] ?? []
                if ids.length == 0 {
                    self.sortedTimestamps.remove(timestamp: timestamp)
                    continue
                }
                for id in ids {
                    let status = FlowTransactionScheduler.getStatus(id: id)
                    if status == nil || status! != FlowTransactionScheduler.Status.Scheduled {
                        transactionsToRemove[id] = timestamp
                        // Need to temporarily limit the number of transactions to remove
                        // because some managers on mainnet have already hit the limit and we need to batch them
                        // to make sure they get cleaned up properly
                        // This will be removed eventually
                        if transactionsToRemove.length > 50 {
                            break
                        }
                    }
                }
            }

            // Then remove and destroy the identified transactions
            for id in transactionsToRemove.keys {
                if let tx <- self.scheduledTransactions.remove(key: id) {
                    self.removeID(id: id, timestamp: transactionsToRemove[id]!, handlerTypeIdentifier: tx.handlerTypeIdentifier)
                    destroy tx
                }
            }

            return transactionsToRemove.keys
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

        /// Gets the sorted timestamps struct
        /// @return: The sorted timestamps struct
        access(all) view fun getSortedTimestamps(): FlowTransactionScheduler.SortedTimestamps {
            return self.sortedTimestamps
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

    /*********************************************
    
    COA Handler Utils

    **********************************************/

    access(all) event COAHandlerExecutionError(id: UInt64, owner: Address?, coaAddress: String?, errorMessage: String)

    access(all) view fun coaHandlerStoragePath(): StoragePath {
        return /storage/coaScheduledTransactionHandler
    }

    access(all) view fun coaHandlerPublicPath(): PublicPath {
        return /public/coaScheduledTransactionHandler
    }

    /// COATransactionHandler is a resource that wraps a capability to a COA (Cadence Owned Account)
    /// and implements the TransactionHandler interface to allow scheduling transactions for COAs.
    /// This handler enables users to schedule transactions that will be executed on behalf of their COA.
    access(all) resource COATransactionHandler: FlowTransactionScheduler.TransactionHandler {
        /// The capability to the COA resource
        access(self) let coaCapability: Capability<auth(EVM.Owner) &EVM.CadenceOwnedAccount>

        /// The capability to the FlowToken vault
        access(self) let flowTokenVaultCapability: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>

        init(coaCapability: Capability<auth(EVM.Owner) &EVM.CadenceOwnedAccount>,
             flowTokenVaultCapability: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
        )
        {
            pre {
                coaCapability.check(): "COA capability is invalid or expired"
                flowTokenVaultCapability.check(): "FlowToken vault capability is invalid or expired"
            }
            self.coaCapability = coaCapability
            self.flowTokenVaultCapability = flowTokenVaultCapability
        }

        access(self) fun emitError(id: UInt64, errorMessage: String) {
            let coa = self.coaCapability.borrow()!
            emit COAHandlerExecutionError(id: id, owner: self.owner?.address, coaAddress: coa.address().toString(),
                                          errorMessage: errorMessage)
        }

        /// Execute the scheduled transaction using the COA
        /// @param id: The ID of the scheduled transaction
        /// @param data: Optional data passed to the transaction execution. In this case, the data must be a COAHandlerParams struct with valid values.
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {

            // Borrow the COA capability
            let coa = self.coaCapability.borrow()
            if coa == nil {
                emit COAHandlerExecutionError(id: id, owner: self.owner?.address ?? Address(0x0), coaAddress: nil,
                                              errorMessage: "COA capability is invalid or expired for scheduled transaction with ID \(id)")
                return
            }

            // Parse the data into a list of COAHandlerParams
            // If the data is a single COAHandlerParams struct, wrap it in a list
            var params: [COAHandlerParams]? = data as? [COAHandlerParams]
            if params == nil {
                if let param = data as? COAHandlerParams {
                    params = [param]
                }
            }

            // Iterate through all the COA transactions and execute them all
            // If revertOnFailure is true for a transaction and any part of it fails, the entire scheduled transaction will be reverted
            // If not but a part of the transaction fails, an error event will be emitted but the scheduled transaction will continue to execute the next transaction
            //
            if let transactions = params {
                for index, txParams in transactions {
                    switch txParams.txType {
                        case COAHandlerTxType.DepositFLOW:
                            let vault = self.flowTokenVaultCapability.borrow()
                            if vault == nil {
                                if !txParams.revertOnFailure {
                                    self.emitError(id: id, errorMessage: "FlowToken vault capability is invalid or expired for scheduled transaction with ID \(id) and index \(index)")
                                    continue
                                } else {
                                    panic("FlowToken vault capability is invalid or expired for scheduled transaction with ID \(id) and index \(index)")
                                }
                            }

                            if txParams.amount! > vault!.balance && !txParams.revertOnFailure {
                                self.emitError(id: id, errorMessage: "Insufficient FLOW in FlowToken vault for deposit into COA for scheduled transaction with ID \(id) and index \(index)")
                                continue
                            }

                            // Deposit the FLOW into the COA vault. If there isn't enough FLOW in the vault,
                            //the transaction will be reverted because we know revertOnFailure is true
                            coa!.deposit(from: <-vault!.withdraw(amount: txParams.amount!) as! @FlowToken.Vault)
                        case COAHandlerTxType.WithdrawFLOW:
                            let vault = self.flowTokenVaultCapability.borrow()
                            if vault == nil {
                                if !txParams.revertOnFailure {
                                    self.emitError(id: id, errorMessage: "FlowToken vault capability is invalid or expired for scheduled transaction with ID \(id) and index \(index)")
                                    continue
                                } else {
                                    panic("FlowToken vault capability is invalid or expired for scheduled transaction with ID \(id) and index \(index)")
                                }
                            }

                            let amount = EVM.Balance(attoflow: 0)
                            amount.setFLOW(flow: txParams.amount!)

                            if amount.attoflow > coa!.balance().attoflow && !txParams.revertOnFailure {
                                self.emitError(id: id, errorMessage: "Insufficient FLOW in COA vault for withdrawal from COA for scheduled transaction with ID \(id) and index \(index)")
                                continue
                            }

                            // Withdraw the FLOW from the COA vault. If there isn't enough FLOW in the COA,
                            // the transaction will be reverted because we know revertOnFailure is true
                            vault!.deposit(from: <-coa!.withdraw(balance: amount))
                        case COAHandlerTxType.Call:
                            let result = coa!.call(to: txParams.callToEVMAddress!, data: txParams.data!, gasLimit: txParams.gasLimit!, value: txParams.value!)

                            if result.status != EVM.Status.successful {
                                if !txParams.revertOnFailure {
                                    self.emitError(id: id, errorMessage: "EVM call failed for scheduled transaction with ID \(id) and index \(index) with error: \(result.errorCode):\(result.errorMessage)")
                                    continue
                                } else {
                                    panic("EVM call failed for scheduled transaction with ID \(id) and index \(index) with error: \(result.errorCode):\(result.errorMessage)")
                                }
                            }
                    }
                }
            } else {
                self.emitError(id: id, errorMessage: "Invalid scheduled transaction data type for COA handler execution for tx with ID \(id)! Expected [FlowTransactionSchedulerUtils.COAHandlerParams] but got \(data.getType().identifier)")
                return
            }
        }

        /// Get the views supported by this handler
        /// @return: Array of view types
        access(all) view fun getViews(): [Type] {
            return [
                Type<COAHandlerView>(),
                Type<StoragePath>(),
                Type<PublicPath>(),
                Type<MetadataViews.Display>()
            ]
        }

        /// Resolve a view for this handler
        /// @param viewType: The type of view to resolve
        /// @return: The resolved view data, or nil if not supported
        access(all) fun resolveView(_ viewType: Type): AnyStruct? {
            if viewType == Type<COAHandlerView>() {
                return COAHandlerView(
                    coaOwner: self.coaCapability.borrow()?.owner?.address,
                    coaEVMAddress: self.coaCapability.borrow()?.address(),
                    coaBalance: self.coaCapability.borrow()?.balance(),
                )
            }
            if viewType == Type<StoragePath>() {
                return FlowTransactionSchedulerUtils.coaHandlerStoragePath()
            } else if viewType == Type<PublicPath>() {
                return FlowTransactionSchedulerUtils.coaHandlerPublicPath()
            } else if viewType == Type<MetadataViews.Display>() {
                return MetadataViews.Display(
                    name: "COA Scheduled Transaction Handler",
                    description: "Scheduled Transaction Handler that can execute transactions on behalf of a COA",
                    thumbnail: MetadataViews.HTTPFile(
                        url: ""
                    )
                )
            }
            return nil
        }
    }

    /// Enum for COA handler execution type
    access(all) enum COAHandlerTxType: UInt8 {
        access(all) case DepositFLOW
        access(all) case WithdrawFLOW
        access(all) case Call

        // TODO: Should we have other transaction types??
    }

    access(all) struct COAHandlerParams {

        /// The type of transaction to execute
        access(all) let txType: COAHandlerTxType

        /// Indicates if the whole set of scheduled transactions should be reverted
        /// if this one transaction fails to execute in EVM
        access(all) let revertOnFailure: Bool

        /// The amount of FLOW to deposit or withdraw
        /// Not required for the Call transaction type
        access(all) let amount: UFix64?

        /// The following fields are only required for the Call transaction type
        access(all) let callToEVMAddress: EVM.EVMAddress?
        access(all) let data: [UInt8]?
        access(all) let gasLimit: UInt64?
        access(all) let value: EVM.Balance?

        init(txType: UInt8, revertOnFailure: Bool, amount: UFix64?, callToEVMAddress: String?, data: [UInt8]?, gasLimit: UInt64?, value: UInt?) {
            self.txType = COAHandlerTxType(rawValue: txType)
                ?? panic("Invalid COA transaction type enum")
            self.revertOnFailure = revertOnFailure
            if self.txType == COAHandlerTxType.DepositFLOW {
                assert(amount != nil, message: "Amount is required for deposit but was not provided")
            }
            if self.txType == COAHandlerTxType.WithdrawFLOW {
                assert(amount != nil, message: "Amount is required for withdrawal but was not provided")
            }
            if self.txType == COAHandlerTxType.Call {
                assert(callToEVMAddress != nil, message: "Call to EVM address is required for EVM call but was not provided")
                assert((data != nil && value != nil) || (data == nil ? value != nil : true), message: "Data and/or value are required for EVM call but neither were provided")
                assert(gasLimit != nil, message: "Gas limit is required for EVM call but was not provided")
            }
            self.amount = amount
            if callToEVMAddress != nil {
                self.callToEVMAddress = EVM.addressFromString(callToEVMAddress!)
            } else {
                self.callToEVMAddress = nil
            }
            if data != nil {
                self.data = data
            } else {
                self.data = []
            }
            self.gasLimit = gasLimit
            if let unwrappedValue = value {
                self.value = EVM.Balance(attoflow: unwrappedValue)
            } else {
                self.value = nil
            }
        }
    }

    /// View struct for COA handler metadata
    access(all) struct COAHandlerView {
        access(all) let coaOwner: Address?
        access(all) let coaEVMAddress: EVM.EVMAddress?

        access(all) let coaBalance: EVM.Balance?

        init(coaOwner: Address?, coaEVMAddress: EVM.EVMAddress?, coaBalance: EVM.Balance?) {
            self.coaOwner = coaOwner
            self.coaEVMAddress = coaEVMAddress
            self.coaBalance = coaBalance
        }
    }

    /// Create a COA transaction handler
    /// @param coaCapability: Capability to the COA resource
    /// @param flowTokenVaultCapability: Capability to the FlowToken vault
    /// @return: A new COATransactionHandler resource
    access(all) fun createCOATransactionHandler(
        coaCapability: Capability<auth(EVM.Owner) &EVM.CadenceOwnedAccount>,
        flowTokenVaultCapability: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
    ): @COATransactionHandler {
        return <-create COATransactionHandler(
            coaCapability: coaCapability,
            flowTokenVaultCapability: flowTokenVaultCapability,
        )
    }

    /********************************************
    
    Scheduled Transactions Metadata Views
    
    ***********************************************/

}