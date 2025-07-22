import "FlowToken"
import "FlowFees"

/// FlowCallbackScheduler 
access(all) contract FlowCallbackScheduler {

    /// Entitlements
    access(all) entitlement ExecuteCallback
    access(all) entitlement CancelCallback
    access(all) entitlement ReadCallbackStatus

    /// Events
    access(all) event CallbackScheduled(
        id: UInt64,
        timestamp: UFix64?,
        priority: UInt8,
        executionEffort: UInt64,
        fees: UFix64,
        callbackOwner: Address
    )

    access(all) event CallbackProcessed(
        id: UInt64,
        priority: UInt8,
        executionEffort: UInt64,
        callbackOwner: Address
    )

    access(all) event CallbackExecuted(
        id: UInt64,
        priority: UInt8,
        callbackOwner: Address
    )

    access(all) event CallbackCanceled(
        id: UInt64,
        priority: UInt8,
        callbackOwner: Address
    )

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

    /// Interfaces

    /// The callback handler is an interface that defines a single method executeCallback that 
    /// must be implemented by the contract or resource that would like to schedule the callback. 
    /// The callback gets executed by the scheduler contract by calling the handler provided to 
    /// schedule function with Callback entitlement. The arguments are:
    /// - ID of the scheduled callback (this can be useful for any internal tracking)
    /// - The data that was passed in during the schedule call
    access(all) struct interface CallbackHandler {
        access(ExecuteCallback) fun executeCallback(id: UInt64, data: AnyStruct?)
    }

    /// Structs

    /// Scheduled callback contains methods to cancel the callback and obtain the status. 
    /// It can only be created by the scheduler contract to prevent spoofing.
    access(all) struct ScheduledCallback {
        access(self) let scheduler: Capability<auth(CancelCallback, ReadCallbackStatus) &SharedScheduler>
        access(all) let id: UInt64
        access(all) let timestamp: UFix64?

        access(all) view fun status(): Status? {
            return self.scheduler.borrow()!.getStatus(id: self.id)
        }

        access(contract) init(
            scheduler: Capability<auth(CancelCallback, ReadCallbackStatus) &SharedScheduler>,
            id: UInt64, 
            timestamp: UFix64?
        ) {
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

    /// Callback data is internal representation of a scheduled callback which contains all the functionality 
    /// to schedule, process and execute each callback. 
    access(all) resource CallbackData {
        access(contract) let handler: Capability<auth(ExecuteCallback) &{CallbackHandler}>
        access(contract) let data: AnyStruct?
        access(contract) let fees: @FlowToken.Vault
        access(all) let id: UInt64
        access(all) let originalTimestamp: UFix64
        access(all) let priority: Priority
        access(all) let executionEffort: UInt64
        access(all) var status: Status
        access(all) let scheduledTimestamp: UFix64

        access(contract) init(
            id: UInt64,
            handler: Capability<auth(ExecuteCallback) &{CallbackHandler}>,
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
        access(all) fun setStatus(newStatus: Status) {
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

        /// withdrawFees withdraws fees from the callback based on the refund multiplier.
        /// This action is only allowed for canceled callbacks, otherwise it panics.
        /// It deposits any leftover fees to the FlowFees vault to be used to pay node operator rewards
        access(all) fun withdrawFees(multiplier: UFix64): @FlowToken.Vault {
            let amount = self.fees.balance * multiplier
            let feesToReturn <- self.fees.withdraw(amount: amount) as! @FlowToken.Vault
            FlowFees.deposit(from: <-self.fees.withdraw(amount: self.fees.balance))
            return <-feesToReturn
        }

        access(all) view fun toString(): String {
            return "callback (id: \(self.id), status: \(self.status.rawValue), timestamp: \(self.scheduledTimestamp), priority: \(self.priority.rawValue), executionEffort: \(self.executionEffort))"
        }
    }

    /// Historic status is an internal representation of status and timestamp 
    /// which is used to keep record of past finalised statuses beyond garbage collection.
    access(all) struct HistoricStatus {
        access(contract) let timestamp: UFix64
        access(contract) let status: Status

        access(contract) init(timestamp: UFix64, status: Status) {
            self.timestamp = timestamp
            self.status = status
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

        /// callback status maps historic callback IDs to their finalized statuses
        access(contract) var historicStatuses: {UInt64: HistoricStatus}

        /// slot queue is a map of timestamps to callback IDs and their execution efforts
        access(contract) var slotQueue: {UFix64: {UInt64: UInt64}}

        /// slot used effort is a map of timestamps map of priorities and 
        /// efforts that has been used for the timeslot
        access(contract) var slotUsedEffort: {UFix64: {Priority: UInt64}}

        /// slot total effort limit is the maximum effort that can be 
        /// cumulatively allocated to one timeslot by all priorities
        access(contract) var slotTotalEffortLimit: UInt64

        /// slot shared effort limit is the maximum effort 
        /// that can be allocated to high and medium priority 
        /// callbacks combined after their exclusive effort reserves have been filled
        access(contract) var slotSharedEffortLimit: UInt64

        /// priority effort reserve is the amount of effort that is 
        /// reserved exclusively for each priority
        access(contract) var priorityEffortReserve: {Priority: UInt64}

        /// priority effort limit is the maximum effort per priority in a timeslot
        access(contract) var priorityEffortLimit: {Priority: UInt64}

        /// minimum execution effort is the minimum effort that can be 
        /// used for any priority
        access(contract) var minimumExecutionEffort: UInt64

        /// priority fee multipliers are values we use to calculate the added 
        /// processing fee for each priority
        access(contract) var priorityFeeMultipliers: {Priority: UFix64}

        /// refund multiplier is the portion of the fees that are refunded when a callback is cancelled
        access(contract) var refundMultiplier: UFix64

        /// historic status limit is the maximum age of a historic status we keep before getting pruned
        access(contract) var historicStatusLimit: UFix64

        /// low priority callbacks don't get assigned a timestamp, 
        /// so we use this special value
        access(contract) let lowPriorityScheduledTimestamp: UFix64

        access(all) init() {
            self.nextID = 1
            self.callbacks <- {}
            self.historicStatuses = {}
            self.slotQueue = {}
            self.slotUsedEffort = {}
            self.lowPriorityScheduledTimestamp = 0.0
            
            /// todo: check if I need to create setters for timeslots
            
            /* slot efforts and limits look like this:

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
            
            self.slotTotalEffortLimit = 35_000 
            self.slotSharedEffortLimit = 10_000
            self.minimumExecutionEffort = 5
    
            self.priorityEffortReserve = {
                Priority.High: 20_000,
                Priority.Medium: 5_000,
                Priority.Low: 0
            }
            
            self.priorityEffortLimit = {
                Priority.High: self.priorityEffortReserve[Priority.High]! + self.slotSharedEffortLimit,
                Priority.Medium: self.priorityEffortReserve[Priority.Medium]! + self.slotSharedEffortLimit,
                Priority.Low: 5_000
            }

            self.priorityFeeMultipliers = {
                Priority.High: 10.0,
                Priority.Medium: 5.0,
                Priority.Low: 2.0
            }
            
            self.refundMultiplier = 0.5
            self.historicStatusLimit = 30.0 * 24.0 * 60.0 * 60.0 // 30 days
        }

        /// getNextID returns the next ID and increments the ID counter
        access(self) fun getNextID(): UInt64 {
            let nextID = self.nextID
            self.nextID = self.nextID + 1
            return nextID
        }

        /// schedule is the primary entry point for scheduling a new callback within the scheduler contract. 
        /// If scheduling the callback is not possible either due to invalid arguments or due to 
        /// unavailable slots, the function panics. 
        //
        /// The schedule function accepts the following arguments:
        /// @param: callback: A capability to an object (struct or resource) in storage that implements the callback handler 
        ///    interface. This handler will be invoked at execution time and will receive the specified data payload.
        /// @param: timestamp: Specifies the earliest block timestamp at which the callback is eligible for execution 
        ///    (fractional seconds values are ignored). It must be set in the future.
        /// @param: priority: An enum value (`high`, `medium`, or `low`) that influences the scheduling behavior and determines 
        ///    how soon after the timestamp the callback will be executed.
        /// @param: executionEffort: Defines the maximum computational resources allocated to the callback. This also determines 
        ///    the fee charged. Unused execution effort is not refunded.
        /// @param: fees: A Vault resource containing sufficient funds to cover the required execution effort.
        access(all) fun schedule(
            callback: Capability<auth(ExecuteCallback) &{CallbackHandler}>,
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

            let callbackID = self.getNextID()
            let callback <- create CallbackData(
                id: callbackID,
                handler: callback,
                data: data,
                originalTimestamp: timestamp,
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
        access(all) view fun estimate(
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64
        ): EstimatedCallback {

            if timestamp <= getCurrentBlock().timestamp {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid timestamp: \(timestamp) is in the past, current timestamp: \(getCurrentBlock().timestamp)")
            }

            if executionEffort > self.priorityEffortLimit[priority]! {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: \(executionEffort) is greater than the priority's available effort of \(self.priorityEffortLimit[priority]!)")
            }

            if executionEffort < self.minimumExecutionEffort {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: \(executionEffort) is less than the minimum execution effort of \(self.minimumExecutionEffort)")
            }

            let fee = self.calculateFee(executionEffort: executionEffort, priority: priority)

            let scheduledTimestamp = self.calculateScheduledTimestamp(
                timestamp: timestamp, 
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

        /// get status of the scheduled callback, if the callback is not found nil is returned.
        access(ReadCallbackStatus) view fun getStatus(id: UInt64): Status? {

            if let callback = &self.callbacks[id] as &CallbackData? {
                return callback.status
            }

            // if the callback is not found in the callbacks map, we check the callback status map for historic status
            if let historic = self.historicStatuses[id] {
                return historic.status
            } else if id < self.nextID {
                return Status.Executed
            }

            return nil
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
        access(self) view fun calculateScheduledTimestamp(
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
            
            let available = self.slotAvailableEffort(timestamp: timestamp, priority: priority)
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
        access(all) view fun slotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {
            // Get the maxiumum allowed for a priority including shared
            let priorityLimit = self.priorityEffortLimit[priority]!
            
            // If nothing has been claimed for the requested timestamp,
            // return the full amount
            if !self.slotUsedEffort.containsKey(timestamp) {
                return priorityLimit
            }

            // Get the mapping of how much effort has been used
            // for each priority for the timestamp
            let slotPriorityEffortsUsed = self.slotUsedEffort[timestamp]!

            // Get the exclusive reserves for each priority
            let highReserve = self.priorityEffortReserve[Priority.High]!
            let mediumReserve = self.priorityEffortReserve[Priority.Medium]!

            // Get how much effort has been used for each priority
            let highUsed = slotPriorityEffortsUsed[Priority.High] ?? 0
            let mediumUsed = slotPriorityEffortsUsed[Priority.Medium] ?? 0

            // If it is low priority, return whatever effort is remaining
            // under 5000
            if priority == Priority.Low {
                let totalEffortRemaining = self.slotTotalEffortLimit - (highUsed + mediumUsed)
                return totalEffortRemaining < priorityLimit ? totalEffortRemaining : priorityLimit
            }
            
            // Get how much shared effort has been used for each priority
            // Ensure the results are always zero or positive
            let highSharedUsed: UInt64 = highReserve >= highUsed ? 0 : highUsed - highReserve
            let mediumSharedUsed: UInt64 = mediumReserve >= mediumUsed ? 0 : mediumUsed - mediumReserve

            // Get the theoretical total shared amount between priorities
            let totalShared = self.slotTotalEffortLimit - highReserve - mediumReserve

            // Get the amount of shared effort available
            let sharedAvailable = totalShared - highSharedUsed - mediumSharedUsed        

            // we calculate available by calculating available shared effort and 
            // adding any unused reserves for that priority
            let reserve = self.priorityEffortReserve[priority]!
            let used = slotPriorityEffortsUsed[priority] ?? 0
            let unusedReserve: UInt64 = used >= reserve ? 0 : reserve - used
            let available = sharedAvailable + unusedReserve
            
            return available
        }

        /// calculate fee by converting execution effort to a fee in Flow tokens.
        access(all) view fun calculateFee(executionEffort: UInt64, priority: Priority): UFix64 {
            // Use the official FlowFees calculation
            let baseFee = FlowFees.computeFees(inclusionEffort: 1.0, executionEffort: UFix64(executionEffort))
            
            return baseFee * self.priorityFeeMultipliers[priority]!
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

            emit CallbackScheduled(
                id: callback.id,
                timestamp: slot,
                priority: callback.priority.rawValue,
                executionEffort: callback.executionEffort,
                fees: callback.fees.balance,
                callbackOwner: callback.handler.address
            )

            self.callbacks[callback.id] <-! callback
        }
  
        /// process scheduled callbacks and prepare them for execution. 
        /// It iterates over all the timestamps in the queue and processes the callbacks that are 
        /// eligible for execution. It also emits an event for each callback that is processed.
        access(all) fun process() {

            let lowPriorityTimestamp = self.lowPriorityScheduledTimestamp
            let lowPriorityCallbacks = self.slotQueue[lowPriorityTimestamp]!

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
                    if self.getPriority(id: id) == Priority.High {
                        highPriorityIDs.append(id)
                    }
                    if self.getPriority(id: id) == Priority.Medium {
                        mediumPriorityIDs.append(id)
                    }
                }
                sortedCallbackIDs = highPriorityIDs.concat(mediumPriorityIDs)

                // Add low priority callbacks to the list
                // until the low available effort is used up
                // todo: This could get pretty costly if there are a lot of low priority callbacks
                // in the queue. Figure out how to more efficiently go through the low priority callbacks
                // Could potentially limit the size of the low priority callback queue?
                var lowPriorityEffortAvailable = self.slotAvailableEffort(timestamp: timestamp, priority: Priority.Low)
                for lowCallbackID in lowPriorityCallbacks.keys {
                    let callbackEffort = lowPriorityCallbacks[lowCallbackID]!
                    if callbackEffort <= lowPriorityEffortAvailable {
                        lowPriorityEffortAvailable = lowPriorityEffortAvailable - callbackEffort
                        callbackIDs[lowCallbackID] = callbackEffort
                        lowPriorityCallbacks[lowCallbackID] = nil
                        sortedCallbackIDs.append(lowCallbackID)
                    }
                }

                for id in sortedCallbackIDs {
                    // Ensure the callback still exists and is scheduled
                    if let callback = &self.callbacks[id] as &CallbackData? {
                        if callback.status == Status.Scheduled {
                            callback.setStatus(newStatus: Status.Processed)
                            emit CallbackProcessed(
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
            let historicStatuses = self.historicStatuses.keys
            for id in historicStatuses {
                let historic = self.historicStatuses[id]
                if historic!.timestamp < currentTimestamp - self.historicStatusLimit {
                    self.historicStatuses.remove(key: id)
                }
            }
        }

        /// cancel scheduled callback and return a portion of the fees that were paid.
        access(CancelCallback) fun cancel(id: UInt64): @FlowToken.Vault {
            let callback = &self.callbacks[id] as &CallbackData? ?? 
                panic("Invalid ID: \(id) callback not found")

            // Remove this callback id from its slot
            let slotQueue = self.slotQueue[callback.scheduledTimestamp]!
            slotQueue[id] = nil
            self.slotQueue[callback.scheduledTimestamp] = slotQueue
            
            // Subtract the execution effort for this callback from the slot's priority
            // Low priority effots don't count toward a slot's execution effort
            // so we don't need to subtract anything for them
            if callback.priority != Priority.Low {
                
                let slotEfforts = self.slotUsedEffort[callback.scheduledTimestamp]!
                slotEfforts[callback.priority] = slotEfforts[callback.priority]! - callback.executionEffort
                self.slotUsedEffort[callback.scheduledTimestamp] = slotEfforts
            }

            let refundedFees <- callback.withdrawFees(multiplier: self.refundMultiplier)
            
            self.finalizeCallback(callback: callback, status: Status.Canceled)
            
            return <-refundedFees
        }

        /// execute callback is a system function that is called by FVM to execute a callback by ID.
        /// The callback must be found and in correct state or the function panics and this is a fatal error
        access(all) fun executeCallback(id: UInt64) {
            let callback = &self.callbacks[id] as &CallbackData? ?? 
                panic("Invalid ID: \(id) callback not found")
            
            callback.handler.borrow()!.executeCallback(id: id, data: callback.data)
            
            self.finalizeCallback(callback: callback, status: Status.Executed)
        }

        /// finalizes the callback by setting the status to executed or canceled and emitting the appropriate event.
        /// It also does garbage collection of the callback resource and the slot map if it is empty.
        /// The callback must be found and in correct state or the function panics.
        /// This function will always be called by the fvm for a given ID
        /// in the same block after it is processed so it won't get processed twice
        access(all) fun finalizeCallback(callback: &CallbackData, status: Status) {
            callback.setStatus(newStatus: status)
            
            switch status {
                case Status.Executed:
                    emit CallbackExecuted(
                        id: callback.id,
                        priority: callback.priority.rawValue,
                        callbackOwner: callback.handler.address
                    )
                case Status.Canceled:
                    emit CallbackCanceled(
                        id: callback.id,
                        priority: callback.priority.rawValue,
                        callbackOwner: callback.handler.address
                    )

                    // keep historic Canceled status for future queries after garbage collection
                    // We don't keep executed statuses because we can just assume
                    // they every ID that is less than the current ID counter
                    // that is not Canceled, Scheduled, or Processed is executed
                    let historic = HistoricStatus(timestamp: callback.scheduledTimestamp, status: status)
                    self.historicStatuses[callback.id] = historic
                default:
                    panic("Invalid status: not final status")
            }

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

        access(all) view fun getPriority(id: UInt64): Priority? {
            if let callback = &self.callbacks[id] as &CallbackData? {
                return callback.priority
            } else {
                return nil
            }
        }
    }

    /// singleton instance to be used
    access(self) var sharedScheduler: Capability<auth(CancelCallback, ReadCallbackStatus) &SharedScheduler>

    access(all) init() {
        let storagePath = /storage/sharedScheduler
        let scheduler <- create SharedScheduler()
        self.account.storage.save(<-scheduler, to: storagePath)
        
        self.sharedScheduler = self.account.capabilities.storage
            .issue<auth(CancelCallback, ReadCallbackStatus) &SharedScheduler>(storagePath)
    }

    access(all) fun schedule(
        callback: Capability<auth(ExecuteCallback) &{CallbackHandler}>,
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

    access(all) view fun estimate(
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
        return self.sharedScheduler.borrow()!.slotAvailableEffort(timestamp: timestamp, priority: priority)
    }

    // todo protect access to this functions to only FVM
    access(all) fun process() {
        self.sharedScheduler.borrow()!.process()
    }

    access(all) fun executeCallback(id: UInt64) {
        self.sharedScheduler.borrow()!.executeCallback(id: id)
    }
}