import "FlowCallbackScheduler"
import "FlowToken"

access(all) contract FlowCallbackUtils {

    /// Storage path for CallbackManager resources
    access(all) let managerStoragePath: StoragePath

    /// Public path for CallbackManager resources
    access(all) let managerPublicPath: PublicPath

    /// Entitlements
    access(all) entitlement Owner

    /// CallbackManager resource that stores ScheduledCallback resources in a dictionary
    /// and provides convenience methods for scheduling and canceling callbacks
    access(all) resource CallbackManager {
        /// Dictionary storing scheduled callbacks by their ID
        access(self) var scheduledCallbacks: @{UInt64: FlowCallbackScheduler.ScheduledCallback}

        init() {
            self.scheduledCallbacks <- {}
        }

        /// Schedule a callback and store it in the manager's dictionary
        /// @param callback: A capability to a resource that implements the CallbackHandler interface
        /// @param data: Optional data to pass to the callback when executed
        /// @param timestamp: The timestamp when the callback should be executed
        /// @param priority: The priority of the callback (High, Medium, or Low)
        /// @param executionEffort: The execution effort for the callback
        /// @param fees: A FlowToken vault containing sufficient fees
        /// @return: The scheduled callback resource
        access(Owner) fun schedule(
            callback: Capability<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: FlowCallbackScheduler.Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ) {
            // Clean up any invalid callbacks before scheduling a new one
            self.cleanup()

            // Route to the main FlowCallbackScheduler
            let scheduledCallback <- FlowCallbackScheduler.schedule(
                callback: callback,
                data: data,
                timestamp: timestamp,
                priority: priority,
                executionEffort: executionEffort,
                fees: <-fees
            )

            // Store the callback in our dictionary
            self.scheduledCallbacks[scheduledCallback.id] <-! scheduledCallback
        }

        /// Cancel a scheduled callback by its ID
        /// @param id: The ID of the callback to cancel
        /// @return: A FlowToken vault containing the refunded fees
        access(Owner) fun cancel(id: UInt64): @FlowToken.Vault {
            // Remove the callback from our dictionary
            let callback <- self.scheduledCallbacks.remove(key: id)
                ?? panic("Invalid ID: Callback with ID \(id) not found in manager")

            // Cancel the callback through the main scheduler
            let refundedFees <- FlowCallbackScheduler.cancel(callback: <-callback!)

            return <-refundedFees
        }

        /// Clean up callbacks that are no longer valid (return nil or Unknown status)
        /// This removes and destroys callbacks that have been executed, canceled, or are otherwise invalid
        /// @return: The number of callbacks that were cleaned up
        access(Owner) fun cleanup(): Int {
            var cleanedUpCount = 0
            var callbacksToRemove: [UInt64] = []

            // First, identify callbacks that need to be removed
            for id in self.scheduledCallbacks.keys {
                let status = FlowCallbackScheduler.getStatus(id: id)
                if status == nil || status == FlowCallbackScheduler.Status.Unknown {
                    callbacksToRemove.append(id)
                }
            }

            // Then remove and destroy the identified callbacks
            for id in callbacksToRemove {
                if let callback <- self.scheduledCallbacks.remove(key: id) {
                    destroy callback
                    cleanedUpCount = cleanedUpCount + 1
                }
            }

            return cleanedUpCount
        }

        /// Get callback data by its ID
        /// @param id: The ID of the callback to retrieve
        /// @return: The callback data from FlowCallbackScheduler, or nil if not found
        access(all) fun getCallbackData(id: UInt64): FlowCallbackScheduler.CallbackData? {
            return FlowCallbackScheduler.getCallbackData(id: id)
        }

        /// Get all callback IDs stored in the manager
        /// @return: An array of all callback IDs
        access(all) fun getCallbackIDs(): [UInt64] {
            return self.scheduledCallbacks.keys
        }

        /// Get the status of a callback by its ID
        /// @param id: The ID of the callback
        /// @return: The status of the callback, or Status.Unknown if not found in manager
        access(all) fun getCallbackStatus(id: UInt64): FlowCallbackScheduler.Status? {
            if self.scheduledCallbacks.containsKey(id) {
                return FlowCallbackScheduler.getStatus(id: id)
            }
            return FlowCallbackScheduler.Status.Unknown
        }
    }

    /// Create a new CallbackManager instance
    /// @return: A new CallbackManager resource
    access(all) fun createCallbackManager(): @CallbackManager {
        return <-create CallbackManager()
    }

    access(all) init() {
        self.managerStoragePath = /storage/flowCallbackManager
        self.managerPublicPath = /public/flowCallbackManager
    }
}