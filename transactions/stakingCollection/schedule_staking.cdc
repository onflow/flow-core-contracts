import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowStakingCollection"
import "FlowToken"
import "FungibleToken"

/// This transaction schedules a recurring transaction to stake and/or withdraw rewards
/// for specified nodes and delegators in a Flow Staking Collection
///
/// The transaction is scheduled using the FlowTransactionSchedulerUtils.Manager
/// and the FlowStakingCollection.StakingRewardsHandler contract
///
/// The transaction schedules the next staking operation for the specified timestamp, effort, and priority
/// Future scheduled transactions are typically scheduled for one week from the latest execution,
/// but if this conflicts with when staking is disabled during the epoch setup phase, it will be scheduled for the next day

transaction(timestamp: UFix64,
            effort: UInt64,
            priority: UInt8,
            nodeIDsToRestake: [String],
            delegatorIDsToRestake: [FlowStakingCollection.DelegatorID],
            nodeIDsToWithdraw: [String],
            delegatorIDsToWithdraw: [FlowStakingCollection.DelegatorID]) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        // if a transaction scheduler manager has not been created for this account yet, create one
        if !account.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            account.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // create a public capability to the callback manager
            let managerRef = account.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            account.capabilities.publish(managerRef, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

        var flowTokenVaultCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>? = nil
        // get the entitled capability to the flow token vault
        let flowTokenVaultCaps = account.capabilities.storage.getControllers(forPath: /storage/flowTokenVault)
        for cap in flowTokenVaultCaps {
            if let cap = cap as? Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault> {
                flowTokenVaultCap = cap
                break
            }
        }

        if flowTokenVaultCap == nil {
            // issue a new entitled capability to the flow token vault
            flowTokenVaultCap = account.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
        }

        var stakingCollectionCap: Capability<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>? = nil

        // Get the staking collection capability
        let stakingCollectionCaps = account.capabilities.storage.getControllers(forPath: FlowStakingCollection.StakingCollectionStoragePath)
        for cap in stakingCollectionCaps {
            if let cap = cap as? Capability<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection> {
                stakingCollectionCap = cap
                break
            }
        }

        if stakingCollectionCap == nil {
            // issue a new entitled capability to the staking collection
            stakingCollectionCap = account.capabilities.storage.issue<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(FlowStakingCollection.StakingCollectionStoragePath)
        }

        // Get the entitled capability to the manager
        var managerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>? = nil
        let managerCaps = account.capabilities.storage.getControllers(forPath: FlowTransactionSchedulerUtils.managerStoragePath)
        for cap in managerCaps {
            if let cap = cap as? Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}> {
                managerCap = cap
                break
            }
        }

        if managerCap == nil {
            // issue a new entitled capability to the manager
            managerCap = account.capabilities.storage.issue<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
        }

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

        // If a transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@FlowStakingCollection.StakingRewardsHandler>(from: FlowStakingCollection.rewardsHandlerStoragePath()) {
            let handler <- FlowStakingCollection.createRewardsHandler(stakingCollection: stakingCollectionCap, flowTokenVault: flowTokenVaultCap, manager: managerCap, data: data)
        
            account.storage.save(<-handler, to: FlowStakingCollection.rewardsHandlerStoragePath())
            account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(FlowStakingCollection.rewardsHandlerStoragePath())
            
            let publicHandlerCap = account.capabilities.storage.issue<&{FlowTransactionScheduler.TransactionHandler}>(FlowStakingCollection.rewardsHandlerStoragePath())
            account.capabilities.publish(publicHandlerCap, at: FlowStakingCollection.rewardsHandlerPublicPath())
        }

        // Get the entitled capability that will be used to create the transaction
        // Need to check both controllers because the order of controllers is not guaranteed
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        
        if let cap = account.capabilities.storage
                            .getControllers(forPath: FlowStakingCollection.rewardsHandlerStoragePath())[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = account.capabilities.storage
                            .getControllers(forPath: FlowStakingCollection.rewardsHandlerStoragePath())[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }

        let handlerRef = handlerCap!.borrow() ?? panic("Could not borrow a Handler reference")

        handlerRef.setSelfCapability(selfCapability: handlerCap!)

        // borrow a reference to the callback manager
        let manager = account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        // schedule transaction
        manager.schedule(
            handlerCap: handlerCap!,
            data: nil,
            timestamp: timestamp,
            priority: priority,
            executionEffort: effort
        )
    }
} 
