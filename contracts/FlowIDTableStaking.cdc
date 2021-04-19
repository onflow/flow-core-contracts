import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowIDTableStaking {

    /****** ID Table and Staking Events ******/

    pub event NewEpoch(totalStaked: UFix64, totalRewardPayout: UFix64)

    /// Node Events
    pub event NewNodeCreated(nodeID: String, role: UInt8, amountCommitted: UFix64)
    pub event TokensCommitted(nodeID: String, amount: UFix64)
    pub event TokensStaked(nodeID: String, amount: UFix64)
    pub event TokensUnstaking(nodeID: String, amount: UFix64)
    pub event TokensUnstaked(nodeID: String, amount: UFix64)
    pub event NodeRemovedAndRefunded(nodeID: String, amount: UFix64)
    pub event RewardsPaid(nodeID: String, amount: UFix64)
    pub event UnstakedTokensWithdrawn(nodeID: String, amount: UFix64)
    pub event RewardTokensWithdrawn(nodeID: String, amount: UFix64)

    /// Delegator Events
    pub event NewDelegatorCreated(nodeID: String, delegatorID: UInt32)
    pub event DelegatorTokensCommitted(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorTokensStaked(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorTokensUnstaking(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorTokensUnstaked(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorRewardsPaid(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorUnstakedTokensWithdrawn(nodeID: String, delegatorID: UInt32, amount: UFix64)
    pub event DelegatorRewardTokensWithdrawn(nodeID: String, delegatorID: UInt32, amount: UFix64)

    /// Contract Field Change Events
    pub event NewDelegatorCutPercentage(newCutPercentage: UFix64)
    pub event NewWeeklyPayout(newPayout: UFix64)
    pub event NewStakingMinimums(newMinimums: {UInt8: UFix64})

    /// Holds the identity table for all the nodes in the network.
    /// Includes nodes that aren't actively participating
    /// key = node ID
    access(contract) var nodes: @{String: NodeRecord}

    /// The minimum amount of tokens that each node type has to stake
    /// in order to be considered valid
    access(contract) var minimumStakeRequired: {UInt8: UFix64}

    /// The total amount of tokens that are staked for all the nodes
    /// of each node type during the current epoch
    access(contract) var totalTokensStakedByNodeType: {UInt8: UFix64}

    /// The total amount of tokens that are paid as rewards every epoch
    /// could be manually changed by the admin resource
    access(contract) var epochTokenPayout: UFix64

    /// The ratio of the weekly awards that each node type gets
    access(contract) var rewardRatios: {UInt8: UFix64}

    /// The percentage of rewards that every node operator takes from
    /// the users that are delegating to it
    access(contract) var nodeDelegatingRewardCut: UFix64

    /// Paths for storing staking resources
    pub let NodeStakerStoragePath: StoragePath
    pub let NodeStakerPublicPath: PublicPath
    pub let StakingAdminStoragePath: StoragePath
    pub let DelegatorStoragePath: StoragePath

    /*********** ID Table and Staking Composite Type Definitions *************/

    /// Contains information that is specific to a node in Flow
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

        pub(set) var networkingAddress: String

        pub(set) var networkingKey: String

        pub(set) var stakingKey: String

        /// The total tokens that only this node currently has staked, not including delegators
        /// This value must always be above the minimum requirement to stay staked or accept delegators
        pub var tokensStaked: @FlowToken.Vault

        /// The tokens that this node has committed to stake for the next epoch.
        pub var tokensCommitted: @FlowToken.Vault

        /// The tokens that this node has unstaked from the previous epoch
        /// Moves to the tokensUnstaked bucket at the end of the epoch.
        pub var tokensUnstaking: @FlowToken.Vault

        /// Tokens that this node is able to withdraw whenever they want
        pub var tokensUnstaked: @FlowToken.Vault

        /// Staking rewards are paid to this bucket
        /// Can be withdrawn whenever
        pub var tokensRewarded: @FlowToken.Vault

        /// list of delegators for this node operator
        pub let delegators: @{UInt32: DelegatorRecord}

        /// The incrementing ID used to register new delegators
        pub(set) var delegatorIDCounter: UInt32

        /// The amount of tokens that this node has requested to unstake for the next epoch
        pub(set) var tokensRequestedToUnstake: UFix64

        /// weight as determined by the amount staked after the staking auction
        pub(set) var initialWeight: UInt64

        init(
            id: String,
            role: UInt8,
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            tokensCommitted: @FungibleToken.Vault
        ) {
            pre {
                id.length == 64: "Node ID length must be 32 bytes (64 hex characters)"
                FlowIDTableStaking.nodes[id] == nil: "The ID cannot already exist in the record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0 && networkingAddress.length <= 510: "The networkingAddress must be less than 255 bytes (510 hex characters)"
                networkingKey.length == 128: "The networkingKey length must be exactly 64 bytes (128 hex characters)"
                stakingKey.length == 192: "The stakingKey length must be exactly 96 bytes (192 hex characters)"
                !FlowIDTableStaking.getNetworkingAddressClaimed(address: networkingAddress): "The networkingAddress cannot have already been claimed"
                !FlowIDTableStaking.getNetworkingKeyClaimed(key: networkingKey): "The networkingKey cannot have already been claimed"
                !FlowIDTableStaking.getStakingKeyClaimed(key: stakingKey): "The stakingKey cannot have already been claimed"
            }

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
            self.initialWeight = 0
            self.delegators <- {}
            self.delegatorIDCounter = 0

            FlowIDTableStaking.updateClaimed(path: /storage/networkingAddressesClaimed, networkingAddress, claimed: true)
            FlowIDTableStaking.updateClaimed(path: /storage/networkingKeysClaimed, networkingKey, claimed: true)
            FlowIDTableStaking.updateClaimed(path: /storage/stakingKeysClaimed, stakingKey, claimed: true)

            self.tokensCommitted <- tokensCommitted as! @FlowToken.Vault
            self.tokensStaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaking <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRewarded <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRequestedToUnstake = 0.0

            emit NewNodeCreated(nodeID: self.id, role: self.role, amountCommitted: self.tokensCommitted.balance)
        }

        destroy() {
            let flowTokenRef = FlowIDTableStaking.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
            FlowIDTableStaking.totalTokensStakedByNodeType[self.role] = FlowIDTableStaking.totalTokensStakedByNodeType[self.role]! - self.tokensStaked.balance
            flowTokenRef.deposit(from: <-self.tokensStaked)
            flowTokenRef.deposit(from: <-self.tokensCommitted)
            flowTokenRef.deposit(from: <-self.tokensUnstaking)
            flowTokenRef.deposit(from: <-self.tokensUnstaked)
            flowTokenRef.deposit(from: <-self.tokensRewarded)

            // Return all of the delegators' funds
            for delegator in self.delegators.keys {
                let delRecord = self.borrowDelegatorRecord(delegator)
                flowTokenRef.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                flowTokenRef.deposit(from: <-delRecord.tokensStaked.withdraw(amount: delRecord.tokensStaked.balance))
                flowTokenRef.deposit(from: <-delRecord.tokensUnstaked.withdraw(amount: delRecord.tokensUnstaked.balance))
                flowTokenRef.deposit(from: <-delRecord.tokensRewarded.withdraw(amount: delRecord.tokensRewarded.balance))
                flowTokenRef.deposit(from: <-delRecord.tokensUnstaking.withdraw(amount: delRecord.tokensUnstaking.balance))
            }

            destroy self.delegators
        }

        /// Utility Function that checks a node's overall committed balance from its borrowed record
        access(contract) fun nodeFullCommittedBalance(): UFix64 {
            if (self.tokensCommitted.balance + self.tokensStaked.balance) < self.tokensRequestedToUnstake {
                return 0.0
            } else {
                return self.tokensCommitted.balance + self.tokensStaked.balance - self.tokensRequestedToUnstake
            }
        }

        /// borrow a reference to to one of the delegators for a node in the record
        access(contract) fun borrowDelegatorRecord(_ delegatorID: UInt32): &DelegatorRecord {
            pre {
                self.delegators[delegatorID] != nil:
                    "Specified delegator ID does not exist in the record"
            }
            return &self.delegators[delegatorID] as! &DelegatorRecord
        }
    }

    // Read-only info about a node
    pub struct NodeInfo {
        pub let id: String
        pub let role: UInt8
        pub let networkingAddress: String
        pub let networkingKey: String
        pub let stakingKey: String
        pub let tokensStaked: UFix64
        pub let tokensCommitted: UFix64
        pub let tokensUnstaking: UFix64
        pub let tokensUnstaked: UFix64
        pub let tokensRewarded: UFix64

        /// list of delegator IDs for this node operator
        pub let delegators: [UInt32]
        pub let delegatorIDCounter: UInt32
        pub let tokensRequestedToUnstake: UFix64
        pub let initialWeight: UInt64

        init(nodeID: String) {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            self.id = nodeRecord.id
            self.role = nodeRecord.role
            self.networkingAddress = nodeRecord.networkingAddress
            self.networkingKey = nodeRecord.networkingKey
            self.stakingKey = nodeRecord.stakingKey
            self.tokensStaked = nodeRecord.tokensStaked.balance
            self.tokensCommitted = nodeRecord.tokensCommitted.balance
            self.tokensUnstaking = nodeRecord.tokensUnstaking.balance
            self.tokensUnstaked = nodeRecord.tokensUnstaked.balance
            self.tokensRewarded = nodeRecord.tokensRewarded.balance
            self.delegators = nodeRecord.delegators.keys
            self.delegatorIDCounter = nodeRecord.delegatorIDCounter
            self.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake
            self.initialWeight = nodeRecord.initialWeight
        }

        /// Derived Fields
        pub fun totalCommittedWithDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            var committedSum = self.totalCommittedWithoutDelegators()
            for delegator in self.delegators {
                let delRecord = nodeRecord.borrowDelegatorRecord(delegator)
                committedSum = committedSum + delRecord.delegatorFullCommittedBalance()
            }
            return committedSum
        }

        pub fun totalCommittedWithoutDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            return nodeRecord.nodeFullCommittedBalance()
        }

        pub fun totalStakedWithDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            var stakedSum = self.tokensStaked
            for delegator in self.delegators {
                let delRecord = nodeRecord.borrowDelegatorRecord(delegator)
                stakedSum = stakedSum + delRecord.tokensStaked.balance
            }
            return stakedSum
        }

        pub fun totalTokensInRecord(): UFix64 {
            return self.tokensStaked + self.tokensCommitted + self.tokensUnstaking + self.tokensUnstaked + self.tokensRewarded
        }
    }

    pub resource DelegatorRecord {
        pub var tokensCommitted: @FlowToken.Vault
        pub var tokensStaked: @FlowToken.Vault
        pub var tokensUnstaking: @FlowToken.Vault
        pub let tokensRewarded: @FlowToken.Vault
        pub let tokensUnstaked: @FlowToken.Vault
        pub(set) var tokensRequestedToUnstake: UFix64

        init() {
            self.tokensCommitted <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensStaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaking <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRewarded <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRequestedToUnstake = 0.0
        }

        destroy () {
            destroy self.tokensCommitted
            destroy self.tokensStaked
            destroy self.tokensUnstaking
            destroy self.tokensRewarded
            destroy self.tokensUnstaked
        }

        /// Utility Function that checks a delegator's overall committed balance from its borrowed record
        access(contract) fun delegatorFullCommittedBalance(): UFix64 {
            if (self.tokensCommitted.balance + self.tokensStaked.balance) < self.tokensRequestedToUnstake {
                return 0.0
            } else {
                return self.tokensCommitted.balance + self.tokensStaked.balance - self.tokensRequestedToUnstake
            }
        }
    }

    /// Read-only info about a delegator
    pub struct DelegatorInfo {
        pub let id: UInt32
        pub let nodeID: String
        pub let tokensCommitted: UFix64
        pub let tokensStaked: UFix64
        pub let tokensUnstaking: UFix64
        pub let tokensRewarded: UFix64
        pub let tokensUnstaked: UFix64
        pub let tokensRequestedToUnstake: UFix64

        init(nodeID: String, delegatorID: UInt32) {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            let delegatorRecord = nodeRecord.borrowDelegatorRecord(delegatorID)

            self.id = delegatorID
            self.nodeID = nodeID
            self.tokensCommitted = delegatorRecord.tokensCommitted.balance
            self.tokensStaked = delegatorRecord.tokensStaked.balance
            self.tokensUnstaking = delegatorRecord.tokensUnstaking.balance
            self.tokensUnstaked = delegatorRecord.tokensUnstaked.balance
            self.tokensRewarded = delegatorRecord.tokensRewarded.balance
            self.tokensRequestedToUnstake = delegatorRecord.tokensRequestedToUnstake
        }

        pub fun totalTokensInRecord(): UFix64 {
            return self.tokensStaked + self.tokensCommitted + self.tokensUnstaking + self.tokensUnstaked + self.tokensRewarded
        }
    }

    pub resource interface NodeStakerPublic {
        pub let id: String
    }

    /// Resource that the node operator controls for staking
    pub resource NodeStaker: NodeStakerPublic {

        pub let id: String

        init(id: String) {
            self.id = id
        }

        /// Add new tokens to the system to stake during the next epoch
        pub fun stakeNewTokens(_ tokens: @FungibleToken.Vault) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit TokensCommitted(nodeID: nodeRecord.id, amount: tokens.balance)

            nodeRecord.tokensCommitted.deposit(from: <-tokens)
        }

        /// Stake tokens that are in the tokensUnstaked bucket
        pub fun stakeUnstakedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            var remainingAmount = amount

            if remainingAmount <= nodeRecord.tokensRequestedToUnstake {
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake - remainingAmount
                remainingAmount = 0.0
            } else if remainingAmount > nodeRecord.tokensRequestedToUnstake {
                remainingAmount = remainingAmount - nodeRecord.tokensRequestedToUnstake
                nodeRecord.tokensRequestedToUnstake = 0.0
            }

            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensUnstaked.withdraw(amount: remainingAmount))

            emit TokensCommitted(nodeID: nodeRecord.id, amount: remainingAmount)
        }

        /// Stake tokens that are in the tokensRewarded bucket
        pub fun stakeRewardedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensRewarded.withdraw(amount: amount))

            emit TokensCommitted(nodeID: nodeRecord.id, amount: amount)
        }

        /// Request amount tokens to be removed from staking at the end of the next epoch
        pub fun requestUnstaking(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot unstake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            assert (
                nodeRecord.tokensStaked.balance +
                nodeRecord.tokensCommitted.balance
                >= amount + nodeRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            assert (
                nodeRecord.delegators.length == 0 ||
                FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: FlowIDTableStaking.NodeInfo(nodeID: nodeRecord.id).totalCommittedWithoutDelegators() - amount, role: nodeRecord.role),
                message: "Cannot unstake below the minimum if there are delegators"
            )

            let amountCommitted = nodeRecord.tokensCommitted.balance

            /// If the request can come from committed, withdraw from committed to unstaked
            if amountCommitted >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amount))

            } else {
                let amountCommitted = nodeRecord.tokensCommitted.balance

                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amountCommitted))

                /// update request to show that leftover amount is requested to be unstaked
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake + (amount - amountCommitted)
            }
        }

        /// Requests to unstake all of the node operators staked and committed tokens,
        pub fun unstakeAll() {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot unstake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            /// if the request can come from committed, withdraw from committed to unstaked
            /// withdraw the requested tokens from committed since they have not been staked yet
            nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

            /// update request to show that leftover amount is requested to be unstaked
            nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance
        }

        pub fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit UnstakedTokensWithdrawn(nodeID: nodeRecord.id, amount: amount)

            return <- nodeRecord.tokensUnstaked.withdraw(amount: amount)
        }

        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit RewardTokensWithdrawn(nodeID: nodeRecord.id, amount: amount)

            return <- nodeRecord.tokensRewarded.withdraw(amount: amount)
        }
    }

    pub resource interface NodeDelegatorPublic {
        pub let id: UInt32
        pub let nodeID: String
    }

    pub resource NodeDelegator: NodeDelegatorPublic {

        /// Each delegator for a node operator has a unique ID
        pub let id: UInt32

        pub let nodeID: String

        init(id: UInt32, nodeID: String) {
            self.id = id
            self.nodeID = nodeID
        }

        /// Delegate new tokens to the node operator
        pub fun delegateNewTokens(from: @FungibleToken.Vault) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: from.balance)

            delRecord.tokensCommitted.deposit(from: <-from)
        }

        /// Delegate tokens from the unstaked bucket to the node operator
        pub fun delegateUnstakedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            var remainingAmount = amount

            if remainingAmount <= delRecord.tokensRequestedToUnstake {
                delRecord.tokensRequestedToUnstake = delRecord.tokensRequestedToUnstake - remainingAmount
                remainingAmount = 0.0
            } else if remainingAmount > delRecord.tokensRequestedToUnstake {
                remainingAmount = remainingAmount - delRecord.tokensRequestedToUnstake
                delRecord.tokensRequestedToUnstake = 0.0
            }

            /// Add the removed tokens to tokens committed
            delRecord.tokensCommitted.deposit(from: <-delRecord.tokensUnstaked.withdraw(amount: remainingAmount))

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: amount)
        }

        /// Delegate tokens from the rewards bucket to the node operator
        pub fun delegateRewardedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            delRecord.tokensCommitted.deposit(from: <-delRecord.tokensRewarded.withdraw(amount: amount))

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: amount)
        }

        /// Request to unstake delegated tokens during the next epoch
        pub fun requestUnstaking(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot request unstaking if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            assert (
                delRecord.tokensStaked.balance +
                delRecord.tokensCommitted.balance
                >= amount + delRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            /// if the request can come from committed, withdraw from committed to unstaked
            if delRecord.tokensCommitted.balance >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: amount))

            } else {
                let amountCommitted = delRecord.tokensCommitted.balance

                if amountCommitted > 0.0 {
                    delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: amountCommitted))
                }

                /// update request to show that leftover amount is requested to be unstaked
                delRecord.tokensRequestedToUnstake = delRecord.tokensRequestedToUnstake + (amount - amountCommitted)
            }
        }

        pub fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorUnstakedTokensWithdrawn(nodeID: nodeRecord.id, delegatorID: self.id, amount: amount)

            return <- delRecord.tokensUnstaked.withdraw(amount: amount)
        }

        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorRewardTokensWithdrawn(nodeID: nodeRecord.id, delegatorID: self.id, amount: amount)

            return <- delRecord.tokensRewarded.withdraw(amount: amount)
        }
    }

    pub resource Admin {

        /// Remove a node from the record
        pub fun removeNode(_ nodeID: String): @NodeRecord {
            let node <- FlowIDTableStaking.nodes.remove(key: nodeID)
                ?? panic("Could not find a node with the specified ID")

            FlowIDTableStaking.updateClaimed(path: /storage/networkingAddressesClaimed, node.networkingAddress, claimed: false)
            FlowIDTableStaking.updateClaimed(path: /storage/networkingKeysClaimed, node.networkingKey, claimed: false)
            FlowIDTableStaking.updateClaimed(path: /storage/stakingKeysClaimed, node.stakingKey, claimed: false)

            return <-node
        }

        pub fun startStakingAuction() {
            FlowIDTableStaking.account.load<Bool>(from: /storage/stakingEnabled)
            FlowIDTableStaking.account.save(true, to: /storage/stakingEnabled)
        }

        /// Ends the staking Auction by removing any unapproved nodes
        /// and setting stakingEnabled to false
        pub fun endStakingAuction(approvedNodeIDs: {String: Bool}) {
            self.removeUnapprovedNodes(approvedNodeIDs: approvedNodeIDs)

            FlowIDTableStaking.account.load<Bool>(from: /storage/stakingEnabled)
            FlowIDTableStaking.account.save(false, to: /storage/stakingEnabled)
        }

        /// Iterates through all the registered nodes and if it finds
        /// a node that has insufficient tokens committed for the next epoch or isn't in the approved list
        /// it moves their committed tokens to their unstaked bucket
        pub fun removeUnapprovedNodes(approvedNodeIDs: {String: Bool}) {
            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            for nodeID in allNodeIDs {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                let totalTokensCommitted = nodeRecord.nodeFullCommittedBalance()

                // if they do not meet the minimum staking requirements
                if !FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: totalTokensCommitted, role: nodeRecord.role) ||
                   (approvedNodeIDs[nodeID] == nil) {

                    emit NodeRemovedAndRefunded(nodeID: nodeRecord.id, amount: nodeRecord.tokensCommitted.balance + nodeRecord.tokensStaked.balance)

                    // move their committed tokens back to their unstaked tokens
                    nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

                    // Set their request to unstake equal to all their staked tokens
                    // since they are forced to unstake
                    nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance

                    // Iterate through all delegators and unstake their tokens
                    for delegator in nodeRecord.delegators.keys {
                        let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                        if delRecord.tokensCommitted.balance > 0.0 {
                            emit DelegatorTokensUnstaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensCommitted.balance)

                            /// move their committed tokens back to their unstaked tokens
                            delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                        }

                        delRecord.tokensRequestedToUnstake = delRecord.tokensStaked.balance
                    }

                    nodeRecord.initialWeight = 0

                } else {
                    /// TODO: Actual initial weight calculation will come at a later date
                    nodeRecord.initialWeight = 100
                }
            }
        }

        pub fun payRewards() {

            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            var totalStaked = FlowIDTableStaking.getTotalStaked()

            if totalStaked == 0.0 {
                return
            }
            var totalRewardScale = FlowIDTableStaking.epochTokenPayout / totalStaked

            /// iterate through all the nodes
            for nodeID in allNodeIDs {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                if nodeRecord.tokensStaked.balance == 0.0 || nodeRecord.role == UInt8(5) { continue }

                let rewardAmount = nodeRecord.tokensStaked.balance * totalRewardScale

                if rewardAmount == 0.0 { continue }

                /// Mint the tokens to reward the operator
                let tokenReward <- flowTokenMinter.mintTokens(amount: rewardAmount)

                // Iterate through all delegators and reward them their share
                // of the rewards for the tokens they have staked for this node
                for delegator in nodeRecord.delegators.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                    if delRecord.tokensStaked.balance == 0.0 { continue }

                    /// Calculate the amount of tokens that this delegator receives
                    let delegatorRewardAmount = delRecord.tokensStaked.balance * totalRewardScale

                    if delegatorRewardAmount == 0.0 { continue }

                    let delegatorReward <- flowTokenMinter.mintTokens(amount: delegatorRewardAmount)

                    // take the node operator's cut
                    if (delegatorReward.balance * FlowIDTableStaking.nodeDelegatingRewardCut) > 0.0 {

                        tokenReward.deposit(from: <-delegatorReward.withdraw(amount: delegatorReward.balance * FlowIDTableStaking.nodeDelegatingRewardCut))
                    }

                    if delegatorReward.balance > 0.0 {
                        emit DelegatorRewardsPaid(nodeID: nodeRecord.id, delegatorID: delegator, amount: delegatorReward.balance)

                        delRecord.tokensRewarded.deposit(from: <-delegatorReward)
                    } else {
                        destroy delegatorReward
                    }
                }

                if tokenReward.balance > 0.0 {
                    emit RewardsPaid(nodeID: nodeRecord.id, amount: tokenReward.balance)

                    /// Deposit the node Rewards into their tokensRewarded bucket
                    nodeRecord.tokensRewarded.deposit(from: <-tokenReward)
                } else {
                    destroy tokenReward
                }
            }
        }

        /// Called at the end of the epoch to move tokens between buckets for stakers
        pub fun moveTokens() {
            pre {
                !FlowIDTableStaking.stakingEnabled(): "Cannot move tokens if the staking auction is still in progress"
            }
            
            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            for nodeID in allNodeIDs {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                // Update total number of tokens staked by all the nodes of each type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + nodeRecord.tokensCommitted.balance

                if nodeRecord.tokensCommitted.balance > 0.0 {
                    emit TokensStaked(nodeID: nodeRecord.id, amount: nodeRecord.tokensCommitted.balance)
                    nodeRecord.tokensStaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))
                }
                if nodeRecord.tokensUnstaking.balance > 0.0 {
                    emit TokensUnstaked(nodeID: nodeRecord.id, amount: nodeRecord.tokensUnstaking.balance)
                    nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensUnstaking.withdraw(amount: nodeRecord.tokensUnstaking.balance))
                }
                if nodeRecord.tokensRequestedToUnstake > 0.0 {
                    emit TokensUnstaking(nodeID: nodeRecord.id, amount: nodeRecord.tokensRequestedToUnstake)
                    nodeRecord.tokensUnstaking.deposit(from: <-nodeRecord.tokensStaked.withdraw(amount: nodeRecord.tokensRequestedToUnstake))
                }

                // move all the delegators' tokens between buckets
                for delegator in nodeRecord.delegators.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                    FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + delRecord.tokensCommitted.balance

                    // mark their committed tokens as staked
                    if delRecord.tokensCommitted.balance > 0.0 {
                        emit DelegatorTokensStaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensCommitted.balance)
                        delRecord.tokensStaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                    }

                    if delRecord.tokensUnstaking.balance > 0.0 {
                        emit DelegatorTokensUnstaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensUnstaking.balance)
                        delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensUnstaking.withdraw(amount: delRecord.tokensUnstaking.balance))
                    }

                    if delRecord.tokensRequestedToUnstake > 0.0 {
                        emit DelegatorTokensUnstaking(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensRequestedToUnstake)
                        delRecord.tokensUnstaking.deposit(from: <-delRecord.tokensStaked.withdraw(amount: delRecord.tokensRequestedToUnstake))
                    }

                    // subtract their requested tokens from the total staked for their node type
                    FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! - delRecord.tokensRequestedToUnstake

                    delRecord.tokensRequestedToUnstake = 0.0
                }

                // subtract their requested tokens from the total staked for their node type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! - nodeRecord.tokensRequestedToUnstake

                // Reset the tokens requested field so it can be used for the next epoch
                nodeRecord.tokensRequestedToUnstake = 0.0
            }

            self.startStakingAuction()

            emit NewEpoch(totalStaked: FlowIDTableStaking.getTotalStaked(), totalRewardPayout: FlowIDTableStaking.epochTokenPayout)
        }

        pub fun setMinimumStakeRequirements(_ newRequirements: {UInt8: UFix64}) {
            pre {
                newRequirements.keys.length == 5: "Incorrect number of nodes"
            }
            FlowIDTableStaking.minimumStakeRequired = newRequirements

            emit NewStakingMinimums(newMinimums: newRequirements)
        }

        // Changes the total weekly payout to a new value
        pub fun setEpochTokenPayout(_ newPayout: UFix64) {
            FlowIDTableStaking.epochTokenPayout = newPayout

            emit NewWeeklyPayout(newPayout: newPayout)
        }

        pub fun setCutPercentage(_ newCutPercentage: UFix64) {
            pre {
                newCutPercentage > 0.0 && newCutPercentage < 1.0:
                    "Cut percentage must be between 0 and 1!"
            }

            FlowIDTableStaking.nodeDelegatingRewardCut = newCutPercentage

            emit NewDelegatorCutPercentage(newCutPercentage: FlowIDTableStaking.nodeDelegatingRewardCut)
        }

        pub fun setClaimed() {

            let claimedNetAddressDictionary: {String: Bool} = {}
            let claimedNetKeyDictionary: {String: Bool} = {}
            let claimedStakingKeysDictionary: {String: Bool} = {}

            for nodeID in FlowIDTableStaking.nodes.keys {
                claimedNetAddressDictionary[FlowIDTableStaking.nodes[nodeID]?.networkingAddress!] = true
                claimedNetKeyDictionary[FlowIDTableStaking.nodes[nodeID]?.networkingKey!] = true
                claimedStakingKeysDictionary[FlowIDTableStaking.nodes[nodeID]?.stakingKey!] = true
            }

            FlowIDTableStaking.account.save(claimedNetAddressDictionary, to: /storage/networkingAddressesClaimed)
            FlowIDTableStaking.account.save(claimedNetKeyDictionary, to: /storage/networkingKeysClaimed)
            FlowIDTableStaking.account.save(claimedStakingKeysDictionary, to: /storage/stakingKeysClaimed)
        }
    }

    /// Any node can call this function to register a new Node
    /// It returns the resource for nodes that they can store in their account storage
    pub fun addNodeRecord(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, tokensCommitted: @FungibleToken.Vault): @NodeStaker {
        pre {
            FlowIDTableStaking.stakingEnabled(): "Cannot register a node operator if the staking auction isn't in progress"
        }
        
        let initialBalance = tokensCommitted.balance

        let newNode <- create NodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <-tokensCommitted)

        // Insert the node to the table
        FlowIDTableStaking.nodes[id] <-! newNode

        return <-create NodeStaker(id: id)
    }

    /// Registers a new delegator with a unique ID for the specified node operator
    /// and returns a delegator object to the caller
    pub fun registerNewDelegator(nodeID: String): @NodeDelegator {
        pre {
            FlowIDTableStaking.stakingEnabled(): "Cannot register a node operator if the staking auction isn't in progress"
        }

        let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

        assert (
            nodeRecord.role != UInt8(5),
            message: "Cannot register a delegator for an access node"
        )

        assert (
            FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: nodeRecord.nodeFullCommittedBalance(), role: nodeRecord.role),
            message: "Cannot register a delegator if the node operator is below the minimum stake"
        )

        nodeRecord.delegatorIDCounter = nodeRecord.delegatorIDCounter + UInt32(1)

        nodeRecord.delegators[nodeRecord.delegatorIDCounter] <-! create DelegatorRecord()

        emit NewDelegatorCreated(nodeID: nodeRecord.id, delegatorID: nodeRecord.delegatorIDCounter)

        return <-create NodeDelegator(id: nodeRecord.delegatorIDCounter, nodeID: nodeRecord.id)
    }

    /// borrow a reference to to one of the nodes in the record
    access(account) fun borrowNodeRecord(_ nodeID: String): &NodeRecord {
        pre {
            FlowIDTableStaking.nodes[nodeID] != nil:
                "Specified node ID does not exist in the record"
        }
        return &FlowIDTableStaking.nodes[nodeID] as! &NodeRecord
    }

    access(account) fun updateClaimed(path: StoragePath, _ key: String, claimed: Bool) {
        let claimedDictionary = self.account.load<{String: Bool}>(from: path)
            ?? panic("Invalid path for dictionary")

        if claimed {
            claimedDictionary[key] = true
        } else {
            claimedDictionary[key] = nil
        }

        self.account.save(claimedDictionary, to: path)
    }

    pub fun stakingEnabled(): Bool {
        return self.account.copy<Bool>(from: /storage/stakingEnabled) ?? false
    }

    /// Gets an array of the node IDs that are proposed for the next epoch
    /// Nodes that are proposed are nodes that have enough tokens staked + committed
    /// for the next epoch
    pub fun getProposedNodeIDs(): [String] {
        var proposedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            // To be considered proposed, a node has to have tokens staked + committed equal or above the minimum
            // Access nodes have a minimum of 0, so they need to be strictly greater than zero to be considered proposed
            if self.isGreaterThanMinimumForRole(numTokens: self.NodeInfo(nodeID: nodeRecord.id).totalCommittedWithoutDelegators(), role: nodeRecord.role)
            {
                proposedNodes.append(nodeID)
            }
        }

        return proposedNodes
    }

    pub fun getStakedNodeIDs(): [String] {
        var stakedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            // To be considered staked, a node has to have tokens staked equal or above the minimum
            // Access nodes have a minimum of 0, so they need to be strictly greater than zero to be considered staked
            if self.isGreaterThanMinimumForRole(numTokens: nodeRecord.tokensStaked.balance, role: nodeRecord.role)
            {
                stakedNodes.append(nodeID)
            }
        }

        return stakedNodes
    }

    pub fun getNodeIDs(): [String] {
        return FlowIDTableStaking.nodes.keys
    }

    pub fun isGreaterThanMinimumForRole(numTokens: UFix64, role: UInt8): Bool {
        if role == UInt8(5) {
            return numTokens > 0.0
        } else {
            return numTokens >= self.minimumStakeRequired[role]!
        }
    }

    pub fun getNetworkingAddressClaimed(address: String): Bool {
        return self.getClaimed(path: /storage/networkingAddressesClaimed, key: address)
    }

    pub fun getNetworkingKeyClaimed(key: String): Bool {
        return self.getClaimed(path: /storage/networkingKeysClaimed, key: key)
    }

    pub fun getStakingKeyClaimed(key: String): Bool {
        return self.getClaimed(path: /storage/stakingKeysClaimed, key: key)
    }

    access(account) fun getClaimed(path: StoragePath, key: String): Bool {
		let claimedDictionary = self.account.borrow<&{String: Bool}>(from: path)
            ?? panic("Invalid path for dictionary")
        return claimedDictionary[key] ?? false
    }

    pub fun getMinimumStakeRequirements(): {UInt8: UFix64} {
        return self.minimumStakeRequired
    }

    pub fun getTotalTokensStakedByNodeType(): {UInt8: UFix64} {
        return self.totalTokensStakedByNodeType
    }

    pub fun getTotalStaked(): UFix64 {
        var totalStaked: UFix64 = 0.0
        for nodeType in FlowIDTableStaking.totalTokensStakedByNodeType.keys {
            // Do not count access nodes
            if nodeType != UInt8(5) {
                totalStaked = totalStaked + FlowIDTableStaking.totalTokensStakedByNodeType[nodeType]!
            }
        }
        return totalStaked
    }

    pub fun getEpochTokenPayout(): UFix64 {
        return self.epochTokenPayout
    }

    pub fun getRewardCutPercentage(): UFix64 {
        return self.nodeDelegatingRewardCut
    }

    pub fun getRewardRatios(): {UInt8: UFix64} {
        return self.rewardRatios
    }

    init(_ epochTokenPayout: UFix64, _ rewardCut: UFix64) {
        self.account.save(true, to: /storage/stakingEnabled)

        self.nodes <- {}

        let stakingKeyClaimed: {String: Bool} = {}
        self.account.save(stakingKeyClaimed, to: /storage/stakingKeysClaimed)
        let networkingKeyClaimed: {String: Bool} = {}
        self.account.save(networkingKeyClaimed, to: /storage/networkingKeysClaimed)
        let networkingAddressClaimed: {String: Bool} = {}
        self.account.save(networkingAddressClaimed, to: /storage/networkingAddressesClaimed)

        self.NodeStakerStoragePath = /storage/flowStaker
        self.NodeStakerPublicPath = /public/flowStaker
        self.StakingAdminStoragePath = /storage/flowStakingAdmin
        self.DelegatorStoragePath = /storage/flowStakingDelegator

        self.minimumStakeRequired = {UInt8(1): 250000.0, UInt8(2): 500000.0, UInt8(3): 1250000.0, UInt8(4): 135000.0, UInt8(5): 0.0}

        self.totalTokensStakedByNodeType = {UInt8(1): 0.0, UInt8(2): 0.0, UInt8(3): 0.0, UInt8(4): 0.0, UInt8(5): 0.0}

        self.epochTokenPayout = epochTokenPayout

        self.nodeDelegatingRewardCut = rewardCut

        self.rewardRatios = {UInt8(1): 0.168, UInt8(2): 0.518, UInt8(3): 0.078, UInt8(4): 0.236, UInt8(5): 0.0}

        self.account.save(<-create Admin(), to: self.StakingAdminStoragePath)
    }
}
 