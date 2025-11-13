import "FlowTransactionScheduler"
import "FlowStakingCollection"

/// This transaction updates the scheduled staking data for an existing staking rewards handler
///
/// This can be the execution effort, priority, or the nodes and delegators to restake or withdraw rewards for
/// If the user wants to cancel future scheduled staking operations, they can set the effort to 0
///which will cause the next scheduling to fail

transaction(timestamp: UFix64,
            effort: UInt64,
            priority: UInt8,
            nodeIDsToRestake: [String],
            delegatorIDsToRestake: [FlowStakingCollection.DelegatorID],
            nodeIDsToWithdraw: [String],
            delegatorIDsToWithdraw: [FlowStakingCollection.DelegatorID]) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        let priorityEnum = FlowTransactionScheduler.Priority(rawValue: priority)
            ?? FlowTransactionScheduler.Priority.High

        // Create the data for the staking rewards handler
        let data = FlowStakingCollection.StakingRewardsHandlerData(
            nodeIDsToRestake: nodeIDsToRestake,
            delegatorIDsToRestake: delegatorIDsToRestake,
            nodeIDsToWithdraw: nodeIDsToWithdraw,
            delegatorIDsToWithdraw: delegatorIDsToWithdraw,
            executionEffort: effort,
            priority: priorityEnum
        )

        // Borrow a reference to the staking rewards handler
        let handlerRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingRewardsHandler>(from: FlowStakingCollection.rewardsHandlerStoragePath())
            ?? panic("Could not borrow a Handler reference from \(FlowStakingCollection.rewardsHandlerStoragePath())")

        handlerRef.setNewStakingData(data: data)
    }
} 
