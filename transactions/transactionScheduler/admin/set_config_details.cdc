import "FlowTransactionScheduler"

transaction(
            maximumIndividualEffort: UInt64?,
            minimumExecutionEffort: UInt64?,
            slotSharedEffortLimit: UInt64?,
            priorityEffortReserve: {UInt8: UInt64}?,
            priorityEffortLimit: {UInt8: UInt64}?,
            maxDataSizeMB: UFix64?,
            priorityFeeMultipliers: {UInt8: UFix64}?,
            refundMultiplier: UFix64?,
            canceledTransactionsLimit: UInt?,
            collectionEffortLimit: UInt64?,
            collectionTransactionsLimit: Int?) {
    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        // borrow an entitled reference to the SharedScheduler resource
        let schedulerRef = account.storage.borrow<auth(FlowTransactionScheduler.UpdateConfig) &FlowTransactionScheduler.SharedScheduler>(from: /storage/sharedScheduler)
            ?? panic("Could not borrow reference to SharedScheduler resource")

        // get the current config
        let currentConfig = FlowTransactionScheduler.getConfig()

        let highRawValue = FlowTransactionScheduler.Priority.High.rawValue
        let mediumRawValue = FlowTransactionScheduler.Priority.Medium.rawValue
        let lowRawValue = FlowTransactionScheduler.Priority.Low.rawValue

        var newReserves: {FlowTransactionScheduler.Priority: UInt64} = {
            FlowTransactionScheduler.Priority.High: currentConfig.priorityEffortReserve[FlowTransactionScheduler.Priority.High]!,
            FlowTransactionScheduler.Priority.Medium: currentConfig.priorityEffortReserve[FlowTransactionScheduler.Priority.Medium]!,
            FlowTransactionScheduler.Priority.Low: currentConfig.priorityEffortReserve[FlowTransactionScheduler.Priority.Low]!
        }
        var newLimits: {FlowTransactionScheduler.Priority: UInt64} = {
            FlowTransactionScheduler.Priority.High: currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.High]!,
            FlowTransactionScheduler.Priority.Medium: currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.Medium]!,
            FlowTransactionScheduler.Priority.Low: currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.Low]!
        }
        var newMultipliers: {FlowTransactionScheduler.Priority: UFix64} = {
            FlowTransactionScheduler.Priority.High: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.High]!,
            FlowTransactionScheduler.Priority.Medium: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.Medium]!,
            FlowTransactionScheduler.Priority.Low: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.Low]!
        }

        if let reserves = priorityEffortReserve {
            newReserves = {
                FlowTransactionScheduler.Priority.High: reserves[highRawValue]!,
                FlowTransactionScheduler.Priority.Medium: reserves[mediumRawValue]!,
                FlowTransactionScheduler.Priority.Low: reserves[lowRawValue]!
            }
        }
        if let limits = priorityEffortLimit {
            newLimits = {
                FlowTransactionScheduler.Priority.High: limits[highRawValue]!,
                FlowTransactionScheduler.Priority.Medium: limits[mediumRawValue]!,
                FlowTransactionScheduler.Priority.Low: limits[lowRawValue]!
            }
        }
        if let multipliers = priorityFeeMultipliers {
            newMultipliers = {
                FlowTransactionScheduler.Priority.High: multipliers[highRawValue]!,
                FlowTransactionScheduler.Priority.Medium: multipliers[mediumRawValue]!,
                FlowTransactionScheduler.Priority.Low: multipliers[lowRawValue]!
            }
        }

        // create a new config, only updating the fields that are provided as non-nil arguments to this transaction
        let newConfig: FlowTransactionScheduler.Config = FlowTransactionScheduler.Config(
            maximumIndividualEffort: maximumIndividualEffort ?? currentConfig.maximumIndividualEffort,
            minimumExecutionEffort: minimumExecutionEffort ?? currentConfig.minimumExecutionEffort,
            slotSharedEffortLimit: slotSharedEffortLimit ?? currentConfig.slotSharedEffortLimit,
            priorityEffortReserve: newReserves,
            priorityEffortLimit: newLimits,
            maxDataSizeMB: maxDataSizeMB ?? currentConfig.maxDataSizeMB,
            priorityFeeMultipliers: newMultipliers,
            refundMultiplier: refundMultiplier ?? currentConfig.refundMultiplier,
            canceledTransactionsLimit: canceledTransactionsLimit ?? currentConfig.canceledTransactionsLimit,
            collectionEffortLimit: collectionEffortLimit ?? currentConfig.collectionEffortLimit,
            collectionTransactionsLimit: collectionTransactionsLimit ?? currentConfig.collectionTransactionsLimit
        )

        // set the new config
        schedulerRef.setConfig(newConfig: newConfig)
    }
}