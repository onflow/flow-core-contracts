import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowStakingCollection"
import "FlowToken"
import "FungibleToken"

/// This transaction schedules a recurring transaction to stake and/or withdraw rewards
/// for specified nodes in a Flow Staking Collection
///
/// The transaction is scheduled using the FlowTransactionSchedulerUtils.Manager
/// and the FlowStakingCollection.StakingRewardsHandler contract
///
/// The transaction schedules the next staking operation for the specified timestamp and effort
/// Future scheduled transactions are typically scheduled for one week from the latest execution,
/// but if this conflicts with when staking is disabled during the epoch setup phase, it will be scheduled for the next day
///
/// A user can use this transaction to update their scheduled staking operations, but they need
/// to provide all the node IDs to restake and withdraw every time, not just the new ones.

transaction(effort: UInt64,
            nodeIDsToRestake: [String],
            nodeIDsToWithdraw: [String]) {

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

        // borrow a reference to the callback manager
        let managerRef = account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        // If a transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@FlowStakingCollection.StakingRewardsHandler>(from: FlowStakingCollection.rewardsHandlerStoragePath()) {

            // Create the data for the staking rewards handler
            let data = FlowStakingCollection.StakingRewardsHandlerData(
                nodeIDsToRestake: nodeIDsToRestake,
                delegatorIDsToRestake: [] as [FlowStakingCollection.DelegatorID],
                nodeIDsToWithdraw: nodeIDsToWithdraw,
                delegatorIDsToWithdraw: [] as [FlowStakingCollection.DelegatorID],
                executionEffort: effort
            )

            let handler <- FlowStakingCollection.createRewardsHandler(stakingCollection: stakingCollectionCap, flowTokenVault: flowTokenVaultCap, manager: managerCap, data: data)
        
            account.storage.save(<-handler, to: FlowStakingCollection.rewardsHandlerStoragePath())
            let handlerExecuteCap = account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(FlowStakingCollection.rewardsHandlerStoragePath())

            // borrow a CollectionOwner reference to the handler in storage
            let handlerOwnerRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingRewardsHandler>(from: FlowStakingCollection.rewardsHandlerStoragePath())
                ?? panic("Could not borrow a Handler reference from \(FlowStakingCollection.rewardsHandlerStoragePath())")
            handlerOwnerRef.setSelfCapability(selfCapability: handlerExecuteCap)

            // issue a public capability to the handler
            let publicHandlerCap = account.capabilities.storage.issue<&{FlowTransactionScheduler.TransactionHandler}>(FlowStakingCollection.rewardsHandlerStoragePath())
            account.capabilities.publish(publicHandlerCap, at: FlowStakingCollection.rewardsHandlerPublicPath())

            // schedule the initial transaction
            managerRef.schedule(
                handlerCap: handlerExecuteCap,
                data: nil,
                timestamp: getCurrentBlock().timestamp + 604800.0, // 1 week
                priority: FlowTransactionScheduler.Priority.Low,
                executionEffort: effort
            )
        } else {

            // If the handler already exists, update the data with the new node IDs to restake and withdraw
            // but keep the same delegator IDs

            // borrow a CollectionOwner reference to the handler in storage
            let handlerOwnerRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingRewardsHandler>(from: FlowStakingCollection.rewardsHandlerStoragePath())
                ?? panic("Could not borrow a Handler reference from \(FlowStakingCollection.rewardsHandlerStoragePath())")

            let oldData = handlerOwnerRef.getData()

            let data = FlowStakingCollection.StakingRewardsHandlerData(
                nodeIDsToRestake: nodeIDsToRestake,
                delegatorIDsToRestake: oldData.delegatorIDsToRestake,
                nodeIDsToWithdraw: nodeIDsToWithdraw,
                delegatorIDsToWithdraw: oldData.delegatorIDsToWithdraw,
                executionEffort: effort
            )

            handlerOwnerRef.setNewStakingData(data: data)
        }

        
    }
} 
