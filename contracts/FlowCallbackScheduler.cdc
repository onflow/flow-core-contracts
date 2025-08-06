import "FlowToken"
import "FlowFees"
import "FlowStorageFees"

/// FlowCallbackScheduler 
access(all) contract FlowCallbackScheduler {

    /// singleton instance used to store all callback data
    /// and route all callback functionality
    access(self) var sharedScheduler: Capability<auth(Cancel) &SharedScheduler>

    /// Enums
    access(all) enum Priority: UInt8 {
        access(all) case High
        access(all) case Medium
        access(all) case Low
    }

    access(all) enum Status: UInt8 {
        /// mutable statuses
        access(all) case Scheduled
        access(all) case Processed
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

    access(all) event Processed(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        callbackOwner: Address
    )

    access(all) event Executed(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        fees: UFix64,
        callbackOwner: Address
    )

    access(all) event Canceled(
        id: UInt64,
        priority: UInt8,
        feesReturned: UFix64,
        feesDeducted: UFix64,
        callbackOwner: Address
    )

    // Emmitted when one or more of the configuration details fields are updated
    // Event listeners can listen to this and query the new configuration
    // if they need to
    access(all) event ConfigUpdated()

    /// Entitlements
    access(all) entitlement Execute
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

        /// The timestamp that was requested for this callback
        /// May be different than the actual scheduled timestamp for low & medium priority callbacks
        access(all) let originalTimestamp: UFix64

        /// The actual timestamp that the callback is scheduled for
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
            data: AnyStruct?,
            originalTimestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault,
            scheduledTimestamp: UFix64
        ) {
            self.id = id
            self.handler = handler
            self.data = data
            self.originalTimestamp = originalTimestamp
            self.priority = priority
            self.executionEffort = executionEffort
            self.fees <- fees
            self.status = Status.Scheduled
            self.scheduledTimestamp = scheduledTimestamp
        }

        /// setStatus updates the status of the callback.
        /// It panics if the callback status is already finalized.
        access(contract) fun setStatus(newStatus: Status) {
            pre {
                self.status != Status.Executed && self.status != Status.Canceled:
                    "Invalid status: Callback with id \(self.id) is already finalized"
                newStatus == Status.Executed ? self.status == Status.Processed : true:
                    "Invalid status: Callback with id \(self.id) cannot be marked as Executed until after it is Processed"
                newStatus == Status.Processed ? self.status == Status.Scheduled : true:
                    "Invalid status: Callback with id \(self.id) can only be set as Processed if it is Scheduled"
            }

            self.status = newStatus
        }

        /// payAndWithdrawFees withdraws fees from the callback based on the refund multiplier.
        /// This action is only allowed for canceled callbacks, otherwise it panics.
        /// It deposits any leftover fees to the FlowFees vault to be used to pay node operator rewards
        access(contract) fun payAndWithdrawFees(multiplierToWithdraw: UFix64): @FlowToken.Vault {
            if multiplierToWithdraw == 0.0 {
                FlowFees.deposit(from: <-self.fees.withdraw(amount: self.fees.balance))
                return <-FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            } else {
                let amount = self.fees.balance * multiplierToWithdraw
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

    /// Struct representing all the configuration details in the Scheduler contract
    /// that is used for governing the protocol
    access(all) struct SchedulerConfig {
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

        /// historic status limit is the maximum age of a historic canceled callback status we keep before getting pruned
        access(all) var historicStatusLimit: UFix64

        access(all) init(
            slotSharedEffortLimit: UInt64,
            priorityEffortReserve: {Priority: UInt64},
            priorityEffortLimit: {Priority: UInt64},
            minimumExecutionEffort: UInt64,
            priorityFeeMultipliers: {Priority: UFix64},
            refundMultiplier: UFix64,
            historicStatusLimit: UFix64
        ) {
            pre {
                refundMultiplier >= 0.0 && refundMultiplier <= 1.0:
                    "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got \(refundMultiplier)"
                historicStatusLimit >= 1.0 && historicStatusLimit < getCurrentBlock().timestamp:
                    "Invalid historic status limit: Limit must be greater than 1.0 and less than the current timestamp but got \(historicStatusLimit)"
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
            self.slotTotalEffortLimit = slotSharedEffortLimit + priorityEffortReserve[Priority.High]! + priorityEffortReserve[Priority.Medium]!
            self.slotSharedEffortLimit = slotSharedEffortLimit
            self.priorityEffortReserve = priorityEffortReserve
            self.priorityEffortLimit = priorityEffortLimit
            self.minimumExecutionEffort = minimumExecutionEffort
            self.priorityFeeMultipliers = priorityFeeMultipliers
            self.refundMultiplier = refundMultiplier
            self.historicStatusLimit = historicStatusLimit
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

        /// callback status maps historic canceled callback IDs to their original timestamps
        access(contract) var historicCanceledCallbacks: {UInt64: UFix64}

        /// slot queue is a map of timestamps to callback IDs and their execution efforts
        access(contract) var slotQueue: {UFix64: {UInt64: UInt64}}

        /// slot used effort is a map of timestamps map of priorities and 
        /// efforts that has been used for the timeslot
        access(contract) var slotUsedEffort: {UFix64: {Priority: UInt64}}

        /// low priority callbacks don't get assigned a timestamp, 
        /// so we use this special value
        access(contract) let lowPriorityScheduledTimestamp: UFix64

        /// Struct that contains all the configuration details for the callback scheduler protocol
        /// Can be updated by the owner of the contract
        access(contract) var configurationDetails: SchedulerConfig

        access(all) init() {
            self.nextID = 1
            self.lowPriorityScheduledTimestamp = 0.0
            
            self.callbacks <- {}
            self.historicCanceledCallbacks = {}
            self.slotUsedEffort = {
                self.lowPriorityScheduledTimestamp: {
                    Priority.High: 0,
                    Priority.Medium: 0,
                    Priority.Low: 0
                }
            }
            self.slotQueue = {
                self.lowPriorityScheduledTimestamp: {}
            }
            
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

            self.configurationDetails = SchedulerConfig(
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
                historicStatusLimit: 30.0 * 24.0 * 60.0 * 60.0 // 30 days
            )
        }

        /// Gets a struct containing all the configuration details
        /// of the Scheduler resource
        access(all) fun getConfigurationDetails(): SchedulerConfig {
            return self.configurationDetails
        }

        /// sets all the configuration details for the Scheduler resource
        access(UpdateConfig) fun setConfigurationDetails(newConfig: SchedulerConfig) {
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

        /// get status of the scheduled callback, if the callback is not found nil is returned.
        access(all) view fun getStatus(id: UInt64): Status? {

            if let callback = self.borrowCallback(id: id) {
                return callback.status
            }

            // if the callback is not found in the callbacks map, we check the callback status map for historic status
            if let historic = self.historicCanceledCallbacks[id] {
                return Status.Canceled
            } else if id < self.nextID {
                // historicCanceledCallbacks only stores canceled callbacks
                // because the only other possible status for finalized callbacks is Executed
                // Since the ID is a monotonically increasing number,
                // we know that any ID that is less than the next ID and not in the 
                // active callbacks map must have been executed
                return Status.Executed
            }

            return nil
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
            // Remove fractional values from the timestamp
            let sanitizedTimestamp = UFix64(UInt64(timestamp))

            // Use the estimate function to validate inputs
            let estimate = self.estimate(
                data: data,
                timestamp: sanitizedTimestamp,
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
                data: data,
                originalTimestamp: sanitizedTimestamp,
                priority: priority,
                executionEffort: executionEffort,
                fees: <- fees,
                scheduledTimestamp: estimate.timestamp!
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
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid timestamp: \(sanitizedTimestamp) is in the past, current timestamp: \(getCurrentBlock().timestamp)")
            }

            if executionEffort > self.configurationDetails.priorityEffortLimit[priority]! {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort of \(self.configurationDetails.priorityEffortLimit[priority]!)")
            }

            if executionEffort < self.configurationDetails.minimumExecutionEffort {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: \(executionEffort) is less than the minimum execution effort of \(self.configurationDetails.minimumExecutionEffort)")
            }

            let fee = self.calculateFee(executionEffort: executionEffort, priority: priority, data: data)

            let scheduledTimestamp = self.calculateScheduledTimestamp(
                timestamp: sanitizedTimestamp, 
                priority: priority, 
                executionEffort: executionEffort
            )

            if scheduledTimestamp == nil {
                return EstimatedCallback(flowFee: fee, timestamp: nil, error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort for the requested timestamp.")
            }

            if priority == Priority.Low {
                return EstimatedCallback(flowFee: fee, timestamp: scheduledTimestamp, error: "Invalid Priority: Cannot estimate for Low Priority callbacks. They will be included in the first block with available space.")
            }

            return EstimatedCallback(flowFee: fee, timestamp: scheduledTimestamp, error: nil)
        }

        /// calculateScheduledTimestamp calculates the timestamp at which a callback 
        /// can be scheduled. It takes into account the priority of the callback and 
        /// the execution effort.
        /// - If the callback is low priority, it returns the lowPriorityScheduledTimestamp 
        ///    as a special value.
        /// - If the callback is high priority, it returns the timestamp if there is enough 
        ///    space or nil if there is no space left.
        /// - If the callback is medium priority and there is no space left it finds next 
        ///    available timestamp.
        access(contract) view fun calculateScheduledTimestamp(
            timestamp: UFix64, 
            priority: Priority, 
            executionEffort: UInt64
        ): UFix64? {
            if priority == Priority.Low {
                return self.lowPriorityScheduledTimestamp
            }

            let used = self.slotUsedEffort[timestamp]
            // if nothing is scheduled at this timestamp, we can schedule at provided timestamp
            if used == nil { 
                return timestamp
            }
            
            let available = self.getSlotAvailableEffort(timestamp: timestamp, priority: priority)
            // if theres enough space, we can schedule at provided timestamp
            if executionEffort <= available {
                return timestamp
            } else if priority == Priority.High {
                // high priority demands scheduling at exact timestamp or failing
                return nil
            }

            // if there is no space left for medium priority we search for next available timestamp
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

            // Get the maxiumum allowed for a priority including shared
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

        /// add callback to the queue and updates all the internal state as well as emit an event
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
            }

            // Add this callback id to the slot
            let slotQueue = self.slotQueue[slot]!
            slotQueue[callback.id] = callback.executionEffort
            self.slotQueue[slot] = slotQueue
            
            // Add the execution effort for this callback to the total for the slot's priority
            let slotEfforts = self.slotUsedEffort[slot]!
            slotEfforts[callback.priority] = slotEfforts[callback.priority]! + callback.executionEffort
            self.slotUsedEffort[slot] = slotEfforts

            emit Scheduled(
                id: callback.id,
                priority: callback.priority.rawValue,
                timestamp: slot,
                executionEffort: callback.executionEffort,
                fees: callback.fees.balance,
                callbackOwner: callback.handler.address
            )

            self.callbacks[callback.id] <-! callback
        }
  
        /// process scheduled callbacks and prepare them for execution. 
        /// It iterates over all the timestamps in the queue and processes the callbacks that are 
        /// eligible for execution. It also emits an event for each callback that is processed.
        access(contract) fun process() {

            let lowPriorityTimestamp = self.lowPriorityScheduledTimestamp
            let lowPriorityCallbacks = self.slotQueue[lowPriorityTimestamp] ?? {}

            let currentTimestamp = getCurrentBlock().timestamp
            
            // find all timestamps that are in the past
            let pastTimestamp = view fun (timestamp: UFix64): Bool {
                // don't add low priority timestamp to the past timestamps
                if timestamp == lowPriorityTimestamp { 
                    return false
                }

                return timestamp <= currentTimestamp
            }
            let pastTimestamps = self.slotQueue.keys.filter(pastTimestamp)
            
            // process all callbacks from timestamps in the past
            // and add low priority callbacks to the timestamp if there is space
            for timestamp in pastTimestamps {
                let callbackIDs = self.slotQueue[timestamp] ?? {}

                var sortedCallbackIDs: [UInt64] = []
                let highPriorityIDs: [UInt64] = []
                let mediumPriorityIDs: [UInt64] = []

                for id in callbackIDs.keys {
                    let callback = self.borrowCallback(id: id)!

                    if callback.priority == Priority.High {
                        highPriorityIDs.append(id)
                    } else if callback.priority == Priority.Medium {
                        mediumPriorityIDs.append(id)
                    }
                }
                sortedCallbackIDs = highPriorityIDs.concat(mediumPriorityIDs)

                // Add low priority callbacks to the list
                // until the low available effort is used up
                // todo: This could get pretty costly if there are a lot of low priority callbacks
                // in the queue. Figure out how to more efficiently go through the low priority callbacks
                // Could potentially limit the size of the low priority callback queue?
                var lowPriorityEffortAvailable = self.getSlotAvailableEffort(timestamp: timestamp, priority: Priority.Low)
                if lowPriorityEffortAvailable > 0 {
                    for lowCallbackID in lowPriorityCallbacks.keys {
                        let callbackEffort = lowPriorityCallbacks[lowCallbackID]!
                        if callbackEffort <= lowPriorityEffortAvailable {
                            lowPriorityEffortAvailable = lowPriorityEffortAvailable - callbackEffort
                            callbackIDs[lowCallbackID] = callbackEffort
                            lowPriorityCallbacks[lowCallbackID] = nil
                            sortedCallbackIDs.append(lowCallbackID)
                        }
                    }
                }

                for id in sortedCallbackIDs {
                    // Ensure the callback still exists and is scheduled
                    if let callback = self.borrowCallback(id: id) {
                        if callback.status == Status.Scheduled {
                            callback.setStatus(newStatus: Status.Processed)
                            emit Processed(
                                id: id,
                                priority: callback.priority.rawValue,
                                executionEffort: callback.executionEffort,
                                callbackOwner: callback.handler.address
                            )
                        }
                    } else {
                        // This should ideally not happen if callbackIDs are correctly managed
                        // but adding a panic for robustness in case of unexpected state
                        panic("Invalid ID: \(id) callback not found during processing")
                    }
                }
            }

            // garbage collect historic statuses that are older than the limit
            // todo: maybe not do this every time, but only each X blocks to save compute
            let historicCallbacks = self.historicCanceledCallbacks.keys
            for id in historicCallbacks {
                let historicTimestamp = self.historicCanceledCallbacks[id]!
                if historicTimestamp < currentTimestamp - self.configurationDetails.historicStatusLimit {
                    self.historicCanceledCallbacks.remove(key: id)
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
            let refundedFees <- callback.payAndWithdrawFees(multiplierToWithdraw: self.configurationDetails.refundMultiplier)

            emit Canceled(
                id: callback.id,
                priority: callback.priority.rawValue,
                feesReturned: refundedFees.balance,
                feesDeducted: refundedFees.balance >= totalFees ? 0.0 : totalFees - refundedFees.balance,
                callbackOwner: callback.handler.address
            )

            // keep historic Canceled status for future queries after garbage collection
            // We don't keep executed statuses because we can just assume
            // they every ID that is less than the current ID counter
            // that is not Canceled, Scheduled, or Processed is Executed
            self.historicCanceledCallbacks[callback.id] = callback.scheduledTimestamp
            
            self.finalizeCallback(callback: callback, status: Status.Canceled)
            
            return <-refundedFees
        }

        /// execute callback is a system function that is called by FVM to execute a callback by ID.
        /// The callback must be found and in correct state or the function panics and this is a fatal error
        access(contract) fun executeCallback(id: UInt64) {
            let callback = self.borrowCallback(id: id) ?? 
                panic("Invalid ID: Callback with id \(id) not found")

            assert (
                callback.status == Status.Processed,
                message: "Invalid ID: Cannot execute callback with id \(id) because it has not been processed yet"
            )
            
            callback.handler.borrow()!.executeCallback(id: id, data: callback.getData())

            emit Executed(
                id: callback.id,
                priority: callback.priority.rawValue,
                executionEffort: callback.executionEffort,
                fees: callback.fees.balance,
                callbackOwner: callback.handler.address
            )

            // Deposit all the fees into the FlowFees vault
            destroy callback.payAndWithdrawFees(multiplierToWithdraw: 0.0)
            
            self.finalizeCallback(callback: callback, status: Status.Executed)
        }

        /// finalizes the callback by setting the status to executed or canceled and emitting the appropriate event.
        /// It also does garbage collection of the callback resource and the slot map if it is empty.
        /// The callback must be found and in correct state or the function panics.
        /// This function will always be called by the fvm for a given ID
        /// in the same block after it is processed so it won't get processed twice
        access(contract) fun finalizeCallback(callback: &CallbackData, status: Status) {
            pre {
                status == Status.Executed || status == Status.Canceled: 
                    "Invalid status: The provided status to finalizeCallback must be Executed or Canceled"
            }

            callback.setStatus(newStatus: status)

            let callbackID = callback.id
            let slot = callback.scheduledTimestamp

            // remove callback resource
            let callbackRes <- self.callbacks.remove(key: callbackID)
            destroy callbackRes
            
            // garbage collect slots 
            if let callbackQueue = self.slotQueue[slot] {

                callbackQueue[callbackID] = nil
                self.slotQueue[slot] = callbackQueue

                // if the slot is now empty remove it from the maps
                if callbackQueue.keys.length == 0 {
                    self.slotQueue.remove(key: slot)
                    self.slotUsedEffort.remove(key: slot)
                }
            }
        }
    }

    access(all) init() {
        let storagePath = /storage/sharedScheduler
        let scheduler <- create SharedScheduler()
        self.account.storage.save(<-scheduler, to: storagePath)
        
        self.sharedScheduler = self.account.capabilities.storage
            .issue<auth(Cancel) &SharedScheduler>(storagePath)
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

    access(all) fun getSchedulerConfigurationDetails(): SchedulerConfig {
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
            || type.isSubtype(of: Type<Path>())
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

    /// todo protect access to the following functions to only FVM

    /// Process all callbacks that have timestamps in the past
    access(all) fun process() {
        self.sharedScheduler.borrow()!.process()
    }

    /// Execute a processed callback by ID
    access(all) fun executeCallback(id: UInt64) {
        self.sharedScheduler.borrow()!.executeCallback(id: id)
    }
}