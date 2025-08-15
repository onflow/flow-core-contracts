import "FlowToken"
import "FlowFees"
import "FlowStorageFees"

/// FlowCallbackScheduler enables smart contracts to schedule autonomous execution in the future.
///
/// This contract implements FLIP 330's scheduled callback system, allowing contracts to "wake up" and execute
/// logic at predefined times without external triggers. 
///
/// Callbacks are prioritized (High/Medium/Low) with different execution guarantees and fee multipliers: 
///   - High priority guarantees first-block execution,
///   - Medium priority provides best-effort scheduling,
///   - Low priority executes opportunistically when capacity allows. 
///
/// The system uses time slots with execution effort limits to manage network resources,
/// ensuring predictable performance while enabling novel autonomous blockchain patterns like recurring
/// payments, automated arbitrage, and time-based contract logic.
access(all) contract FlowCallbackScheduler {

    /// singleton instance used to store all callback data
    /// and route all callback functionality
    access(self) var sharedScheduler: Capability<auth(Cancel) &SharedScheduler>

    access(all) let storagePath: StoragePath

    /// Enums
    access(all) enum Priority: UInt8 {
        access(all) case High
        access(all) case Medium
        access(all) case Low
    }

    access(all) enum Status: UInt8 {
        /// unknown statuses are used for handling historic callbacks with null statuses
        access(all) case Unknown
        /// mutable status
        access(all) case Scheduled
        /// finalized statuses
        access(all) case Executed
        access(all) case Canceled
    }

    /// Events
    access(all) event Scheduled(
        id: UInt64,
        priority: UInt8,
        timestamp: UFix64,
        executionEffort: UInt64,
        fees: UFix64,
        callbackOwner: Address
    )

    access(all) event PendingExecution(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        fees: UFix64,
        callbackOwner: Address
    )

    access(all) event Executed(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        callbackOwner: Address,
    )

    access(all) event Canceled(
        id: UInt64,
        priority: UInt8,
        feesReturned: UFix64,
        feesDeducted: UFix64,
        callbackOwner: Address
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

    /// The callback handler is an interface that defines a single method executeCallback that 
    /// must be implemented by the resource that would like to schedule the callback. 
    /// The callback gets executed by the scheduler contract by calling the authorized Capability 
    /// that was provided when scheduled.
    access(all) resource interface CallbackHandler {
        /// Executes the implemented callback logic
        ///
        /// @param id: The id of the scheduled callback (this can be useful for any internal tracking)
        /// @param data: The data that was passed when the callback was originally scheduled
        access(Execute) fun executeCallback(id: UInt64, data: AnyStruct?)
    }

    /// Structs

    /// ScheduledCallback contains a method to check the callback status and can be passed back
    /// to the scheduler contract to cancel the callback if it has not yet been executed. 
    /// It can only be created by the scheduler contract to prevent spoofing.
    access(all) struct ScheduledCallback {
        access(self) let scheduler: Capability<auth(Cancel) &SharedScheduler>
        access(all) let id: UInt64
        access(all) let timestamp: UFix64

        access(all) view fun status(): Status? {
            return self.scheduler.borrow()!.getStatus(id: self.id)
        }

        access(contract) init(
            scheduler: Capability<auth(Cancel) &SharedScheduler>,
            id: UInt64, 
            timestamp: UFix64
        ) {
            pre {
                scheduler.check():
                    "Invalid Scheduler Capability provided when initializing ScheduledCallback with id \(id)"
            }
            self.scheduler = scheduler
            self.id = id
            self.timestamp = timestamp
        }
    }

    /// Estimated callback contains data for estimating callback scheduling.
    access(all) struct EstimatedCallback {
        /// flowFee is the estimated fee in Flow for the callback to be scheduled
        access(all) let flowFee: UFix64?
        /// timestamp is estimated scheduled timestamp for the callback at which it will be execute
        access(all) let timestamp: UFix64?
        /// error is an optional error message if the callback cannot be scheduled
        access(all) let error: String?

        access(contract) view init(flowFee: UFix64?, timestamp: UFix64?, error: String?) {
            self.flowFee = flowFee
            self.timestamp = timestamp
            self.error = error
        }
    }

    /// Callback data is an internal representation of a scheduled callback which contains all the functionality 
    /// to schedule, process and execute each callback. 
    access(all) resource CallbackData {
        access(all) let id: UInt64
        access(all) let priority: Priority
        access(all) let executionEffort: UInt64
        access(all) var status: Status

        /// The timestamp that the callback is scheduled for
        /// For medium priority callbacks, it may be different than the requested timestamp
        /// For low priority callbacks, it is the requested timestamp,
        /// but the timestamp where the callback is actually executed may be different
        access(all) var scheduledTimestamp: UFix64

        /// Capability to the logic that the callback will execute
        access(contract) let handler: Capability<auth(Execute) &{CallbackHandler}>

        /// Optional data that can be passed to the handler
        access(contract) let data: AnyStruct?

        /// Fees to pay for the callback
        access(contract) let fees: @FlowToken.Vault

        access(contract) init(
            id: UInt64,
            handler: Capability<auth(Execute) &{CallbackHandler}>,
            scheduledTimestamp: UFix64,
            data: AnyStruct?,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault,
        ) {
            self.id = id
            self.handler = handler
            self.scheduledTimestamp = scheduledTimestamp
            self.data = data
            self.priority = priority
            self.executionEffort = executionEffort
            self.fees <- fees
            self.status = Status.Scheduled
        }

        /// setStatus updates the status of the callback.
        /// It panics if the callback status is already finalized.
        access(contract) fun setStatus(newStatus: Status) {
            pre {
                self.status != Status.Executed && self.status != Status.Canceled:
                    "Invalid status: Callback with id \(self.id) is already finalized"
                newStatus == Status.Executed ? self.status == Status.Scheduled : true:
                    "Invalid status: Callback with id \(self.id) can only be set as Executed if it is Scheduled"
                newStatus == Status.Canceled ? self.status == Status.Scheduled : true:
                    "Invalid status: Callback with id \(self.id) can only be set as Canceled if it is Scheduled"
            }

            self.status = newStatus
        }

        /// setScheduledTimestamp updates the scheduled timestamp of the callback.
        /// It panics if the callback status is already finalized.
        access(contract) fun setScheduledTimestamp(newTimestamp: UFix64) {
            pre {
                self.status != Status.Executed && self.status != Status.Canceled:
                    "Invalid status: Callback with id \(self.id) is already finalized"
            }
            self.scheduledTimestamp = newTimestamp
        }

        /// payAndRefundFees withdraws fees from the callback based on the refund multiplier.
        /// This action is only allowed for canceled callbacks, otherwise it panics.
        /// It deposits any leftover fees to the FlowFees vault to be used to pay node operator rewards
        access(contract) fun payAndRefundFees(refundMultiplier: UFix64): @FlowToken.Vault {
            if refundMultiplier == 0.0 {
                FlowFees.deposit(from: <-self.fees.withdraw(amount: self.fees.balance))
                return <-FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            } else {
                let amount = self.fees.balance * refundMultiplier
                let feesToReturn <- self.fees.withdraw(amount: amount) as! @FlowToken.Vault
                FlowFees.deposit(from: <-self.fees.withdraw(amount: self.fees.balance))
                return <-feesToReturn
            }
        }

        /// getData copies and returns the data field
        access(all) view fun getData(): AnyStruct? {
            return self.data
        }

        access(all) view fun toString(): String {
            return "callback (id: \(self.id), status: \(self.status.rawValue), timestamp: \(self.scheduledTimestamp), priority: \(self.priority.rawValue), executionEffort: \(self.executionEffort), callbackOwner: \(self.handler.address))"
        }
    }

    /// Struct interface representing all the base configuration details in the Scheduler contract
    /// that is used for governing the protocol
    /// This is an interface to allow for the configuration details to be updated in the future
    access(all) struct interface SchedulerConfig {
        /// slot total effort limit is the maximum effort that can be 
        /// cumulatively allocated to one timeslot by all priorities
        access(all) var slotTotalEffortLimit: UInt64

        /// slot shared effort limit is the maximum effort 
        /// that can be allocated to high and medium priority 
        /// callbacks combined after their exclusive effort reserves have been filled
        access(all) var slotSharedEffortLimit: UInt64

        /// priority effort reserve is the amount of effort that is 
        /// reserved exclusively for each priority
        access(all) var priorityEffortReserve: {Priority: UInt64}

        /// priority effort limit is the maximum effort per priority in a timeslot
        access(all) var priorityEffortLimit: {Priority: UInt64}

        /// minimum execution effort is the minimum effort that can be 
        /// used for any priority
        access(all) var minimumExecutionEffort: UInt64

        /// priority fee multipliers are values we use to calculate the added 
        /// processing fee for each priority
        access(all) var priorityFeeMultipliers: {Priority: UFix64}

        /// refund multiplier is the portion of the fees that are refunded when a callback is cancelled
        access(all) var refundMultiplier: UFix64

        /// canceledCallbacksLimit is the maximum number of canceled callbacks to keep in the canceledCallbacks array
        access(all) var canceledCallbacksLimit: UInt

        access(all) init(
            slotSharedEffortLimit: UInt64,
            priorityEffortReserve: {Priority: UInt64},
            priorityEffortLimit: {Priority: UInt64},
            minimumExecutionEffort: UInt64,
            priorityFeeMultipliers: {Priority: UFix64},
            refundMultiplier: UFix64,
            canceledCallbacksLimit: UInt
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
            }
        }
    }

    /// Concrete implementation of the SchedulerConfig interface
    /// This struct is used to store the configuration details in the Scheduler contract
    access(all) struct Config: SchedulerConfig {
        access(all) var slotTotalEffortLimit: UInt64
        access(all) var slotSharedEffortLimit: UInt64
        access(all) var priorityEffortReserve: {Priority: UInt64}
        access(all) var priorityEffortLimit: {Priority: UInt64}
        access(all) var minimumExecutionEffort: UInt64
        access(all) var priorityFeeMultipliers: {Priority: UFix64}
        access(all) var refundMultiplier: UFix64
        access(all) var canceledCallbacksLimit: UInt

        access(all) init(
            slotSharedEffortLimit: UInt64,
            priorityEffortReserve: {Priority: UInt64},
            priorityEffortLimit: {Priority: UInt64},
            minimumExecutionEffort: UInt64,
            priorityFeeMultipliers: {Priority: UFix64},
            refundMultiplier: UFix64,
            canceledCallbacksLimit: UInt
        ) {
            self.slotTotalEffortLimit = slotSharedEffortLimit + priorityEffortReserve[Priority.High]! + priorityEffortReserve[Priority.Medium]!
            self.slotSharedEffortLimit = slotSharedEffortLimit
            self.priorityEffortReserve = priorityEffortReserve
            self.priorityEffortLimit = priorityEffortLimit
            self.minimumExecutionEffort = minimumExecutionEffort
            self.priorityFeeMultipliers = priorityFeeMultipliers
            self.refundMultiplier = refundMultiplier
            self.canceledCallbacksLimit = canceledCallbacksLimit
        }
    }


    /// SortedTimestamps maintains a sorted array of timestamps for efficient processing
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
        access(all) fun hasTimestampsBefore(current: UFix64): Bool {
            return self.timestamps.length > 0 && self.timestamps[0] <= current
        }
    }

    /// Resources

    /// Shared scheduler is a resource that is used as a singleton in the scheduler contract and contains 
    /// all the functionality to schedule, process and execute callbacks as well as the internal state. 
    access(all) resource SharedScheduler {
        /// nextID contains the next callback ID to be assigned
        access(contract) var nextID: UInt64

        /// callbacks is a map of callback IDs to callback data
        access(contract) var callbacks: @{UInt64: CallbackData}

        /// slot queue is a map of timestamps to callback IDs and their execution efforts
        access(contract) var slotQueue: {UFix64: {UInt64: UInt64}}

        /// slot used effort is a map of timestamps map of priorities and 
        /// efforts that has been used for the timeslot
        access(contract) var slotUsedEffort: {UFix64: {Priority: UInt64}}

        /// sorted timestamps manager for efficient processing
        access(contract) var sortedTimestamps: SortedTimestamps
        
        /// used for querying historic statuses so that we don't have to store all succeeded statuses
        access(contract) var earliestHistoricID: UInt64

        /// canceled callbacks keeps a record of canceled callback IDs up to a canceledCallbacksLimit
        access(all) var canceledCallbacks: [UInt64]

        /// Struct that contains all the configuration details for the callback scheduler protocol
        /// Can be updated by the owner of the contract
        access(contract) var configurationDetails: {SchedulerConfig}

        access(all) init() {
            self.nextID = 1
            self.earliestHistoricID = 0
            self.canceledCallbacks = [0 as UInt64]
            
            self.callbacks <- {}
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

            self.configurationDetails = Config(
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
                minimumExecutionEffort: 5,
                priorityFeeMultipliers: {
                    Priority.High: 10.0,
                    Priority.Medium: 5.0,
                    Priority.Low: 2.0
                },
                refundMultiplier: 0.5,
                canceledCallbacksLimit: 30 * 24 // 30 days with 1 per hour
            )
        }

        /// Gets a struct containing all the configuration details
        /// of the Scheduler resource
        access(all) fun getConfigurationDetails(): {SchedulerConfig} {
            return self.configurationDetails
        }

        /// sets all the configuration details for the Scheduler resource
        access(UpdateConfig) fun setConfigurationDetails(newConfig: {SchedulerConfig}) {
            self.configurationDetails = newConfig
            emit ConfigUpdated()
        }

        /// Borrows a reference to the specified callback
        access(contract) view fun borrowCallback(id: UInt64): &CallbackData? {
            return &self.callbacks[id]
        }

        /// calculate fee by converting execution effort to a fee in Flow tokens.
        access(all) fun calculateFee(executionEffort: UInt64, priority: Priority, data: AnyStruct?): UFix64 {
            // Use the official FlowFees calculation
            let baseFee = FlowFees.computeFees(inclusionEffort: 1.0, executionEffort: UFix64(executionEffort))
            
            // Scale the execution fee by the multiplier for the priority
            let scaledExecutionFee = baseFee * self.configurationDetails.priorityFeeMultipliers[priority]!

            // Calculate the FLOW required to pay for storage of the callback data
            let storageFee = FlowStorageFees.storageCapacityToFlow(FlowCallbackScheduler.getSizeOfData(data))
            
            return scaledExecutionFee + storageFee
        }

        /// getNextIDAndIncrement returns the next ID and increments the ID counter
        access(self) fun getNextIDAndIncrement(): UInt64 {
            let nextID = self.nextID
            self.nextID = self.nextID + 1
            return nextID
        }

        /// get status of the scheduled callback, if the callback is not found Unknown is returned.
        access(all) view fun getStatus(id: UInt64): Status? {

            if let callback = self.borrowCallback(id: id) {
                return callback.status
            }

            // if the callback was canceled and it is still not pruned from 
            // list return canceled status
            if self.canceledCallbacks.contains(id) {
                return Status.Canceled
            }

            // if no callbacks were yet canceled the status is executed
            if self.canceledCallbacks.length == 0 {
                return Status.Executed
            }

            // if callback ID is after first canceled ID it must be executed 
            // otherwise it would have been canceled and part of this list
            let firstCanceledID = self.canceledCallbacks[0]
            if id > firstCanceledID {
                return Status.Executed
            }

            // the callback list was pruned and the callback status might be 
            // either canceled or execute so we return unknown
            return Status.Unknown
        }

        /// schedule is the primary entry point for scheduling a new callback within the scheduler contract. 
        /// If scheduling the callback is not possible either due to invalid arguments or due to 
        /// unavailable slots, the function panics. 
        //
        /// The schedule function accepts the following arguments:
        /// @param: callback: A capability to a resource in storage that implements the callback handler 
        ///    interface. This handler will be invoked at execution time and will receive the specified data payload.
        /// @param: timestamp: Specifies the earliest block timestamp at which the callback is eligible for execution 
        ///    (fractional seconds values are ignored). It must be set in the future.
        /// @param: priority: An enum value (`high`, `medium`, or `low`) that influences the scheduling behavior and determines 
        ///    how soon after the timestamp the callback will be executed.
        /// @param: executionEffort: Defines the maximum computational resources allocated to the callback. This also determines 
        ///    the fee charged. Unused execution effort is not refunded.
        /// @param: fees: A Vault resource containing sufficient funds to cover the required execution effort.
        access(contract) fun schedule(
            callback: Capability<auth(Execute) &{CallbackHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): ScheduledCallback {

            // Use the estimate function to validate inputs
            let estimate = self.estimate(
                data: data,
                timestamp: timestamp,
                priority: priority,
                executionEffort: executionEffort
            )

            // Estimate returns an error for low priority callbacks
            // so need to check that the error is fine
            // because low priority callbacks are allowed in schedule
            if estimate.error != nil && estimate.timestamp == nil {
                panic(estimate.error!)
            }

            assert (
                fees.balance >= estimate.flowFee!,
                message: "Insufficient fees: The Fee balance of \(fees.balance) is not sufficient to pay the required amount of \(estimate.flowFee!) for execution of the callback."
            )

            let callbackID = self.getNextIDAndIncrement()
            let callback <- create CallbackData(
                id: callbackID,
                handler: callback,
                scheduledTimestamp: estimate.timestamp!,
                data: data,
                priority: priority,
                executionEffort: executionEffort,
                fees: <- fees,
            )

            emit Scheduled(
                id: callback.id,
                priority: callback.priority.rawValue,
                timestamp: callback.scheduledTimestamp,
                executionEffort: callback.executionEffort,
                fees: callback.fees.balance,
                callbackOwner: callback.handler.address
            )

            self.addCallback(slot: estimate.timestamp!, callback: <-callback)
            
            return ScheduledCallback(
                scheduler: FlowCallbackScheduler.sharedScheduler, 
                id: callbackID, 
                timestamp: estimate.timestamp!
            )
        }

        /// The estimate function calculates the required fee in Flow and expected execution time for 
        /// a callback based on timestamp, priority, and execution effort. 
        //
        /// If the provided arguments are invalid or the callback cannot be scheduled (e.g., due to 
        /// insufficient computation effort or unavailable time slots) the estimate function returns `nil`.
        ///        
        /// This helps developers ensure sufficient funding and preview the expected scheduling window, 
        /// reducing the risk of unnecessary cancellations.
        access(contract) fun estimate(
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64
        ): EstimatedCallback {
            // Remove fractional values from the timestamp
            let sanitizedTimestamp = UFix64(UInt64(timestamp))

            if sanitizedTimestamp <= getCurrentBlock().timestamp {
                return EstimatedCallback(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid timestamp: \(sanitizedTimestamp) is in the past, current timestamp: \(getCurrentBlock().timestamp)"
                        )
            }

            if executionEffort > self.configurationDetails.priorityEffortLimit[priority]! {
                return EstimatedCallback(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort of \(self.configurationDetails.priorityEffortLimit[priority]!)"
                        )
            }

            if executionEffort < self.configurationDetails.minimumExecutionEffort {
                return EstimatedCallback(
                            flowFee: nil,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is less than the minimum execution effort of \(self.configurationDetails.minimumExecutionEffort)"
                        )
            }

            let fee = self.calculateFee(executionEffort: executionEffort, priority: priority, data: data)

            let scheduledTimestamp = self.calculateScheduledTimestamp(
                timestamp: sanitizedTimestamp, 
                priority: priority, 
                executionEffort: executionEffort
            )

            if scheduledTimestamp == nil {
                return EstimatedCallback(
                            flowFee: fee,
                            timestamp: nil,
                            error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort for the requested timestamp."
                        )
            }

            if priority == Priority.Low {
                return EstimatedCallback(
                            flowFee: fee,
                            timestamp: scheduledTimestamp,
                            error: "Invalid Priority: Cannot estimate for Low Priority callbacks. They will be included in the first block with available space after their requested timestamp."
                        )
            }

            return EstimatedCallback(flowFee: fee, timestamp: scheduledTimestamp, error: nil)
        }

        /// calculateScheduledTimestamp calculates the timestamp at which a callback 
        /// can be scheduled. It takes into account the priority of the callback and 
        /// the execution effort.
        /// - If the callback is low priority, it returns the requested timestamp
        /// - If the callback is high priority, it returns the timestamp if there is enough 
        ///    space or nil if there is no space left.
        /// - If the callback is medium priority and there is no space left it finds next 
        ///    available timestamp.
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
            } else if priority == Priority.High {
                // high priority demands scheduling at exact timestamp or failing
                return nil
            }

            // if there is no space left for medium or low priority we search for next available timestamp
            // todo: check how big the callstack can grow and if we should avoid recursion
            return self.calculateScheduledTimestamp(
                timestamp: timestamp + 1.0, 
                priority: priority, 
                executionEffort: executionEffort
            )
        }

        /// slot available effort returns the amount of effort that is available for a given timestamp and priority.
        access(all) view fun getSlotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {

            // Remove fractional values from the timestamp
            let sanitizedTimestamp = UFix64(UInt64(timestamp))

            // Get the maximum allowed for a priority including shared
            let priorityLimit = self.configurationDetails.priorityEffortLimit[priority]!
            
            // If nothing has been claimed for the requested timestamp,
            // return the full amount
            if !self.slotUsedEffort.containsKey(sanitizedTimestamp) {
                return priorityLimit
            }

            // Get the mapping of how much effort has been used
            // for each priority for the timestamp
            let slotPriorityEffortsUsed = self.slotUsedEffort[sanitizedTimestamp]!

            // Get the exclusive reserves for each priority
            let highReserve = self.configurationDetails.priorityEffortReserve[Priority.High]!
            let mediumReserve = self.configurationDetails.priorityEffortReserve[Priority.Medium]!

            // Get how much effort has been used for each priority
            let highUsed = slotPriorityEffortsUsed[Priority.High] ?? 0
            let mediumUsed = slotPriorityEffortsUsed[Priority.Medium] ?? 0

            // If it is low priority, return whatever effort is remaining
            // under 5000
            if priority == Priority.Low {
                let highPlusMediumUsed = highUsed + mediumUsed
                // prevent underflow
                let totalEffortRemaining = self.configurationDetails.slotTotalEffortLimit.saturatingSubtract(highPlusMediumUsed)
                return totalEffortRemaining < priorityLimit ? totalEffortRemaining : priorityLimit
            }
            
            // Get how much shared effort has been used for each priority
            // Ensure the results are always zero or positive
            let highSharedUsed: UInt64 = highUsed.saturatingSubtract(highReserve)
            let mediumSharedUsed: UInt64 = mediumUsed.saturatingSubtract(mediumReserve)

            // Get the theoretical total shared amount between priorities
            let totalShared = (self.configurationDetails.slotTotalEffortLimit.saturatingSubtract(highReserve)).saturatingSubtract(mediumReserve)

            // Get the amount of shared effort currently available
            let highPlusMediumSharedUsed = highSharedUsed + mediumSharedUsed
            // prevent underflow
            let sharedAvailable = totalShared.saturatingSubtract(highPlusMediumSharedUsed)

            // we calculate available by calculating available shared effort and 
            // adding any unused reserves for that priority
            let reserve = self.configurationDetails.priorityEffortReserve[priority]!
            let used = slotPriorityEffortsUsed[priority] ?? 0
            let unusedReserve: UInt64 = reserve.saturatingSubtract(used)
            let available = sharedAvailable + unusedReserve
            
            return available
        }

        /// Adds callback to the queue and updates all the internal state as well as emit an event
        access(self) fun addCallback(slot: UFix64, callback: @CallbackData) {

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

            // Add this callback id to the slot
            let slotQueue = self.slotQueue[slot]!
            slotQueue[callback.id] = callback.executionEffort
            self.slotQueue[slot] = slotQueue
            
            if callback.priority != Priority.Low {
                // Add the execution effort for this callback to the total for the slot's priority
                // Low priority callbacks don't count toward a slot's execution effort
                // because they are executed in the first block with available space after their requested timestamp
                let slotEfforts = self.slotUsedEffort[slot]!
                slotEfforts[callback.priority] = slotEfforts[callback.priority]! + callback.executionEffort
                self.slotUsedEffort[slot] = slotEfforts
            }

            self.callbacks[callback.id] <-! callback
        }
 
        /// process scheduled callbacks and prepare them for execution. 
        ///
        /// It iterates over past timestamps in the queue and processes the callbacks that are 
        /// eligible for execution. It also emits an event for each callback that is processed.
        ///
        /// This function is only called by the FVM to process callbacks.
        access(Process) fun process() {

            let currentTimestamp = getCurrentBlock().timestamp
            
            // Early exit if no timestamps need processing
            if !self.sortedTimestamps.hasTimestampsBefore(current: currentTimestamp) {
                return
            }
            
            // Collect past timestamps efficiently from sorted array
            let pastTimestamps = self.sortedTimestamps.getBefore(current: currentTimestamp)
            
            // process all callbacks from timestamps in the past in order
            for timestamp in pastTimestamps {
                let callbackIDs = self.slotQueue[timestamp] ?? {}

                // Get the available effort for low priority callbacks at this timestamp
                var lowPriorityEffortAvailable = self.getSlotAvailableEffort(timestamp: timestamp, priority: Priority.Low)

                for id in callbackIDs.keys {
                    let callback = self.borrowCallback(id: id)
                        ?? panic("Invalid ID: \(id) callback not found during initial processing") // critical bug

                    // Callbacks that are already executed are garbage collected and removed from the queue
                    if callback.status == Status.Executed {
                        callbackIDs.remove(key: id)
                        destroy self.garbageCollect(callback: callback)
                        continue
                    }

                    if callback.status == Status.Scheduled {
                        if callback.priority == Priority.Low {
                            if callback.executionEffort <= lowPriorityEffortAvailable {
                                lowPriorityEffortAvailable = lowPriorityEffortAvailable - callback.executionEffort
                            } else {
                                // remove the callback from this timestamp
                                // and try to add it to a future timestamp
                                let newTimestamp = self.calculateScheduledTimestamp(
                                    timestamp: timestamp + 1.0, 
                                    priority: Priority.Low, 
                                    executionEffort: callback.executionEffort
                                )!

                                let callbackResource <- self.garbageCollect(callback: callback)
                                callbackResource.setScheduledTimestamp(newTimestamp: newTimestamp)
                                self.addCallback(slot: newTimestamp, callback: <-callbackResource)
                                
                                continue
                            }
                        }

                        emit PendingExecution(
                                id: id,
                                priority: callback.priority.rawValue,
                                executionEffort: callback.executionEffort,
                                fees: callback.fees.balance,
                                callbackOwner: callback.handler.address
                            )

                        // after pending execution event is emitted we set the callback as executed because we 
                        // must rely on execution node to actually execute it. Execution of the callback which is 
                        // done in a separate transaction that calls executeCallback(id) function can not update 
                        // the status of callback or any other shared state, since that blocks concurrent callback 
                        // execution. Therefore optimistic update to executed is made here to avoid race condition.
                        callback.setStatus(newStatus: Status.Executed)

                        // charge the fee for callback execution
                        destroy callback.payAndRefundFees(refundMultiplier: 0.0)
                    }
                }
            }
        }

        /// cancel scheduled callback and return a portion of the fees that were paid.
        access(Cancel) fun cancel(id: UInt64): @FlowToken.Vault {
            let callback = self.borrowCallback(id: id) ?? 
                panic("Invalid ID: \(id) callback not found")

            // Remove this callback id from its slot
            let slotQueue = self.slotQueue[callback.scheduledTimestamp]!
            slotQueue[id] = nil
            self.slotQueue[callback.scheduledTimestamp] = slotQueue
            
            // Subtract the execution effort for this callback from the slot's priority
            // Low priority efforts don't count toward a slot's execution effort
            // so we don't need to subtract anything for them
            if callback.priority != Priority.Low {
                let slotEfforts = self.slotUsedEffort[callback.scheduledTimestamp]!
                slotEfforts[callback.priority] = slotEfforts[callback.priority]!.saturatingSubtract(callback.executionEffort)
                self.slotUsedEffort[callback.scheduledTimestamp] = slotEfforts
            }

            let totalFees = callback.fees.balance
            let refundedFees <- callback.payAndRefundFees(refundMultiplier: self.configurationDetails.refundMultiplier)

            // if the callback was canceled, add it to the canceled callbacks array
            self.canceledCallbacks.append(id)
            // keep the array under the limit
            if UInt(self.canceledCallbacks.length) > self.configurationDetails.canceledCallbacksLimit {
                self.canceledCallbacks.remove(at: 0)
            }

            emit Canceled(
                id: callback.id,
                priority: callback.priority.rawValue,
                feesReturned: refundedFees.balance,
                feesDeducted: totalFees - refundedFees.balance,
                callbackOwner: callback.handler.address
            )

            destroy self.garbageCollect(callback: callback)
            
            return <-refundedFees
        }

        /// execute callback is a system function that is called by FVM to execute a callback by ID.
        /// The callback must be found and in correct state or the function panics and this is a fatal error
        ///
        /// This function is only called by the FVM to execute callbacks.
        access(Execute) fun executeCallback(id: UInt64) {
            let callback = self.borrowCallback(id: id) ?? 
                panic("Invalid ID: Callback with id \(id) not found")

            assert (
                callback.status == Status.Executed,
                message: "Invalid ID: Cannot execute callback with id \(id) because it has incorrect status \(callback.status.rawValue)"
            )
            
            callback.handler.borrow()!.executeCallback(id: id, data: callback.getData())

            emit Executed(
                id: callback.id,
                priority: callback.priority.rawValue,
                executionEffort: callback.executionEffort,
                callbackOwner: callback.handler.address,
            )
        }

        /// finalizes and garbage collects the callback by removing the callback resource and the slot map if it is empty.
        access(contract) fun garbageCollect(callback: &CallbackData): @CallbackData {

            let callbackID = callback.id
            let slot = callback.scheduledTimestamp

            // remove callback resource
            let callbackRes <- self.callbacks.remove(key: callbackID)!
            
            // garbage collect slots 
            if let callbackQueue = self.slotQueue[slot] {

                callbackQueue[callbackID] = nil
                self.slotQueue[slot] = callbackQueue

                // if the slot is now empty remove it from the maps
                if callbackQueue.keys.length == 0 {
                    self.slotQueue.remove(key: slot)
                    self.slotUsedEffort.remove(key: slot)

                    self.sortedTimestamps.remove(timestamp: slot)
                }
            }

            return <-callbackRes
        }
    }

    access(all) fun schedule(
        callback: Capability<auth(Execute) &{CallbackHandler}>,
        data: AnyStruct?,
        timestamp: UFix64,
        priority: Priority,
        executionEffort: UInt64,
        fees: @FlowToken.Vault
    ): ScheduledCallback {
        return self.sharedScheduler.borrow()!.schedule(
            callback: callback, 
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
    ): EstimatedCallback {
        return self.sharedScheduler.borrow()!
            .estimate(
                data: data, 
                timestamp: timestamp, 
                priority: priority, 
                executionEffort: executionEffort,
            )
    }

    access(all) fun cancel(callback: ScheduledCallback): @FlowToken.Vault {
        return <-self.sharedScheduler.borrow()!.cancel(id: callback.id)
    }

    access(all) view fun getStatus(id: UInt64): Status? {
        return self.sharedScheduler.borrow()!.getStatus(id: id)
    }

    access(all) view fun getSlotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {
        return self.sharedScheduler.borrow()!.getSlotAvailableEffort(timestamp: timestamp, priority: priority)
    }

    access(all) fun getSchedulerConfigurationDetails(): {SchedulerConfig} {
        return self.sharedScheduler.borrow()!.getConfigurationDetails()
    }
    
    /// getSizeOfData takes a callback's data
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
        self.account.storage.save(<-scheduler, to: self.storagePath)
        
        self.sharedScheduler = self.account.capabilities.storage
            .issue<auth(Cancel) &SharedScheduler>(self.storagePath)
    }
}