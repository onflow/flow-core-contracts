import "FlowCallbackScheduler"

transaction(slotSharedEffortLimit: UInt64?,
            priorityEffortReserve: {UInt8: UInt64}?,
            priorityEffortLimit: {UInt8: UInt64}?,
            minimumExecutionEffort: UInt64?,
            priorityFeeMultipliers: {UInt8: UFix64}?,
            refundMultiplier: UFix64?,
            historicStatusLimit: UFix64?) {
    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        // borrow an entitled reference to the SharedScheduler resource
        let schedulerRef = account.storage.borrow<auth(FlowCallbackScheduler.UpdateMetadata) &FlowCallbackScheduler.SharedScheduler>(from: /storage/sharedScheduler)
            ?? panic("Could not borrow reference to SharedScheduler resource")

        // get the current config
        let currentConfig = schedulerRef.getConfigMetadata()

        let highRawValue = FlowCallbackScheduler.Priority.High.rawValue
        let mediumRawValue = FlowCallbackScheduler.Priority.Medium.rawValue
        let lowRawValue = FlowCallbackScheduler.Priority.Low.rawValue

        var newReserves: {FlowCallbackScheduler.Priority: UInt64} = {
            FlowCallbackScheduler.Priority.High: currentConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!,
            FlowCallbackScheduler.Priority.Medium: currentConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!,
            FlowCallbackScheduler.Priority.Low: currentConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!
        }
        var newLimits: {FlowCallbackScheduler.Priority: UInt64} = {
            FlowCallbackScheduler.Priority.High: currentConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!,
            FlowCallbackScheduler.Priority.Medium: currentConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!,
            FlowCallbackScheduler.Priority.Low: currentConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!
        }
        var newMultipliers: {FlowCallbackScheduler.Priority: UFix64} = {
            FlowCallbackScheduler.Priority.High: currentConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!,
            FlowCallbackScheduler.Priority.Medium: currentConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!,
            FlowCallbackScheduler.Priority.Low: currentConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!
        }

        if let reserves = priorityEffortReserve {
            newReserves = {
                FlowCallbackScheduler.Priority.High: reserves[highRawValue]!,
                FlowCallbackScheduler.Priority.Medium: reserves[mediumRawValue]!,
                FlowCallbackScheduler.Priority.Low: reserves[lowRawValue]!
            }
        }
        if let limits = priorityEffortLimit {
            newLimits = {
                FlowCallbackScheduler.Priority.High: limits[highRawValue]!,
                FlowCallbackScheduler.Priority.Medium: limits[mediumRawValue]!,
                FlowCallbackScheduler.Priority.Low: limits[lowRawValue]!
            }
        }
        if let multipliers = priorityFeeMultipliers {
            newMultipliers = {
                FlowCallbackScheduler.Priority.High: multipliers[highRawValue]!,
                FlowCallbackScheduler.Priority.Medium: multipliers[mediumRawValue]!,
                FlowCallbackScheduler.Priority.Low: multipliers[lowRawValue]!
            }
        }

        // create a new config, only updating the fields that are provided as non-nil arguments to this transaction
        let newConfig: FlowCallbackScheduler.SchedulerConfig = FlowCallbackScheduler.SchedulerConfig(
            slotSharedEffortLimit: slotSharedEffortLimit ?? currentConfig.slotSharedEffortLimit,
            priorityEffortReserve: newReserves,
            priorityEffortLimit: newLimits,
            minimumExecutionEffort: minimumExecutionEffort ?? currentConfig.minimumExecutionEffort,
            priorityFeeMultipliers: newMultipliers,
            refundMultiplier: refundMultiplier ?? currentConfig.refundMultiplier,
            historicStatusLimit: historicStatusLimit ?? currentConfig.historicStatusLimit
        )

        // set the new config
        schedulerRef.setConfigMetadata(newConfig: newConfig)
    }
}