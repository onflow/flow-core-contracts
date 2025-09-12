import "FlowTransactionScheduler"
import "FlowToken"

access(all) contract FlowTransactionSchedulerUtils {

    /// Storage path for Manager resources
    access(all) let managerStoragePath: StoragePath

    /// Public path for Manager resources
    access(all) let managerPublicPath: PublicPath

    /// Entitlements
    access(all) entitlement Owner

    /// Manager resource that stores ScheduledTransaction resources in a dictionary
    /// and provides convenience methods for scheduling and canceling transactions
    access(all) resource Manager {
        /// Dictionary storing scheduled transactions by their ID
        access(self) var scheduledTransactions: @{UInt64: FlowTransactionScheduler.ScheduledTransaction}

        init() {
            self.scheduledTransactions <- {}
        }

        /// Schedule a transaction and store it in the manager's dictionary
        /// @param handlerCap: A capability to a resource that implements the TransactionHandler interface
        /// @param data: Optional data to pass to the transaction when executed
        /// @param timestamp: The timestamp when the transaction should be executed
        /// @param priority: The priority of the transaction (High, Medium, or Low)
        /// @param executionEffort: The execution effort for the transaction
        /// @param fees: A FlowToken vault containing sufficient fees
        /// @return: The scheduled transaction resource
        access(Owner) fun schedule(
            handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): UInt64 {
            // Clean up any invalid transactions before scheduling a new one
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

            // Store the transaction in our dictionary
            self.scheduledTransactions[scheduledTransaction.id] <-! scheduledTransaction

            return id
        }

        /// Cancel a scheduled transaction by its ID
        /// @param id: The ID of the transaction to cancel
        /// @return: A FlowToken vault containing the refunded fees
        access(Owner) fun cancel(id: UInt64): @FlowToken.Vault {
            // Remove the transaction from our dictionary
            let tx <- self.scheduledTransactions.remove(key: id)
                ?? panic("Invalid ID: Transaction with ID \(id) not found in manager")

            // Cancel the transaction through the main scheduler
            let refundedFees <- FlowTransactionScheduler.cancel(scheduledTx: <-tx!)

            return <-refundedFees
        }

        /// Clean up transactions that are no longer valid (return nil or Unknown status)
        /// This removes and destroys transactions that have been executed, canceled, or are otherwise invalid
        /// @return: The number of transactions that were cleaned up
        access(Owner) fun cleanup(): Int {
            var cleanedUpCount = 0
            var transactionsToRemove: [UInt64] = []

            // First, identify transactions that need to be removed
            for id in self.scheduledTransactions.keys {
                let status = FlowTransactionScheduler.getStatus(id: id)
                if status == nil || status == FlowTransactionScheduler.Status.Unknown {
                    transactionsToRemove.append(id)
                }
            }

            // Then remove and destroy the identified transactions
            for id in transactionsToRemove {
                if let tx <- self.scheduledTransactions.remove(key: id) {
                    destroy tx
                    cleanedUpCount = cleanedUpCount + 1
                }
            }

            return cleanedUpCount
        }

        /// Get transaction data by its ID
        /// @param id: The ID of the transaction to retrieve
        /// @return: The transaction data from FlowTransactionScheduler, or nil if not found
        access(all) fun getTransactionData(id: UInt64): FlowTransactionScheduler.TransactionData? {
            return FlowTransactionScheduler.getTransactionData(id: id)
        }

        /// Get all transaction IDs stored in the manager
        /// @return: An array of all transaction IDs
        access(all) fun getTransactionIDs(): [UInt64] {
            return self.scheduledTransactions.keys
        }

        /// Get the status of a transaction by its ID
        /// @param id: The ID of the transaction
        /// @return: The status of the transaction, or Status.Unknown if not found in manager
        access(all) fun getTransactionStatus(id: UInt64): FlowTransactionScheduler.Status? {
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
}