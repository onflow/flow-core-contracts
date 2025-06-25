import "FlowToken"

// CallbackScheduler 
access(all) contract CallbackScheduler {

    // Entitlements
    access(all) entitlement mayExecuteCallback
    access(all) entitlement mayCancelCallback
    access(all) entitlement mayReadCallbackStatus

    // Events
    access(all) event CallbackScheduled(ID: UInt64, timestamp: UFix64?, priority: UInt8, executionEffort: UInt64)
    access(all) event CallbackProcessed(ID: UInt64, executionEffort: UInt64)
    access(all) event CallbackExecuted(ID: UInt64)
    access(all) event CallbackCanceled(ID: UInt64)

    // Interfaces

    // The callback handler is an interface that defines a single method executeCallback that 
    // must be implemented by the contract or resource that would like to schedule the callback. 
    // The callback gets executed by the scheduler contract by calling the handler provided to 
    // schedule function with Callback entitlement. The arguments are:
    // - ID of the scheduled callback (this can be useful for any internal tracking)
    // - The data that was passed in during the schedule call
    access(all) struct interface CallbackHandler {
        access(mayExecuteCallback) fun executeCallback(ID: UInt64, data: AnyStruct?)
    }

    access(all) resource interface Scheduler {
         
        // The schedule function is the primary entry point for scheduling a new callback execution. 
        // If scheduling the callback is not possible either due to invalid arguments or due to 
        // unavailable slots, the function should panic. 
        //
        // The schedule function accepts the following arguments:
        //
        // - handler: A capability to an object (struct or resource) in storage that implements 
        //     the callback handler interface. This handler will be invoked at execution time and 
        //     will receive the specified data payload.
        // - timestamp: Specifies the earliest block timestamp at which the callback is eligible 
        //     for execution (fractional seconds values are ignored). It must be set in the future.
        // - priority: An enum value (high, medium, or low) that influences the scheduling 
        //     behavior and determines how soon after the timestamp the callback will be executed.
        // - executionEffort: Defines the maximum computational resources allocated to the 
        //     callback. This also determines the fee charged. Unused computation effort is not refunded.
        // - fees: A Vault resource containing sufficient funds to cover the required computation effort.
        // - Return value: The function returns a ScheduledCallback object.
        access(all) fun schedule(
            callback: Capability<auth(mayExecuteCallback) &{CallbackHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): ScheduledCallback


        // The estimate function calculates the required fee in Flow and expected execution time for 
        // a callback based on timestamp, priority, and execution effort. 
        //
        // If the provided arguments are invalid or the callback cannot be scheduled (e.g., due to 
        // insufficient computation effort or unavailable time slots) the estimate function returns `nil`.
        //        
        // This helps developers ensure sufficient funding and preview the expected scheduling window, 
        // reducing the risk of unnecessary cancellations.
        access(all) fun estimate(
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64
        ): EstimatedCallback?

        // Get status of a scheduled callback.
        access(mayReadCallbackStatus) fun getStatus(ID: UInt64): Status?

        // Cancel a scheduled callback before execution. A partial refund is returned as a Vault resource.
        access(mayCancelCallback) fun cancel(ID: UInt64): @FlowToken.Vault
        
        // Service methods used by the FVM to process and execute callbacks.
        access(all) fun process()
        access(all) fun executeCallback(ID: UInt64)
    }

    // Enums
    access(all) enum Priority: UInt8 {
        access(all) case High
        access(all) case Medium
        access(all) case Low
    }

    access(all) enum Status: UInt8 {
        // mutable statuses
        access(all) case Scheduled
        access(all) case Processed
        // finalized statuses
        access(all) case Executed
        access(all) case Canceled
    }

    // Structs

    // Scheduled callback contains methods to cancel the callback and obtain the status. 
    // It can only be created by the scheduler contract to prevent spoofing.
    access(all) struct ScheduledCallback {
        access(self) let scheduler: Capability<auth(mayCancelCallback, mayReadCallbackStatus) &{Scheduler}>
        access(all) let ID: UInt64
        access(all) let timestamp: UFix64?

        access(all) fun status(): Status? {
            return self.scheduler.borrow()!.getStatus(ID: self.ID)
        }

        access(all) fun cancel(): @FlowToken.Vault {
            return <-self.scheduler.borrow()!.cancel(ID: self.ID)
        }

        access(contract) init(
            scheduler: Capability<auth(mayCancelCallback, mayReadCallbackStatus) &{Scheduler}>, 
            ID: UInt64, 
            timestamp: UFix64?
        ) {
            self.scheduler = scheduler
            self.ID = ID
            self.timestamp = timestamp
        }
    }

    // Estimated callback contains data for estimating callback scheduling.
    access(all) struct EstimatedCallback {
        access(all) let flowFee: UFix64?
        access(all) let timestamp: UFix64?
        access(all) let error: String?

        access(contract) init(flowFee: UFix64?, timestamp: UFix64?, error: String?) {
            self.flowFee = flowFee
            self.timestamp = timestamp
            self.error = error
        }
    }

    // Historic status is an internal representation of status and timestamp 
    // which is used to keep record of past finalised statuses beyond garbage collection.
    access(all) struct HistoricStatus {
        access(contract) let timestamp: UFix64
        access(contract) let status: Status

        access(contract) init(timestamp: UFix64, status: Status) {
            self.timestamp = timestamp
            self.status = status
        }
    }

    // Resources

    // Callback data is internal representation of a scheduled callback which contains all the functionality 
    // to schedule, process and execute each callback. 
    access(all) resource CallbackData {
        access(all) let ID: UInt64
        access(all) let handler: Capability<auth(mayExecuteCallback) &{CallbackHandler}>
        access(all) let data: AnyStruct?
        access(all) let originalTimestamp: UFix64
        access(all) let priority: Priority
        access(all) let executionEffort: UInt64
        access(all) let fees: @FlowToken.Vault
        access(all) var status: Status
        access(all) let scheduledTimestamp: UFix64

        access(contract) init(
            ID: UInt64,
            handler: Capability<auth(mayExecuteCallback) &{CallbackHandler}>,
            data: AnyStruct?,
            originalTimestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault,
            scheduledTimestamp: UFix64
        ) {
            self.ID = ID
            self.handler = handler
            self.data = data
            self.originalTimestamp = originalTimestamp
            self.priority = priority
            self.executionEffort = executionEffort
            self.fees <- fees
            self.status = Status.Scheduled
            self.scheduledTimestamp = scheduledTimestamp
        }

        // setStatus updates the status of the callback.
        // It panics if the callback status is already finalized.
        access(all) fun setStatus(newStatus: Status) {
            if self.status == Status.Executed || self.status == Status.Canceled {
                panic("Invalid status: callback is already finalized")
            }

            if newStatus == Status.Executed && self.status != Status.Processed {
                panic("Invalid status: callback not processed before execution")
            }

            if newStatus == Status.Processed && self.status != Status.Scheduled {
                panic("Invalid status: callback not scheduled before processing")
            }

            self.status = newStatus
        }

        // withdrawFees withdraws fees from the callback based on the refund multiplier.
        // This action is only allowed for canceled callbacks, otherwise it panics.
        access(all) fun withdrawFees(multiplier: UFix64): @FlowToken.Vault {
            if self.status != Status.Canceled {
                panic("Invalid status: can only withdraw fees for canceled callbacks")
            }

            let amount = self.fees.balance * multiplier
            return <- self.fees.withdraw(amount: amount) as! @FlowToken.Vault
        }

        access(contract) fun toString(): String {
            return "callback (ID: ".concat(self.ID.toString())
                .concat(", status: ").concat(self.status.rawValue.toString())
                .concat(", timestamp: ").concat(self.scheduledTimestamp.toString())
                .concat(", priority: ").concat(self.priority.rawValue.toString())
                .concat(", executionEffort: ").concat(self.executionEffort.toString())
                .concat(", fees: ").concat(self.fees.balance.toString())
                .concat(")")
        }
    }

    // Shared scheduler is a resource that implements the Scheduler interface. 
    // It is used as a singleton in the scheduler contract and contains all the functionality 
    // to schedule, process and execute callbacks as well as the internal state. 
    access(all) resource SharedScheduler: Scheduler {
        // nextID contains the next callback ID to be assigned
        access(self) var nextID: UInt64
        // callbacks is a map of callback IDs to callback data
        access(self) var callbacks: @{UInt64: CallbackData}
        // callback status maps historic callback IDs to their finalized statuses
        access(self) var historicStatuses: {UInt64: HistoricStatus}
        // slot queue is a map of timestamps to callback IDs
        access(self) var slotQueue: {UFix64: [UInt64]}
        // slot used effort is a map of timestamps map of priorities and 
        // efforts that has been used for the timeslot
        access(self) var slotUsedEffort: {UFix64: {Priority: UInt64}}
        // slot total effort limit is the maximum effort that can be 
        // allocated to one timeslot by all priorities
        access(self) var slotTotalEffortLimit: UInt64
        // slot shared effort limit is the maximum effort 
        // that can be allocated to high and medium priority 
        // callbacks in addition to the effort reserved for each priority
        access(self) var slotSharedEffortLimit: UInt64
        // priority effort reserve is the amount of effort that is 
        // reserved exclusively for each priority
        access(self) var priorityEffortReserve: {Priority: UInt64}
        // priority effort limit is the maximum effort per priority in a timeslot
        access(self) var priorityEffortLimit: {Priority: UInt64}
        // minimum execution effort is the minimum effort that can be 
        // used for any priority
        access(self) var minimumExecutionEffort: UInt64
        // priority fee multipliers are values we use to calculate the added 
        // processing fee for each priority
        access(self) var priorityFeeMultipliers: {Priority: UFix64}
        // refund multiplier is the portion of the fees that are refunded when a callback is cancelled
        access(self) var refundMultiplier: UFix64
        // historic status limit is the maximum age of a historic status we keep before getting pruned
        access(self) var historicStatusLimit: UFix64
        // low priority callbacks don't get assigned a timestamp, 
        // so we use this special value
        access(self) let lowPriorityScheduledTimestamp: UFix64
        

        access(all) init() {
            self.nextID = 1
            self.callbacks <- {}
            self.historicStatuses = {}
            self.slotQueue = {}
            self.slotUsedEffort = {}
            self.lowPriorityScheduledTimestamp = 0.0
            
            // todo: check if I need to create setters for timeslots
            
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

        // getNextID returns the next ID and increments the ID counter
        access(self) fun getNextID(): UInt64 {
            let nextID = self.nextID
            self.nextID = self.nextID + 1
            return nextID
        }

        // calculateScheduledTimestamp calculates the timestamp at which a callback 
        // can be scheduled. It takes into account the priority of the callback and 
        // the execution effort.
        // - If the callback is low priority, it returns the lowPriorityScheduledTimestamp 
        //    as a special value.
        // - If the callback is high priority, it returns the timestamp if there is enough 
        //    space or nil if there is no space left.
        // - If the callback is medium priority and there is no space left it finds next 
        //    available timestamp.
        access(self) fun calculateScheduledTimestamp(
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

        // slot available effort returns the amount of effort that is available for a given timestamp and priority.
        access(self) fun slotAvailableEffort(timestamp: UFix64, priority: Priority): UInt64 {
            let slotPriority: {CallbackScheduler.Priority: UInt64}? = self.slotUsedEffort[timestamp]
            let priorityLimit = self.priorityEffortLimit[priority]!

            if slotPriority == nil {
                return priorityLimit
            }

            let highReserve = self.priorityEffortReserve[Priority.High]!
            let mediumReserve = self.priorityEffortReserve[Priority.Medium]!

            let highUsed = slotPriority![Priority.High] ?? 0
            let mediumUsed = slotPriority![Priority.Medium] ?? 0
            
            let highSharedUsed = self.minZero(highUsed - highReserve)
            let mediumSharedUsed = self.minZero(mediumUsed - mediumReserve)

            let totalShared = self.slotTotalEffortLimit - highReserve - mediumReserve
            let sharedAvailable = totalShared - highSharedUsed - mediumSharedUsed            

            // we calculate available by calculating available shared effort and 
            // adding any unused reserves for that priority
            let reserve = self.priorityEffortReserve[priority]!
            let used = slotPriority![priority] ?? 0
            let unusedReserve = self.minZero(reserve - used)
            let available = sharedAvailable + unusedReserve
            
            return available
        }

        access(self) fun minZero(_ val: UInt64): UInt64 {
            return val < 0 ? 0 : val
        }

        // calculate fee by converting execution effort to a fee in Flow tokens.
        access(self) fun calculateFee(executionEffort: UInt64, priority: Priority): UFix64 {
            // todo: change to match the actual fee calculation
            let baseFee = UFix64(executionEffort) / 10000.0
            
            return baseFee * self.priorityFeeMultipliers[priority]!
        }

        // add callback to the queue and updates all the internal state as well as emit an event
        access(self) fun addCallback(slot: UFix64, callback: @CallbackData) {
            if self.slotQueue[slot] == nil {
                self.slotQueue[slot] = []
            }
            self.slotQueue[slot]!.append(callback.ID)
            
            if self.slotUsedEffort[slot] == nil {
                self.slotUsedEffort[slot] = {
                    Priority.High: 0,
                    Priority.Medium: 0,
                    Priority.Low: 0
                }
            }
            let slotEfforts = self.slotUsedEffort[slot]!
            slotEfforts[callback.priority] = slotEfforts[callback.priority]! + callback.executionEffort

            emit CallbackScheduled(
                ID: callback.ID,
                timestamp: slot,
                priority: callback.priority.rawValue,
                executionEffort: callback.executionEffort
            )

            self.callbacks[callback.ID] <-! callback
        }
 
        // schedule is the primary entry point for scheduling a new callback within the scheduler contract. 
        // If scheduling the callback is not possible either due to invalid arguments or due to 
        // unavailable slots, the function panics. 
        //
        // The schedule function accepts the following arguments:
        // - handler: A capability to an object (struct or resource) in storage that implements the callback handler 
        //    interface. This handler will be invoked at execution time and will receive the specified data payload.
        // - timestamp: Specifies the earliest block timestamp at which the callback is eligible for execution 
        //    (fractional seconds values are ignored). It must be set in the future.
        // - priority: An enum value (`high`, `medium`, or `low`) that influences the scheduling behavior and determines 
        //    how soon after the timestamp the callback will be executed.
        // - executionEffort: Defines the maximum computational resources allocated to the callback. This also determines 
        //    the fee charged. Unused execution effort is not refunded.
        // - fees: A Vault resource containing sufficient funds to cover the required execution effort.
        access(all) fun schedule(
            callback: Capability<auth(mayExecuteCallback) &{CallbackHandler}>,
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64,
            fees: @FlowToken.Vault
        ): ScheduledCallback {
            if timestamp <= getCurrentBlock().timestamp {
                panic("Invalid timestamp: ".concat(timestamp.toString())
                    .concat(" is in the past, current timestamp: "
                    .concat(getCurrentBlock().timestamp.toString())))
            }

            if executionEffort > self.priorityEffortLimit[priority]! {
                panic("Invalid execution effort: greater than available effort for priority")
            }

            if executionEffort < self.minimumExecutionEffort {
                panic("Invalid execution effort: less than minimum execution effort")
            }

            let requiredFee = self.calculateFee(executionEffort: executionEffort, priority: priority)
            if fees.balance < requiredFee {
                panic("Insufficient fees: required ".concat(requiredFee.toString())
                    .concat(" but only ".concat(fees.balance.toString()).concat(" provided")))
            }

            var scheduledTimestamp: UFix64? = self.calculateScheduledTimestamp(
                timestamp: timestamp, 
                priority: priority, 
                executionEffort: executionEffort
            )
            if scheduledTimestamp == nil {
                panic("Unavailable timestamp: not possible to schedule callback for priority")
            }

            let callbackID = self.getNextID()
            let callback <- create CallbackData(
                ID: callbackID,
                handler: callback,
                data: data,
                originalTimestamp: timestamp,
                priority: priority,
                executionEffort: executionEffort,
                fees: <- fees,
                scheduledTimestamp: scheduledTimestamp!
            )
            self.addCallback(slot: scheduledTimestamp!, callback: <-callback)
            
            return ScheduledCallback(
                scheduler: CallbackScheduler.sharedScheduler, 
                ID: callbackID, 
                timestamp: scheduledTimestamp
            )
        }

        // estimate returns an estimated callback with fees calculations and scheduled timestamp.
        // If the provided arguments are invalid or the callback cannot be scheduled the function returns nil.
        // This function can be used to dry-run the scheduling process.
        access(all) fun estimate(
            data: AnyStruct?,
            timestamp: UFix64,
            priority: Priority,
            executionEffort: UInt64
        ): EstimatedCallback? {
            // low priority callbacks are not supported
            if priority == Priority.Low {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid priority: low priority callbacks estimation not supported")
            }

            if timestamp <= getCurrentBlock().timestamp {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid timestamp: timestamp is in the past")
            }

            if executionEffort > self.priorityEffortLimit[priority]! {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: greater than available effort for priority")
            }

            if executionEffort < self.minimumExecutionEffort {
                return EstimatedCallback(flowFee: nil, timestamp: nil, error: "Invalid execution effort: less than minimum execution effort")
            }

            let fee = self.calculateFee(executionEffort: executionEffort, priority: priority)
            let scheduledTimestamp = self.calculateScheduledTimestamp(
                timestamp: timestamp, 
                priority: priority, 
                executionEffort: executionEffort
            )
            if scheduledTimestamp == nil {
                return nil
            }

            return EstimatedCallback(flowFee: fee, timestamp: scheduledTimestamp, error: nil)
        }

        // get status of the scheduled callback, if the callback is not found nil is returned.
        access(mayReadCallbackStatus) fun getStatus(ID: UInt64): Status? {
            if let callback = &self.callbacks[ID] as &CallbackData? {
                return callback.status
            }

            // if the callback is not found in the callbacks map, we check the callback status map for historic status
            if let historic = self.historicStatuses[ID] {
                return historic.status
            }

            return nil
        }

        // process scheduled callbacks and prepare them for execution. 
        // It iterates over all the timestamps in the queue and processes the callbacks that are 
        // eligible for execution. It also emits an event for each callback that is processed.
        access(all) fun process() {
            
            // todo: minimum priority callbacks should be processed as well if space

            let lowPriorityTimestamp = self.lowPriorityScheduledTimestamp
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
            for timestamp in pastTimestamps {
                let callbackIDs = self.slotQueue[timestamp] ?? []
                
                for ID in callbackIDs {
                    let callback = &self.callbacks[ID] as &CallbackData? ?? 
                        panic("Invalid ID:".concat(ID.toString()).concat(" callback not found"))

                    callback.setStatus(newStatus: Status.Processed)
                    emit CallbackProcessed(ID: ID, executionEffort: callback.executionEffort)
                }
            }

            // garbage collect historic statuses that are older than the limit
            let historicStatuses = self.historicStatuses.keys
            for ID in historicStatuses {
                let historic = self.historicStatuses[ID]
                if historic!.timestamp < currentTimestamp - self.historicStatusLimit {
                    self.historicStatuses.remove(key: ID)
                }
            }
        }

        // cancel scheduled callback and return a portion of the fees that were paid.
        access(mayCancelCallback) fun cancel(ID: UInt64): @FlowToken.Vault {
            let callback = &self.callbacks[ID] as &CallbackData? ?? 
                panic("Invalid ID: callback not found")
            
            self.finalizeCallback(callback: callback, status: Status.Canceled)
            
            return <- callback.withdrawFees(multiplier: self.refundMultiplier)
        }

        // execute callback is a system function that is called by FVM to execute a callback by ID.
        // The callback must be found and in correct state or the function panics and this is a fatal error
        access(all) fun executeCallback(ID: UInt64) {
            let callback = &self.callbacks[ID] as &CallbackData? ?? 
                panic("Invalid ID: callback not found")
            let handlerRef = callback.handler.borrow() ?? 
                panic("Invalid handler: cannot borrow callback handler")

            handlerRef.executeCallback(ID: ID, data: callback.data)
            self.finalizeCallback(callback: callback, status: Status.Executed)
        }

        // finalizes the callback by setting the status to executed or canceled and emitting the appropriate event.
        // It also does garbage collection of the callback resource and the slot map if it is empty.
        // The callback must be found and in correct state or the function panics. 
        access(all) fun finalizeCallback(callback: &CallbackData, status: Status) {
            switch status {
                case Status.Executed:
                    emit CallbackExecuted(ID: callback.ID)
                case Status.Canceled:
                    emit CallbackCanceled(ID: callback.ID)
                default:
                    panic("Invalid status: not final status")
            }

            callback.setStatus(newStatus: status)

            // keep historic status for future queries after garbage collection
            let historic = HistoricStatus(timestamp: callback.scheduledTimestamp, status: status)
            self.historicStatuses[callback.ID] = historic

            // remove callback resource
            let callbackRes <- self.callbacks.remove(key: callback.ID)
            destroy callbackRes

            // garbage collect slots 
            let slot = callback.scheduledTimestamp
            if let slotQueue = self.slotQueue[slot] {
                let trimmedQueue = slotQueue.filter(view fun(id: UInt64): Bool { return id != callback.ID })
                self.slotQueue[slot] = trimmedQueue

                // if the slot is now empty remove it from the maps
                if trimmedQueue.length == 0 {
                    self.slotQueue.remove(key: slot)
                    self.slotUsedEffort.remove(key: slot)
                }
            }
        }
    }

    // singleton instance to be used
    access(self) var sharedScheduler: Capability<auth(mayCancelCallback, mayReadCallbackStatus) &{Scheduler}>

    access(all) init() {
        let storagePath = /storage/sharedScheduler
        let scheduler <- create SharedScheduler()
        self.account.storage.save(<-scheduler, to: storagePath)
        
        self.sharedScheduler = self.account.capabilities.storage
            .issue<auth(mayCancelCallback, mayReadCallbackStatus) &{Scheduler}>(storagePath)
    }

    access(all) fun schedule(
        callback: Capability<auth(mayExecuteCallback) &{CallbackHandler}>,
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
    ): EstimatedCallback? {
        return self.sharedScheduler.borrow()!
            .estimate(
                data: data, 
                timestamp: timestamp, 
                priority: priority, 
                executionEffort: executionEffort,
            )
    }

    access(all) fun getStatus(ID: UInt64): Status? {
        return self.sharedScheduler.borrow()!.getStatus(ID: ID)
    }

    // todo protect access to this functions to only FVM
    access(all) fun process() {
        self.sharedScheduler.borrow()!.process()
    }

    access(all) fun executeCallback(ID: UInt64) {
        self.sharedScheduler.borrow()!.executeCallback(ID: ID)
    }
}