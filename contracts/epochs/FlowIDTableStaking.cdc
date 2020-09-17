/*

    FlowIDTableStaking

    The Flow ID Table and Staking contract manages 
    node operators' and delegators' information 
    and flow tokens that are staked as part of the Flow Protocol.

    Nodes submit their stake to the Admin's addNodeInfo Function
    during the staking auction phase.
    This records their info and committd tokens. They also will get a Node
    Object that they can use to stake, unstake, and withdraw rewards.

    The Admin has the authority to remove node records, 
    refund insufficiently staked nodes, pay rewards, 
    and move tokens between buckets.

    All the node info an staking info is publicly accessible
    to any transaction in the network

 */

import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

pub contract FlowIDTableStaking {

    /********************* ID Table and Staking Events **********************/
    pub event NewNodeCreated(nodeID: String, amountCommitted: UFix64)
    pub event TokensCommitted(nodeID: String, amount: UFix64)
    pub event TokensStaked(nodeID: String, amount: UFix64)
    pub event TokensUnStaked(nodeID: String, amount: UFix64)
    pub event NodeRemovedAndRefunded(nodeID: String, amount: UFix64)
    pub event RewardsPaid(nodeID: String, amount: UFix64)
    pub event TokensWithdrawn(nodeID: String, amount: UFix64)

    /// Holds the identity table for all the nodes in the network.
    /// Includes nodes that aren't actively participating
    /// could get a little complex in the future
    /// key = node ID
    /// value = the record of that node's info, tokens, and delegators
    access(contract) var nodes: @{String: NodeRecord}

    /// The minimum amount of tokens that each node type has to stake
    /// in order to be considered valid
    /// key = node role
    /// value = amount of tokens
    access(contract) var minimumStakeRequired: {UInt8: UFix64}

    /// The total amount of tokens that are staked for all the nodes
    /// of each node type during the current epoch
    /// key = node role
    /// value = amount of tokens
    access(contract) var totalTokensStakedByNodeType: {UInt8: UFix64}

    /// The total amount of tokens that are paid as rewards every epoch
    /// could be manually changed by the admin resource
    pub var epochTokenPayout: UFix64

    /// The ratio of the weekly awards that each node type gets
    /// key = node role
    /// value = decimal number between 0 and 1 indicating a percentage
    access(contract) var rewardRatios: {UInt8: UFix64}

    /// Mints Flow tokens for staking rewards
    access(contract) let flowTokenMinter: @FlowToken.Minter

    /// Paths for storing staking resources
    pub let NodeStakerStoragePath: Path
    pub let StakingAdminStoragePath: Path

    /*********** ID Table and Staking Composite Type Definitions *************/

    /// Contains information that is specific to a node in Flow
    /// only lives in this contract
    pub resource NodeRecord {

        /// The unique ID of the node
        /// Set when the node is created
        pub let id: String

        /// The type of node: 
        /// 1 = collection
        /// 2 = consensus
        /// 3 = execution
        /// 4 = verification
        /// 5 = access
        pub var role: UInt8

        /// The address used for networking
        pub(set) var networkingAddress: String

        /// the public key for networking
        pub(set) var networkingKey: String

        /// the public key for staking
        pub(set) var stakingKey: String

        /// The tokens that this node currently has staked
        pub var tokensStaked: @FlowToken.Vault

        /// The tokens that this node has committed to stake for the next epoch.
        pub var tokensCommitted: @FlowToken.Vault

        /// The tokens that this node has unstaked from the previous epoch
        /// Moves to the tokensUnlocked bucket at the end of the epoch.
        pub var tokensUnstaked: @FlowToken.Vault

        /// Tokens that this node is able to withdraw whenever they want
        /// Staking rewards are paid to this bucket
        pub var tokensUnlocked: @FlowToken.Vault

        /// Staking rewards are paid to this bucket
        /// Can be withdrawn whenever
        pub var tokensRewarded: @FlowToken.Vault

        /// list of delegators for this node operator
        pub let delegators: @{UInt32: DelegatorRecord}

        /// The percentage of rewards that this node operator takes from 
        /// the users that are delegating to it
        pub var cutPercentage: UFix64

        /// The amount of tokens that this node has requested to unstake
        /// for the next epoch
        pub(set) var tokensRequestedToUnstake: UFix64

        /// weight as determined by the amount staked after the staking auction
        pub(set) var initialWeight: UInt64

        init(id: String,
             role: UInt8,  /// role that the node will have for future epochs
             networkingAddress: String, 
             networkingKey: String, 
             stakingKey: String, 
             tokensCommitted: @FungibleToken.Vault
        ) {
            pre {
                id.length == 64: "Node ID length must be 32 bytes (64 hex characters)"
                FlowIDTableStaking.nodes[id] == nil: "The ID cannot already exist in the record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0: "The networkingAddress cannot be empty"
                cutPercentage >= 0.0 && cutPercentage <= 1.0: "The cutPercentage must be between 0 and 1."
            }

            /// Assert that the addresses and keys are not already in use
            /// They must be unique
            for nodeID in FlowIDTableStaking.nodes.keys {
                assert (
                    networkingAddress != FlowIDTableStaking.nodes[nodeID]?.networkingAddress,
                    message: "Networking Address is already in use!"
                )
                assert (
                    networkingKey != FlowIDTableStaking.nodes[nodeID]?.networkingKey,
                    message: "Networking Key is already in use!"
                )
                assert (
                    stakingKey != FlowIDTableStaking.nodes[nodeID]?.stakingKey,
                    message: "Staking Key is already in use!"
                )
            }

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
            self.initialWeight = 0
            self.delegators <- {}
            self.cutPercentage = cutPercentage

            self.tokensCommitted <- tokensCommitted as! @FlowToken.Vault
            self.tokensStaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnlocked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRequestedToUnstake = 0.0
        }

        destroy() {
            let flowTokenRef = FlowIDTableStaking.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
            if self.tokensStaked.balance > 0.0 {
                FlowIDTableStaking.totalTokensStakedByNodeType[self.role] = FlowIDTableStaking.totalTokensStakedByNodeType[self.role]! - self.tokensStaked.balance
                flowTokenRef.deposit(from: <-self.tokensStaked)
            } else { destroy self.tokensStaked }
            if self.tokensCommitted.balance > 0.0 {
                flowTokenRef.deposit(from: <-self.tokensCommitted)
            } else { destroy  self.tokensCommitted }
            if self.tokensUnstaked.balance > 0.0 {
                flowTokenRef.deposit(from: <-self.tokensUnstaked)
            } else { destroy  self.tokensUnstaked }
            if self.tokensUnlocked.balance > 0.0 {
                flowTokenRef.deposit(from: <-self.tokensUnlocked)
            } else { destroy  self.tokensUnlocked }
            if self.tokensRewarded.balance > 0.0 {
                flowTokenRef.deposit(from: <-self.tokensRewarded)
            } else { destroy  self.tokensRewarded }

            /// Needs to be fixed
            destroy self.delegators
        }

        /// borrow a reference to to one of the delegators for a node in the record
        /// This gives the caller access to all the public fields on the
        /// object and is basically as if the caller owned the object
        /// The only thing they cannot do is destroy it or move it
        /// This will only be used by the other epoch contracts
        access(contract) fun borrowDelegatorRecord(_ delegatorID: UInt32): &DelegatorRecord {
            pre {
                self.delegators[delegatorID] != nil:
                    "Specified delegator ID does not exist in the record"
            }
            return &self.delegators[delegatorID] as! &DelegatorRecord
        }
    }

    /// Records the staking info associated with a delegator
    /// Stored in the NodeRecord resource for the node that a delegator
    /// is associated with
    pub resource DelegatorRecord {

        /// Tokens this delegator has committed for the next epoch
        /// The actual tokens are stored in the node's committed bucket
        pub(set) var tokensCommitted: UFix64

        /// Tokens this delegator has staked for the current epoch
        /// The actual tokens are stored in the node's staked bucket
        pub(set) var tokensStaked: UFix64

        /// Tokens this delegator has unstaked and is locked for the current epoch
        /// The actual tokens are stored in the node's unstaked bucket
        pub(set) var tokensUnstaked: UFix64

        /// Tokens this delegator has been rewarded and can withdraw
        pub let tokensRewarded: @FlowToken.Vault

        /// Tokens that this delegator unstaked and can withdraw
        pub let tokensUnlocked: @FlowToken.Vault

        /// Tokens that the delegator has requested to unstake
        pub(set) var tokensRequestedToUnstake: UFix64

        init() {
            self.tokensCommitted = 0.0
            self.tokensStaked = 0.0
            self.tokensUnstaked = 0.0
            self.tokensRewarded <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnlocked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRequestedToUnstake = 0.0
        }

        destroy () {
            destroy self.tokensRewarded
            destroy self.tokensUnlocked
        }
    }

    /// Interface that the node operator publishes 
    /// to allow other users to register to delegate to it
    pub resource interface PublicNodeStaker {
        pub fun createNewDelegator(): @NodeDelegator
    }

    /// Resource that the node operator controls for participating
    /// in the staking auction and other Epoch phases.
    pub resource NodeStaker: PublicNodeStaker {

        pub let id: String

        init(id: String) {
            self.id = id
        }

        /// Add new tokens to the system to stake during the next epoch
        pub fun stakeNewTokens(_ tokens: @FungibleToken.Vault) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            /// Add the new tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-tokens)
        }

        /// Stake tokens that are in the tokensUnlocked bucket 
        /// but haven't been officially staked
        pub fun stakeUnlockedTokens(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            /// Add the removed tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensUnlocked.withdraw(amount: amount))
        }

        /// Stake tokens that are in the tokensRewarded bucket 
        /// but haven't been officially staked
        pub fun stakeRewardedTokens(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            self.amountStaked = self.amountStaked + amount

            /// Add the removed tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensRewarded.withdraw(amount: amount))
        }

        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        pub fun requestUnStaking(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            assert (
                nodeRecord.tokensStaked.balance + 
                nodeRecord.tokensCommitted.balance 
                >= amount + nodeRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            self.amountStaked = self.amountStaked - amount

            /// If the request can come from committed, withdraw from committed to unlocked
            if nodeRecord.tokensCommitted.balance >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amount))

            } else {
                /// Get the balance of the tokens that are currently committed
                let amountCommitted = nodeRecord.tokensCommitted.balance

                if amountCommitted > 0.0 {
                    nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amountCommitted))
                }

                /// update request to show that leftover amount is requested to be unstaked
                /// at the end of the current epoch
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake + (amount - amountCommitted)
            }  
        }

        /// Requests to unstake all of the node operators staked and committed tokens,
        /// as well as all the staked and committed tokens of all of their delegators
        pub fun unstakeAll() {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            // iterate through all their delegators, uncommit their tokens
            // and request to unstake their staked tokens
            for delegator in nodeRecord.delegators.keys {
                let record = nodeRecord.borrowDelegatorRecord(delegator)

                if record.tokensCommitted > 0.0 {
                    record.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: record.tokensCommitted))
                    record.tokensCommitted = 0.0
                }

                record.tokensRequestedToUnstake = record.tokensStaked
            }

            self.amountStaked = 0.0

            /// if the request can come from committed, withdraw from committed to unlocked
            if nodeRecord.tokensCommitted.balance >= 0.0 {

                /// withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

            }
            
            /// update request to show that leftover amount is requested to be unstaked
            /// at the end of the current epoch
            nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance
        }

        /// Withdraw tokens from the unlocked bucket
        pub fun withdrawUnlockedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            return <- nodeRecord.tokensUnlocked.withdraw(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            return <- nodeRecord.tokensRewarded.withdraw(amount: amount)
        }

        /// Registers a new delegator with a unique ID for this node operator
        /// and returns a delegator object to the caller
        pub fun createNewDelegator(): @NodeDelegator {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            self.delegatorIDCounter = self.delegatorIDCounter + UInt32(1)

            nodeRecord.delegators[self.delegatorIDCounter] <-! create DelegatorRecord()

            return <-create NodeDelegator(id: self.delegatorIDCounter, nodeID: self.id)
        }

    }

    /// Resource object that the delegator stores in their account
    /// to perform staking actions
    pub resource NodeDelegator {

        /// Each delegator for a node operator has a unique ID
        pub let id: UInt32

        /// The ID of the node operator that this delegator delegates to
        pub let nodeID: String

            // Insert the node to the table
            FlowIDTableStaking.nodes[id] <-! newNode

        /// Delegate new tokens to the node operator
        pub fun delegateNewTokens(from: @FungibleToken.Vault) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            record.tokensCommitted = record.tokensCommitted + from.balance

            nodeRecord.tokensCommitted.deposit(from: <-from)

        }

        /// Delegate tokens from the unlocked bucket to the node operator
        pub fun delegateUnlockedTokens(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            record.tokensCommitted = record.tokensCommitted + amount

            nodeRecord.tokensCommitted.deposit(from: <-record.tokensUnlocked.withdraw(amount: amount))

        }

        /// Delegate tokens from the rewards bucket to the node operator
        pub fun delegateRewardedTokens(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            record.tokensCommitted = record.tokensCommitted + amount

            nodeRecord.tokensCommitted.deposit(from: <-record.tokensRewarded.withdraw(amount: amount))

        }

        /// Request to unstake delegated tokens during the next epoch
        pub fun requestUnstaking(amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            assert (
                record.tokensStaked + 
                record.tokensCommitted 
                >= amount + record.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            /// if the request can come from committed, withdraw from committed to unlocked
            if record.tokensCommitted >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                record.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amount))

                record.tokensCommitted = record.tokensCommitted - amount

            } else {
                /// Get the balance of the tokens that are currently committed
                let amountCommitted = record.tokensCommitted

                if amountCommitted > 0.0 {
                    record.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amountCommitted))
                }

                record.tokensCommitted = record.tokensCommitted - amountCommitted

                /// update request to show that leftover amount is requested to be unstaked
                /// at the end of the current epoch
                record.tokensRequestedToUnstake = record.tokensRequestedToUnstake + (amount - amountCommitted)
            }  
        }

        /// Withdraw tokens from the unlocked bucket
        pub fun withdrawUnlockedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            /// remove the tokens from the unlocked bucket
            return <- record.tokensUnlocked.withdraw(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)

            let record = nodeRecord.borrowDelegatorRecord(self.id)

            /// remove the tokens from the unlocked bucket
            return <- record.tokensRewarded.withdraw(amount: amount)
        }
    }

    /// Admin resource that has the ability to create new staker objects,
    /// remove insufficiently staked nodes at the end of the staking auction,
    /// and pay rewards to nodes at the end of an epoch
    pub resource Admin {

        /// Remove a node from the record
        pub fun removeNode(_ nodeID: String): @NodeRecord {

            // Remove the node from the table
            let node <- FlowIDTableStaking.nodes.remove(key: nodeID)
                ?? panic("Could not find a node with the specified ID")

            return <-node
        }

        /// Iterates through all the registered nodes and if it finds
        /// a node that has insufficient tokens committed for the next epoch
        /// it moves their committed tokens to their unlocked bucket
        /// This will only be called once per epoch
        /// after the staking auction phase
        ///
        /// Also sets the initial weight of all the accepted nodes
        pub fun endStakingAuction(approvedNodeIDs: {String: Bool}) {

            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            /// remove nodes that have insufficient stake
            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                let totalTokensCommitted = FlowIDTableStaking.getTotalCommittedBalance(nodeID)

                /// If the tokens that they have committed for the next epoch
                /// do not meet the minimum requirements
                if (totalTokensCommitted < FlowIDTableStaking.minimumStakeRequired[nodeRecord.role]!) || approvedNodeIDs[nodeID] == nil {

                    /// move their committed tokens back to their unlocked tokens
                    nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

                    /// Set their request to unstake equal to all their staked tokens
                    /// since they are forced to unstake
                    nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance

                    nodeRecord.initialWeight = 0
                } else {
                    /// Set initial weight of all the committed nodes
                    /// TODO: Figure out how to calculate the initial weight for each node
                    nodeRecord.initialWeight = 50
                }
            }
        }

        /// Called at the end of the epoch to pay rewards to node operators
        /// based on the tokens that they have staked
        pub fun payRewards() {

            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            // calculate total reward sum for each node type
            // by multiplying the total amount of rewards by the ration for each node type
            var rewardsForNodeTypes: {UInt8: UFix64} = {}
            rewardsForNodeTypes[UInt8(1)] = FlowIDTableStaking.epochTokenPayout * FlowIDTableStaking.rewardRatios[UInt8(1)]!
            rewardsForNodeTypes[UInt8(2)] = FlowIDTableStaking.epochTokenPayout * FlowIDTableStaking.rewardRatios[UInt8(2)]!
            rewardsForNodeTypes[UInt8(3)] = FlowIDTableStaking.epochTokenPayout * FlowIDTableStaking.rewardRatios[UInt8(3)]!
            rewardsForNodeTypes[UInt8(4)] = FlowIDTableStaking.epochTokenPayout * FlowIDTableStaking.rewardRatios[UInt8(4)]!
            rewardsForNodeTypes[UInt8(5)] = 0.0

            /// iterate through all the nodes
            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                if nodeRecord.tokensStaked.balance == 0.0 { continue }

                /// Calculate the amount of tokens that this node operator receives
                let rewardAmount =  rewardsForNodeTypes[nodeRecord.role]! * (nodeRecord.tokensStaked.balance / FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]!)

                /// Mint the tokens to reward the operator
                let tokenReward <- FlowIDTableStaking.flowTokenMinter.mintTokens(amount: rewardAmount)

                // Iterate through all delegators and reward them their share
                // of the rewards for the tokens they have staked for this node
                for delegator in nodeRecord.delegators.keys {
                    let record = nodeRecord.borrowDelegatorRecord(delegator)

                    let delegatorRewardAmount = (rewardAmount * record.tokensStaked / FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]!) * (1.0 - nodeRecord.cutPercentage)

                    let delegatorReward <- tokenReward.withdraw(amount: delegatorRewardAmount)

                    record.tokensRewarded.deposit(from: <-delegatorReward)
                }

                /// Deposit the rest of their tokens into their tokensRewarded bucket
                nodeRecord.tokensRewarded.deposit(from: <-tokenReward)    
            }
        }

        /// Called at the end of the epoch to move tokens between buckets
        /// for stakers
        /// Tokens that have been committed are moved to the staked bucket
        /// Tokens that were unstaked during the last epoch are fully unlocked
        /// Unstaking requests are filled by moving those tokens from staked to unstaked
        pub fun moveTokens() {
            
            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                // Update total number of tokens staked by all the nodes of each type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + nodeRecord.tokensCommitted.balance

                if nodeRecord.tokensCommitted.balance > 0.0 {
                    nodeRecord.tokensStaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))
                }
                if nodeRecord.tokensUnstaked.balance > 0.0 {
                    nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensUnstaked.withdraw(amount: nodeRecord.tokensUnstaked.balance))
                }
                if nodeRecord.tokensRequestedToUnstake > 0.0 {
                    nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensStaked.withdraw(amount: nodeRecord.tokensRequestedToUnstake))
                }

                for delegator in nodeRecord.delegators.keys {

                    let record = nodeRecord.borrowDelegatorRecord(delegator)

                    record.tokensStaked = record.tokensStaked + record.tokensCommitted
                    record.tokensCommitted = 0.0

                    record.tokensUnlocked.deposit(from: <-nodeRecord.tokensUnstaked.withdraw(amount: record.tokensRequestedToUnstake))

                    nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensStaked.withdraw(amount: record.tokensRequestedToUnstake))

                    record.tokensUnstaked = record.tokensRequestedToUnstake

                    record.tokensStaked = record.tokensStaked - record.tokensRequestedToUnstake

                    // subtract their requested tokens from the total staked for their node type
                    FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! - record.tokensRequestedToUnstake

                    record.tokensRequestedToUnstake = 0.0
                }

                // subtract their requested tokens from the total staked for their node type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! - nodeRecord.tokensRequestedToUnstake

                // Reset the tokens requested field so it can be used for the next epoch
                nodeRecord.tokensRequestedToUnstake = 0.0
            }
        }

        // Changes the total weekly payout to a new value
        pub fun updateEpochTokenPayout(_ newPayout: UFix64) {
            FlowIDTableStaking.epochTokenPayout = newPayout
        }
    }

    /// borrow a reference to to one of the nodes in the record
    /// This gives the caller access to all the public fields on the
    /// objects and is basically as if the caller owned the object
    /// The only thing they cannot do is destroy it or move it
    /// This will only be used by the other epoch contracts
    access(contract) fun borrowNodeRecord(_ nodeID: String): &NodeRecord {
        pre {
            FlowIDTableStaking.nodes[nodeID] != nil:
                "Specified node ID does not exist in the record"
        }
        return &FlowIDTableStaking.nodes[nodeID] as! &NodeRecord
    }

    /****************** Getter Functions for the node Info *******************/

    /// Gets an array of the node IDs that are proposed for the next epoch
    /// Nodes that are proposed are nodes that have enough tokens staked + committed
    /// for the next epoch
    pub fun getProposedNodeIDs(): [String] {
        var proposedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let record = FlowIDTableStaking.borrowNodeRecord(nodeID)

            if self.getTotalCommittedBalance(nodeID) >= self.minimumStakeRequired[record.role]!  {
                proposedNodes.append(nodeID)
            }
        }

        return proposedNodes
    }

    /// Gets an array of all the nodeIDs that are staked.
    /// Only nodes that are participating in the current epoch
    /// can be staked, so this is an array of all the active 
    /// node operators
    pub fun getStakedNodeIDs(): [String] {
        var stakedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let record = FlowIDTableStaking.borrowNodeRecord(nodeID)

            if record.tokensStaked.balance >= self.minimumStakeRequired[record.role]!  {
                stakedNodes.append(nodeID)
            }
        }

        return stakedNodes
    }

    /// Gets an array of all the node IDs that have ever applied
    pub fun getNodeIDs(): [String] {
        return FlowIDTableStaking.nodes.keys
    }

    /// Gets the role of the specified node
    pub fun getNodeRole(_ nodeID: String): UInt8? {
        return FlowIDTableStaking.nodes[nodeID]?.role
    }

    /// Gets the networking Address of the specified node
    pub fun getNodeNetworkingAddress(_ nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.networkingAddress
    }

    /// Gets the networking key of the specified node
    pub fun getNodeNetworkingKey(_ nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.networkingKey
    }

    /// Gets the staking key of the specified node
    pub fun getNodeStakingKey(_ nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.stakingKey
    }

    /// Gets the initial weight of the specified node
    pub fun getNodeInitialWeight(_ nodeID: String): UInt64? {
        return FlowIDTableStaking.nodes[nodeID]?.initialWeight
    }

    /// Gets the total token balance that the specified node currently has staked
    pub fun getNodeStakedBalance(_ nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensStaked.balance
    }

    /// Gets the token balance that the specified node has committed
    /// to add to their stake for the next epoch
    pub fun getNodeCommittedBalance(_ nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensCommitted.balance
    }

    /// Gets the token balance that the specified node has unstaked
    /// from the previous epoch
    pub fun getNodeUnStakedBalance(_ nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensUnstaked.balance
    }

    /// Gets the token balance that the specified node can freely withdraw
    pub fun getNodeUnlockedBalance(_ nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensUnlocked.balance
    }

    /// Gets the token balance that the specified node can freely withdraw
    pub fun getNodeRewardedBalance(_ nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensRewarded.balance
    }

    pub fun getTotalCommittedBalance(_ nodeID: String): UFix64 {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        if (nodeRecord.tokensCommitted.balance + nodeRecord.tokensStaked.balance) < nodeRecord.tokensRequestedToUnstake {
            return 0.0
        } else {
            var sum: UFix64 = 0.0

            sum = nodeRecord.tokensCommitted.balance + nodeRecord.tokensStaked.balance - nodeRecord.tokensRequestedToUnstake

            for delegator in nodeRecord.delegators.keys {
                let record = nodeRecord.borrowDelegatorRecord(delegator)
                sum = sum - record.tokensRequestedToUnstake
            }

            return sum
        }
    }

    pub fun getNodeUnstakingRequest(_ nodeID: String): UFix64 {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensRequestedToUnstake
    }

    /// Functions to return contract fields

    pub fun getMinimumStakeRequirements(): {UInt8: UFix64} {
        return self.minimumStakeRequired
    }

    pub fun getTotalTokensStakedByNodeType(): {UInt8: UFix64} {
        return self.totalTokensStakedByNodeType
    }

    pub fun getEpochTokenPayout(): UFix64 {
        return self.epochTokenPayout
    }

    pub fun getRewardRatios(): {UInt8: UFix64} {
        return self.rewardRatios
    }

    init() {
        self.nodes <- {}

        self.NodeStakerStoragePath = /storage/flowStaker
        self.StakingAdminStoragePath = /storage/flowStakingAdmin

        // These are just arbitrary numbers right now
        self.minimumStakeRequired = {UInt8(1): 125000.0, UInt8(2): 250000.0, UInt8(3): 625000.0, UInt8(4): 67500.0, UInt8(5): 0.0}

        self.totalTokensStakedByNodeType = {UInt8(1): 0.0, UInt8(2): 0.0, UInt8(3): 0.0, UInt8(4): 0.0, UInt8(5): 0.0}

        // Arbitrary number for now
        self.epochTokenPayout = 250000000.0

        // The preliminary percentage of rewards that go to each node type every epoch
        // subject to change
        self.rewardRatios = {UInt8(1): 0.168, UInt8(2): 0.518, UInt8(3): 0.078, UInt8(4): 0.236, UInt8(5): 0.0}

        /// THIS NEEDS TO CHANGE TO A PRIVATE CAPABILITY AFTER TESTING
        self.account.save(<-create Admin(), to: self.StakingAdminStoragePath)
        self.account.link<&Admin>(/public/flowStakingAdmin, target: self.StakingAdminStoragePath)

        /// Borrow a reference to the Flow Token Admin in the account storage
        let flowTokenMinter <- self.account.load<@FlowToken.Minter>(from: /storage/flowTokenMinter)
            ?? panic("Could not borrow a reference to the Flow Token Admin resource")

        /// Create a flowTokenMinterResource
        self.flowTokenMinter <- flowTokenMinter
    }
}
 