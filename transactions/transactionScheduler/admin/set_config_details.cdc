import "FlowTransactionScheduler"

transaction(
            maximumIndividualEffort: UInt64?,
            minimumExecutionEffort: UInt64?,
            highPriorityEffortLimit: UInt64?,
            mediumPriorityEffortLimit: UInt64?,
            lowPriorityEffortLimit: UInt64?,
            maxDataSizeMB: UFix64?,
            priorityFeeMultipliers: {UInt8: UFix64}?,
            refundMultiplier: UFix64?,
            canceledTransactionsLimit: UInt?,
            collectionEffortLimit: UInt64?,
            collectionTransactionsLimit: Int?,
            txRemovalLimit: UInt?) {
    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        // borrow an entitled reference to the SharedScheduler resource
        let schedulerRef = account.storage.borrow<auth(FlowTransactionScheduler.UpdateConfig) &FlowTransactionScheduler.SharedScheduler>(from: /storage/sharedScheduler)
            ?? panic("Could not borrow reference to SharedScheduler resource")

        // get the current config
        let currentConfig = FlowTransactionScheduler.getConfig()

        let highRawValue = FlowTransactionScheduler.Priority.High.rawValue
        let mediumRawValue = FlowTransactionScheduler.Priority.Medium.rawValue
        let lowRawValue = FlowTransactionScheduler.Priority.Low.rawValue

        var newMultipliers: {FlowTransactionScheduler.Priority: UFix64} = {
            FlowTransactionScheduler.Priority.High: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.High]!,
            FlowTransactionScheduler.Priority.Medium: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.Medium]!,
            FlowTransactionScheduler.Priority.Low: currentConfig.priorityFeeMultipliers[FlowTransactionScheduler.Priority.Low]!
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
            priorityEffortLimit: {
                FlowTransactionScheduler.Priority.High: highPriorityEffortLimit ?? currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.High]!,
                FlowTransactionScheduler.Priority.Medium: mediumPriorityEffortLimit ?? currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.Medium]!,
                FlowTransactionScheduler.Priority.Low: lowPriorityEffortLimit ?? currentConfig.priorityEffortLimit[FlowTransactionScheduler.Priority.Low]!
            },
            maxDataSizeMB: maxDataSizeMB ?? currentConfig.maxDataSizeMB,
            priorityFeeMultipliers: newMultipliers,
            refundMultiplier: refundMultiplier ?? currentConfig.refundMultiplier,
            canceledTransactionsLimit: canceledTransactionsLimit ?? currentConfig.canceledTransactionsLimit,
            collectionEffortLimit: collectionEffortLimit ?? currentConfig.collectionEffortLimit,
            collectionTransactionsLimit: collectionTransactionsLimit ?? currentConfig.collectionTransactionsLimit,
            txRemovalLimit: txRemovalLimit ?? currentConfig.getTxRemovalLimit()
        )

        // set the new config
        schedulerRef.setConfig(newConfig: newConfig, txRemovalLimit: txRemovalLimit ?? currentConfig.getTxRemovalLimit())
    }
}