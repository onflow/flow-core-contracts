/*

    FlowIDTableStaking

    The Flow ID Table and Staking contract manages
    node operators' and delegators' information
    and Flow tokens that are staked as part of the Flow Protocol.

    Nodes submit their stake to the public addNodeInfo function
    during the staking auction phase.

    This records their info and committed tokens. They also will get a Node
    Object that they can use to stake, unstake, and withdraw rewards.

    Each node has multiple token buckets that hold their tokens
    based on their status: committed, staked, unstaking, unstaked, and rewarded.

    Delegators can also register to delegate FLOW to a node operator
    during the staking auction phase by using the registerNewDelegator() function.
    They have the same token buckets that node operators do.

    The Admin has the authority to remove node records,
    refund insufficiently staked nodes, pay rewards,
    and move tokens between buckets. These will happen once every epoch.

    See additional staking documentation here: https://docs.onflow.org/staking/

 */

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowFees from 0xFLOWFEESADDRESS
import Crypto

access(all) contract FlowIDTableStaking {

    /****** ID Table and Staking Events ******/

    access(all) event NewEpoch(totalStaked: UFix64, totalRewardPayout: UFix64)
    access(all) event EpochTotalRewardsPaid(total: UFix64, fromFees: UFix64, minted: UFix64, feesBurned: UFix64)

    /// Node Events
    access(all) event NewNodeCreated(nodeID: String, role: UInt8, amountCommitted: UFix64)
    access(all) event TokensCommitted(nodeID: String, amount: UFix64)
    access(all) event TokensStaked(nodeID: String, amount: UFix64)
    access(all) event NodeTokensRequestedToUnstake(nodeID: String, amount: UFix64)
    access(all) event TokensUnstaking(nodeID: String, amount: UFix64)
    access(all) event TokensUnstaked(nodeID: String, amount: UFix64)
    access(all) event NodeRemovedAndRefunded(nodeID: String, amount: UFix64)
    access(all) event RewardsPaid(nodeID: String, amount: UFix64)
    access(all) event UnstakedTokensWithdrawn(nodeID: String, amount: UFix64)
    access(all) event RewardTokensWithdrawn(nodeID: String, amount: UFix64)
    access(all) event NetworkingAddressUpdated(nodeID: String, newAddress: String)
    access(all) event NodeWeightChanged(nodeID: String, newWeight: UInt64)

    /// Delegator Events
    access(all) event NewDelegatorCreated(nodeID: String, delegatorID: UInt32)
    access(all) event DelegatorTokensCommitted(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorTokensStaked(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorTokensRequestedToUnstake(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorTokensUnstaking(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorTokensUnstaked(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorRewardsPaid(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorUnstakedTokensWithdrawn(nodeID: String, delegatorID: UInt32, amount: UFix64)
    access(all) event DelegatorRewardTokensWithdrawn(nodeID: String, delegatorID: UInt32, amount: UFix64)

    /// Contract Field Change Events
    access(all) event NewDelegatorCutPercentage(newCutPercentage: UFix64)
    access(all) event NewWeeklyPayout(newPayout: UFix64)
    access(all) event NewStakingMinimums(newMinimums: {UInt8: UFix64})
    access(all) event NewDelegatorStakingMinimum(newMinimum: UFix64)

    /// Holds the identity table for all the nodes in the network.
    /// Includes nodes that aren't actively participating
    /// key = node ID
    /// value = the record of that node's info, tokens, and delegators
    access(contract) var nodes: @{String: NodeRecord}

    /// The minimum amount of tokens that each staker type has to stake
    /// in order to be considered valid
    /// Keys:
    /// 1 - Collector Nodes
    /// 2 - Consensus Nodes
    /// 3 - Execution Nodes
    /// 4 - Verification Nodes
    /// 5 - Access Nodes
    access(account) var minimumStakeRequired: {UInt8: UFix64}

    /// The total amount of tokens that are staked for all the nodes
    /// of each node type during the current epoch
    access(account) var totalTokensStakedByNodeType: {UInt8: UFix64}

    /// The total amount of tokens that are paid as rewards every epoch
    /// could be manually changed by the admin resource
    access(account) var epochTokenPayout: UFix64

    /// The ratio of the weekly awards that each node type gets
    /// key = node role
    /// value = decimal number between 0 and 1 indicating a percentage
    /// NOTE: Currently is not used
    access(contract) var rewardRatios: {UInt8: UFix64}

    /// The percentage of rewards that every node operator takes from
    /// the users that are delegating to it
    access(account) var nodeDelegatingRewardCut: UFix64

    /// Paths for storing staking resources
    access(all) let NodeStakerStoragePath: StoragePath
    access(all) let NodeStakerPublicPath: PublicPath
    access(all) let StakingAdminStoragePath: StoragePath
    access(all) let DelegatorStoragePath: StoragePath

    /*********** ID Table and Staking Composite Type Definitions *************/

    /// Contains information that is specific to a node in Flow
    access(all) resource NodeRecord {

        /// The unique ID of the node
        /// Set when the node is created
        access(all) let id: String

        /// The type of node:
        /// 1 = collection
        /// 2 = consensus
        /// 3 = execution
        /// 4 = verification
        /// 5 = access
        access(all) var role: UInt8

        access(all) var networkingAddress: String
        access(all) var networkingKey: String
        access(all) var stakingKey: String

        /// TODO: Proof of Possession (PoP) of the staking private key

        /// The total tokens that only this node currently has staked, not including delegators
        /// This value must always be above the minimum requirement to stay staked or accept delegators
        access(all) var tokensStaked: @FlowToken.Vault

        /// The tokens that this node has committed to stake for the next epoch.
        /// Moves to the tokensStaked bucket at the end of an epoch
        access(all) var tokensCommitted: @FlowToken.Vault

        /// The tokens that this node has unstaked from the previous epoch
        /// Moves to the tokensUnstaked bucket at the end of an epoch.
        access(all) var tokensUnstaking: @FlowToken.Vault

        /// Tokens that this node has unstaked and are able to withdraw whenever they want
        access(all) var tokensUnstaked: @FlowToken.Vault

        /// Staking rewards are paid to this bucket
        access(all) var tokensRewarded: @FlowToken.Vault

        /// list of delegators for this node operator
        access(all) let delegators: @{UInt32: DelegatorRecord}

        /// The incrementing ID used to register new delegators
        access(all) var delegatorIDCounter: UInt32

        /// The amount of tokens that this node has requested to unstake for the next epoch
        access(all) var tokensRequestedToUnstake: UFix64

        /// weight as determined by the amount staked after the staking auction
        access(all) var initialWeight: UInt64

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
                FlowIDTableStaking.isValidNodeID(id): "The node ID must have only numbers and lowercase hex characters"
                FlowIDTableStaking.nodes[id] == nil: "The ID cannot already exist in the record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0 && networkingAddress.length <= 510: "The networkingAddress must be less than 510 characters"
                networkingKey.length == 128: "The networkingKey length must be exactly 64 bytes (128 hex characters)"
                stakingKey.length == 192: "The stakingKey length must be exactly 96 bytes (192 hex characters)"
                !FlowIDTableStaking.getNetworkingAddressClaimed(address: networkingAddress): "The networkingAddress cannot have already been claimed"
                !FlowIDTableStaking.getNetworkingKeyClaimed(key: networkingKey): "The networkingKey cannot have already been claimed"
                !FlowIDTableStaking.getStakingKeyClaimed(key: stakingKey): "The stakingKey cannot have already been claimed"
            }

            let stakeKey = PublicKey(
                publicKey: stakingKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.BLS_BLS12_381
            )

            let netKey = PublicKey(
                publicKey: networkingKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            )

            // TODO: Verify the provided Proof of Possession of the staking private key

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
        access(account) fun nodeFullCommittedBalance(): UFix64 {
            if (self.tokensCommitted.balance + self.tokensStaked.balance) < self.tokensRequestedToUnstake {
                return 0.0
            } else {
                return self.tokensCommitted.balance + self.tokensStaked.balance - self.tokensRequestedToUnstake
            }
        }

        /// borrow a reference to to one of the delegators for a node in the record
        access(account) fun borrowDelegatorRecord(_ delegatorID: UInt32): &DelegatorRecord {
            pre {
                self.delegators[delegatorID] != nil:
                    "Specified delegator ID does not exist in the record"
            }
            return (&self.delegators[delegatorID] as &DelegatorRecord?)!
        }

        /// Add a delegator to the node record
        access(account) fun setDelegator(delegatorID: UInt32, delegator: @DelegatorRecord) {
            self.delegators[delegatorID] <-! delegator
        }
    }

    /// Struct to create to get read-only info about a node
    access(all) struct NodeInfo {
        access(all) let id: String
        access(all) let role: UInt8
        access(all) let networkingAddress: String
        access(all) let networkingKey: String
        access(all) let stakingKey: String
        access(all) let tokensStaked: UFix64
        access(all) let tokensCommitted: UFix64
        access(all) let tokensUnstaking: UFix64
        access(all) let tokensUnstaked: UFix64
        access(all) let tokensRewarded: UFix64

        /// list of delegator IDs for this node operator
        access(all) let delegators: [UInt32]
        access(all) let delegatorIDCounter: UInt32
        access(all) let tokensRequestedToUnstake: UFix64
        access(all) let initialWeight: UInt64

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
        access(all) fun totalCommittedWithDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            var committedSum = self.totalCommittedWithoutDelegators()
            for delegator in self.delegators {
                let delRecord = nodeRecord.borrowDelegatorRecord(delegator)
                committedSum = committedSum + delRecord.delegatorFullCommittedBalance()
            }
            return committedSum
        }

        access(all) fun totalCommittedWithoutDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            return nodeRecord.nodeFullCommittedBalance()
        }

        access(all) fun totalStakedWithDelegators(): UFix64 {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)
            var stakedSum = self.tokensStaked
            for delegator in self.delegators {
                let delRecord = nodeRecord.borrowDelegatorRecord(delegator)
                stakedSum = stakedSum + delRecord.tokensStaked.balance
            }
            return stakedSum
        }

        access(all) fun totalTokensInRecord(): UFix64 {
            return self.tokensStaked + self.tokensCommitted + self.tokensUnstaking + self.tokensUnstaked + self.tokensRewarded
        }
    }

    /// Records the staking info associated with a delegator
    /// This resource is stored in the NodeRecord object that is being delegated to
    access(all) resource DelegatorRecord {
        /// Tokens this delegator has committed for the next epoch
        access(all) var tokensCommitted: @FlowToken.Vault

        /// Tokens this delegator has staked for the current epoch
        access(all) var tokensStaked: @FlowToken.Vault

        /// Tokens this delegator has requested to unstake and is locked for the current epoch
        access(all) var tokensUnstaking: @FlowToken.Vault

        /// Tokens this delegator has been rewarded and can withdraw
        access(all) let tokensRewarded: @FlowToken.Vault

        /// Tokens that this delegator unstaked and can withdraw
        access(all) let tokensUnstaked: @FlowToken.Vault

        /// Amount of tokens that the delegator has requested to unstake
        access(all) var tokensRequestedToUnstake: UFix64

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

    /// Struct that can be returned to show all the info about a delegator
    access(all) struct DelegatorInfo {
        access(all) let id: UInt32
        access(all) let nodeID: String
        access(all) let tokensCommitted: UFix64
        access(all) let tokensStaked: UFix64
        access(all) let tokensUnstaking: UFix64
        access(all) let tokensRewarded: UFix64
        access(all) let tokensUnstaked: UFix64
        access(all) let tokensRequestedToUnstake: UFix64

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

        access(all) fun totalTokensInRecord(): UFix64 {
            return self.tokensStaked + self.tokensCommitted + self.tokensUnstaking + self.tokensUnstaked + self.tokensRewarded
        }
    }

    access(all) resource interface NodeStakerPublic {
        access(all) let id: String
    }

    /// Resource that the node operator controls for staking
    access(all) resource NodeStaker: NodeStakerPublic {

        /// Unique ID for the node operator
        access(all) let id: String

        init(id: String) {
            self.id = id
        }

        /// Tells whether the node is currently eligible for CandidateNodeStatus
        /// which means that it is a new node who currently is not participating with tokens staked
        /// and has enough committed for the next epoch for its role
        access(self) fun isEligibleForCandidateNodeStatus(_ nodeRecord: &FlowIDTableStaking.NodeRecord): Bool {
            let participantList = FlowIDTableStaking.getParticipantNodeList()!
            if participantList[nodeRecord.id] == true {
                return false
            }
            return nodeRecord.tokensStaked.balance == 0.0 &&
                FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: nodeRecord.tokensCommitted.balance, role: nodeRecord.role)
        }

        /// Change the node's networking address to a new one
        access(all) fun updateNetworkingAddress(_ newAddress: String) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot update networking address if the staking auction isn't in progress"
                newAddress.length > 0 && newAddress.length <= 510: "The networkingAddress must be less than 510 characters"
                !FlowIDTableStaking.getNetworkingAddressClaimed(address: newAddress): "The networkingAddress cannot have already been claimed"
            }

            // Borrow the node's record from the staking contract
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            FlowIDTableStaking.updateClaimed(path: /storage/networkingAddressesClaimed, nodeRecord.networkingAddress, claimed: false)

            nodeRecord.networkingAddress = newAddress

            FlowIDTableStaking.updateClaimed(path: /storage/networkingAddressesClaimed, newAddress, claimed: true)

            emit NetworkingAddressUpdated(nodeID: self.id, newAddress: newAddress)
        }

        /// Add new tokens to the system to stake during the next epoch
        access(all) fun stakeNewTokens(_ tokens: @FungibleToken.Vault) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            // Borrow the node's record from the staking contract
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit TokensCommitted(nodeID: nodeRecord.id, amount: tokens.balance)

            // Add the new tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-tokens)

            // Only add them as a candidate node if they don't already
            // have tokens staked and are above the minimum
            if self.isEligibleForCandidateNodeStatus(nodeRecord) {
                FlowIDTableStaking.addToCandidateNodeList(nodeID: nodeRecord.id, roleToAdd: nodeRecord.role)
            }

            FlowIDTableStaking.setNewMovesPending(nodeID: self.id, delegatorID: nil)
        }

        /// Stake tokens that are in the tokensUnstaked bucket
        access(all) fun stakeUnstakedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            var remainingAmount = amount

            // If there are any tokens that have been requested to unstake for the current epoch,
            // cancel those first before staking new unstaked tokens
            if remainingAmount <= nodeRecord.tokensRequestedToUnstake {
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake - remainingAmount
                remainingAmount = 0.0
            } else if remainingAmount > nodeRecord.tokensRequestedToUnstake {
                remainingAmount = remainingAmount - nodeRecord.tokensRequestedToUnstake
                nodeRecord.tokensRequestedToUnstake = 0.0
            }

            // Commit the remaining amount from the tokens unstaked bucket
            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensUnstaked.withdraw(amount: remainingAmount))

            emit TokensCommitted(nodeID: nodeRecord.id, amount: remainingAmount)

            // Only add them as a candidate node if they don't already
            // have tokens staked and are above the minimum
            if self.isEligibleForCandidateNodeStatus(nodeRecord) {
                FlowIDTableStaking.addToCandidateNodeList(nodeID: nodeRecord.id, roleToAdd: nodeRecord.role)
            }

            FlowIDTableStaking.setNewMovesPending(nodeID: self.id, delegatorID: nil)
        }

        /// Stake tokens that are in the tokensRewarded bucket
        access(all) fun stakeRewardedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot stake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensRewarded.withdraw(amount: amount))

            emit TokensCommitted(nodeID: nodeRecord.id, amount: amount)

            // Only add them as a candidate node if they don't already
            // have tokens staked and are above the minimum
            if self.isEligibleForCandidateNodeStatus(nodeRecord) {
                FlowIDTableStaking.addToCandidateNodeList(nodeID: nodeRecord.id, roleToAdd: nodeRecord.role)
            }

            FlowIDTableStaking.setNewMovesPending(nodeID: self.id, delegatorID: nil)
        }

        /// Request amount tokens to be removed from staking at the end of the next epoch
        access(all) fun requestUnstaking(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot unstake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            // If the request is greater than the total number of tokens
            // that can be unstaked, revert
            assert (
                nodeRecord.tokensStaked.balance +
                nodeRecord.tokensCommitted.balance
                >= amount + nodeRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            // Node operators who have delegators have to have enough of their own tokens staked
            // to meet the minimum, without any contributions from delegators
            assert (
                nodeRecord.delegators.length == 0 ||
                FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: FlowIDTableStaking.NodeInfo(nodeID: nodeRecord.id).totalCommittedWithoutDelegators() - amount, role: nodeRecord.role),
                message: "Cannot unstake below the minimum if there are delegators"
            )

            // Get the balance of the tokens that are currently committed
            let amountCommitted = nodeRecord.tokensCommitted.balance

            // If the request can come from committed, withdraw from committed to unstaked
            if amountCommitted >= amount {

                // withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amount))

                emit TokensUnstaked(nodeID: self.id, amount: amount)

            } else {
                let amountCommitted = nodeRecord.tokensCommitted.balance

                // withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: amountCommitted))

                // update request to show that leftover amount is requested to be unstaked
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensRequestedToUnstake + (amount - amountCommitted)

                FlowIDTableStaking.setNewMovesPending(nodeID: self.id, delegatorID: nil)

                emit TokensUnstaked(nodeID: self.id, amount: amountCommitted)
                emit NodeTokensRequestedToUnstake(nodeID: self.id, amount: nodeRecord.tokensRequestedToUnstake)
            }

            // Remove the node as a candidate node if they were one before but aren't now
            if !self.isEligibleForCandidateNodeStatus(nodeRecord) {
                FlowIDTableStaking.removeFromCandidateNodeList(nodeID: self.id, role: nodeRecord.role)
            }   
        }

        /// Requests to unstake all of the node operators staked and committed tokens
        /// as well as all the staked and committed tokens of all of their delegators
        access(all) fun unstakeAll() {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot unstake if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            if nodeRecord.tokensCommitted.balance > 0.0 {

                emit TokensUnstaked(nodeID: self.id, amount: nodeRecord.tokensCommitted.balance)

                /// if the request can come from committed, withdraw from committed to unstaked
                /// withdraw the requested tokens from committed since they have not been staked yet
                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))
            }

            if nodeRecord.tokensStaked.balance > 0.0 {

                /// update request to show that leftover amount is requested to be unstaked
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance

                FlowIDTableStaking.setNewMovesPending(nodeID: self.id, delegatorID: nil)

                emit NodeTokensRequestedToUnstake(nodeID: self.id, amount: nodeRecord.tokensRequestedToUnstake)
            }

            FlowIDTableStaking.removeFromCandidateNodeList(nodeID: self.id, role: nodeRecord.role)
        }

        /// Withdraw tokens from the unstaked bucket
        access(all) fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit UnstakedTokensWithdrawn(nodeID: nodeRecord.id, amount: amount)

            return <- nodeRecord.tokensUnstaked.withdraw(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        access(all) fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.id)

            emit RewardTokensWithdrawn(nodeID: nodeRecord.id, amount: amount)

            return <- nodeRecord.tokensRewarded.withdraw(amount: amount)
        }
    }

    /// Public interface to query information about a delegator
    /// from the account it is stored in 
    access(all) resource interface NodeDelegatorPublic {
        access(all) let id: UInt32
        access(all) let nodeID: String
    }

    /// Resource object that the delegator stores in their account to perform staking actions
    access(all) resource NodeDelegator: NodeDelegatorPublic {

        access(all) let id: UInt32
        access(all) let nodeID: String

        init(id: UInt32, nodeID: String) {
            self.id = id
            self.nodeID = nodeID
        }

        /// Delegate new tokens to the node operator
        access(all) fun delegateNewTokens(from: @FungibleToken.Vault) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            // borrow the node record of the node in order to get the delegator record
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: from.balance)

            // Commit the new tokens to the delegator record
            delRecord.tokensCommitted.deposit(from: <-from)

            FlowIDTableStaking.setNewMovesPending(nodeID: self.nodeID, delegatorID: self.id)
        }

        /// Delegate tokens from the unstaked bucket to the node operator
        access(all) fun delegateUnstakedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            var remainingAmount = amount

            // If there are any tokens that have been requested to unstake for the current epoch,
            // cancel those first before staking new unstaked tokens
            if remainingAmount <= delRecord.tokensRequestedToUnstake {
                delRecord.tokensRequestedToUnstake = delRecord.tokensRequestedToUnstake - remainingAmount
                remainingAmount = 0.0
            } else if remainingAmount > delRecord.tokensRequestedToUnstake {
                remainingAmount = remainingAmount - delRecord.tokensRequestedToUnstake
                delRecord.tokensRequestedToUnstake = 0.0
            }

            // Commit the remaining unstaked tokens
            delRecord.tokensCommitted.deposit(from: <-delRecord.tokensUnstaked.withdraw(amount: remainingAmount))

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: amount)

            FlowIDTableStaking.setNewMovesPending(nodeID: self.nodeID, delegatorID: self.id)
        }

        /// Delegate tokens from the rewards bucket to the node operator
        access(all) fun delegateRewardedTokens(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot delegate if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            delRecord.tokensCommitted.deposit(from: <-delRecord.tokensRewarded.withdraw(amount: amount))

            emit DelegatorTokensCommitted(nodeID: self.nodeID, delegatorID: self.id, amount: amount)

            FlowIDTableStaking.setNewMovesPending(nodeID: self.nodeID, delegatorID: self.id)
        }

        /// Request to unstake delegated tokens during the next epoch
        access(all) fun requestUnstaking(amount: UFix64) {
            pre {
                FlowIDTableStaking.stakingEnabled(): "Cannot request unstaking if the staking auction isn't in progress"
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            // The delegator must have enough tokens to unstake
            assert (
                delRecord.tokensStaked.balance +
                delRecord.tokensCommitted.balance
                >= amount + delRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            // if the request can come from committed, withdraw from committed to unstaked
            if delRecord.tokensCommitted.balance >= amount {

                // withdraw the requested tokens from committed since they have not been staked yet
                delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: amount))
                emit DelegatorTokensUnstaked(nodeID: self.nodeID, delegatorID: self.id, amount: amount)

            } else {
                /// Get the balance of the tokens that are currently committed
                let amountCommitted = delRecord.tokensCommitted.balance

                if amountCommitted > 0.0 {
                    delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: amountCommitted))
                }

                /// update request to show that leftover amount is requested to be unstaked
                delRecord.tokensRequestedToUnstake = delRecord.tokensRequestedToUnstake + (amount - amountCommitted)

                FlowIDTableStaking.setNewMovesPending(nodeID: self.nodeID, delegatorID: self.id)

                emit DelegatorTokensUnstaked(nodeID: self.nodeID, delegatorID: self.id, amount: amountCommitted)
                emit DelegatorTokensRequestedToUnstake(nodeID: self.nodeID, delegatorID: self.id, amount: delRecord.tokensRequestedToUnstake)
            }
        }

        /// Withdraw tokens from the unstaked bucket
        access(all) fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorUnstakedTokensWithdrawn(nodeID: nodeRecord.id, delegatorID: self.id, amount: amount)

            return <- delRecord.tokensUnstaked.withdraw(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        access(all) fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(self.nodeID)
            let delRecord = nodeRecord.borrowDelegatorRecord(self.id)

            emit DelegatorRewardTokensWithdrawn(nodeID: nodeRecord.id, delegatorID: self.id, amount: amount)

            return <- delRecord.tokensRewarded.withdraw(amount: amount)
        }
    }

    /// Includes all the rewards breakdowns for all the nodes and delegators for a specific epoch
    /// as well as the total amount of tokens to be minted for rewards
    access(all) struct EpochRewardsSummary {
        access(all) let totalRewards: UFix64
        access(all) let breakdown: [RewardsBreakdown]

        init(totalRewards: UFix64, breakdown: [RewardsBreakdown]) {
            self.totalRewards = totalRewards
            self.breakdown = breakdown
        }
    }

    /// Details the rewards breakdown for an individual node and its delegators
    access(all) struct RewardsBreakdown {
        access(all) let nodeID: String
        access(all) var nodeRewards: UFix64
        access(all) let delegatorRewards: {UInt32: UFix64}

        init(nodeID: String) {
            self.nodeID = nodeID
            self.nodeRewards = 0.0
            self.delegatorRewards = {}
        }

        /// Scale the rewards of a single delegator by a scaling factor
        access(all) fun scaleDelegatorRewards(delegatorID: UInt32, scalingFactor: UFix64) {
            if let reward = self.delegatorRewards[delegatorID] {
                    self.delegatorRewards[delegatorID] = reward * scalingFactor
            }
        }
        
        access(all) fun scaleOperatorRewards(scalingFactor: UFix64) {
            self.nodeRewards = self.nodeRewards * scalingFactor
        }

        /// Scale the rewards of all the stakers in the record
        access(all) fun scaleAllRewards(scalingFactor: UFix64) {
            self.scaleOperatorRewards(scalingFactor: scalingFactor)
            for id in self.delegatorRewards.keys {
                self.scaleDelegatorRewards(delegatorID: id, scalingFactor: scalingFactor)
            }
        }

        /// Sets the reward amount for a specific delegator of this node
        access(all) fun setDelegatorReward(delegatorID: UInt32, rewards: UFix64) {
            self.delegatorRewards[delegatorID] = rewards
        }
    }

    /// Interface that only contains operations that are part
    /// of the regular automated functioning of the epoch process
    /// These are accessed by the `FlowEpoch` contract through a capability
    access(all) resource interface EpochOperations {
        access(all) fun setEpochTokenPayout(_ newPayout: UFix64)
        access(all) fun setSlotLimits(slotLimits: {UInt8: UInt16})
        access(all) fun setNodeWeight(nodeID: String, weight: UInt64)
        access(all) fun startStakingAuction()
        access(all) fun endStakingAuction()
        access(all) fun payRewards(_ rewardsSummary: EpochRewardsSummary)
        access(all) fun calculateRewards(): EpochRewardsSummary
        access(all) fun moveTokens()
    }
    
    /// Admin resource that has the ability to create new staker objects, remove insufficiently staked nodes
    /// at the end of the staking auction, and pay rewards to nodes at the end of an epoch
    access(all) resource Admin: EpochOperations {

        /// Sets a new set of minimum staking requirements for all the nodes
        /// Nodes' indexes are their role numbers
        access(all) fun setMinimumStakeRequirements(_ newRequirements: {UInt8: UFix64}) {
            pre {
                newRequirements.keys.length == 5:
                    "There must be six entries for node minimum stake requirements"
            }
            FlowIDTableStaking.minimumStakeRequired = newRequirements
            emit NewStakingMinimums(newMinimums: newRequirements)
        }

        /// Sets a new set of minimum staking requirements for all the delegators
        access(all) fun setDelegatorMinimumStakeRequirement(_ newRequirement: UFix64) {
            FlowIDTableStaking.account.load<UFix64>(from: /storage/delegatorStakingMinimum)
            FlowIDTableStaking.account.save(newRequirement, to: /storage/delegatorStakingMinimum)

            emit NewDelegatorStakingMinimum(newMinimum: newRequirement)
        }

        /// Changes the total weekly payout to a new value
        access(all) fun setEpochTokenPayout(_ newPayout: UFix64) {
            if newPayout != FlowIDTableStaking.epochTokenPayout {
                emit NewWeeklyPayout(newPayout: newPayout)
            }
            FlowIDTableStaking.epochTokenPayout = newPayout
        }

        /// Sets a new delegator cut percentage that nodes take from delegator rewards
        access(all) fun setCutPercentage(_ newCutPercentage: UFix64) {
            pre {
                newCutPercentage > 0.0 && newCutPercentage < 1.0:
                    "Cut percentage must be between 0 and 1!"
            }
            if newCutPercentage != FlowIDTableStaking.nodeDelegatingRewardCut {
                emit NewDelegatorCutPercentage(newCutPercentage: newCutPercentage)
            }
            FlowIDTableStaking.nodeDelegatingRewardCut = newCutPercentage
        }

        /// Sets new limits to the number of candidate nodes for an epoch
        access(all) fun setCandidateNodeLimit(role: UInt8, newLimit: UInt64) {
            pre {
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
            }

            let candidateNodeLimits = FlowIDTableStaking.account.load<{UInt8: UInt64}>(from: /storage/idTableCandidateNodeLimits)!
            candidateNodeLimits[role] = newLimit
            FlowIDTableStaking.account.save<{UInt8: UInt64}>(candidateNodeLimits, to: /storage/idTableCandidateNodeLimits)
        }

        /// Set slot (count) limits for each node role
        /// The slot limit limits the number of participant nodes with the given role which may be added to the network.
        /// It only prevents candidate nodes from joining. It does not cause existing participant nodes to unstake,
        /// even if the number of participant nodes exceeds the slot limit.
        access(all) fun setSlotLimits(slotLimits: {UInt8: UInt16}) {
            pre {
                slotLimits.keys.length == 5: "Slot Limits Dictionary can only have 5 entries"
                slotLimits[UInt8(1)] != nil: "Need to have a limit set for collector nodes"
                slotLimits[UInt8(2)] != nil: "Need to have a limit set for consensus nodes"
                slotLimits[UInt8(3)] != nil: "Need to have a limit set for execution nodes"
                slotLimits[UInt8(4)] != nil: "Need to have a limit set for verification nodes"
                slotLimits[UInt8(5)] != nil: "Need to have a limit set for access nodes"
            }

            FlowIDTableStaking.account.load<{UInt8: UInt16}>(from: /storage/flowStakingSlotLimits)
            FlowIDTableStaking.account.save(slotLimits, to: /storage/flowStakingSlotLimits)
        }


        /// Sets a list of node IDs who will not receive rewards for the current epoch
        /// This is used during epochs to punish nodes who have poor uptime 
        /// or who do not update to latest node software quickly enough
        /// The parameter is a dictionary mapping node IDs
        /// to a percentage, which is the percentage of their expected rewards that
        /// they will receive instead of the full amount
        access(all) fun setNonOperationalNodesList(_ nodeIDs: {String: UFix64}) {
            for percentage in nodeIDs.values {
                assert(
                    percentage >= 0.0 && percentage < 1.0,
                    message: "Percentage value to decrease rewards payout should be between 0 and 1"
                )
            }

            let list = FlowIDTableStaking.account.load<{String: UFix64}>(from: /storage/idTableNonOperationalNodesList)

            FlowIDTableStaking.account.save<{String: UFix64}>(nodeIDs, to: /storage/idTableNonOperationalNodesList)
        }

        /// Allows the protocol to set a specific weight for a node
        /// if their staked amount changes or if they are removed
        access(all) fun setNodeWeight(nodeID: String, weight: UInt64) {
            if weight > 100 {
                panic("Specified node weight out of range.")
            }

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)
            nodeRecord.initialWeight = weight

            emit NodeWeightChanged(nodeID: nodeID, newWeight: weight)
        }

        /// Sets a list of approved node IDs for the next epoch
        /// Nodes not on this list will be unstaked at the end of the staking auction
        /// and not considered to be a proposed/staked node
        access(all) fun setApprovedList(_ newApproveList: {String: Bool}) {
            let currentApproveList = FlowIDTableStaking.getApprovedList()
                ?? panic("Could not load approve list from storage")

            for id in newApproveList.keys {
                if FlowIDTableStaking.nodes[id] == nil {
                    panic("Approved node ".concat(id).concat(" does not already exist in the identity table"))
                }
            }

            // If one of the nodes has been removed from the approve list
            // it need to be set as movesPending so it
            // will be caught in the `removeInvalidNodes` method
            // If this happens not during the staking auction, the node should be removed
            // and marked to unstake immediately
            for id in currentApproveList.keys {
                if newApproveList[id] == nil {
                    if FlowIDTableStaking.stakingEnabled() {
                        FlowIDTableStaking.setNewMovesPending(nodeID: id, delegatorID: nil)
                    } else {
                        self.unsafeRemoveAndRefundNodeRecord(id)
                    }
                }
            }

            self.unsafeSetApprovedList(newApproveList)
        }

        /// sets the approved list without validating it (requires caller to validate)
        access(self) fun unsafeSetApprovedList(_ newApproveList: {String: Bool}) {
            let currentApproveList = FlowIDTableStaking.account.load<{String: Bool}>(from: /storage/idTableApproveList)
                ?? panic("Could not load the current approve list from storage")
            FlowIDTableStaking.account.save<{String: Bool}>(newApproveList, to: /storage/idTableApproveList)
        }

        /// removes and refunds the node record without also removing them from the approved-list
        access(self) fun unsafeRemoveAndRefundNodeRecord(_ nodeID: String) {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            emit NodeRemovedAndRefunded(nodeID: nodeRecord.id, amount: nodeRecord.tokensCommitted.balance + nodeRecord.tokensStaked.balance)

            // move their committed tokens back to their unstaked tokens
            nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

            // If the node is currently staked, unstake it and subtract one from the count
            // if staking is currently disabled, then that means that the node
            // has already been added to the node counts and needs to be subtracted also
            if nodeRecord.tokensStaked.balance > 0.0 || !FlowIDTableStaking.stakingEnabled() {
                // Set their request to unstake equal to all their staked tokens
                // since they are forced to unstake
                nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance

                // Subract 1 from the counts for this node's role
                // Since they will not fill an open slot any more
                var currentRoleNodeCounts: {UInt8: UInt16} = FlowIDTableStaking.getCurrentRoleNodeCounts()
                var currentRoleCount = currentRoleNodeCounts[nodeRecord.role]!
                if currentRoleCount > 0 {
                    currentRoleNodeCounts[nodeRecord.role] = currentRoleCount - 1
                }
                FlowIDTableStaking.account.load<{UInt8: UInt16}>(from: /storage/flowStakingRoleNodeCounts)
                FlowIDTableStaking.account.save(currentRoleNodeCounts, to: /storage/flowStakingRoleNodeCounts)
            }

            // Iterate through all delegators and unstake their tokens
            // since their node has unstaked
            for delegator in nodeRecord.delegators.keys {
                let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                if delRecord.tokensCommitted.balance > 0.0 {
                    emit DelegatorTokensUnstaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensCommitted.balance)

                    // move their committed tokens back to their unstaked tokens
                    delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                }

                // Request to unstake all tokens
                if delRecord.tokensStaked.balance > 0.0 {
                    delRecord.tokensRequestedToUnstake = delRecord.tokensStaked.balance
                    FlowIDTableStaking.setNewMovesPending(nodeID: nodeRecord.id, delegatorID: delegator)
                }
            }

            FlowIDTableStaking.setNewMovesPending(nodeID: nodeRecord.id, delegatorID: nil)

            FlowIDTableStaking.removeFromCandidateNodeList(nodeID: nodeRecord.id, role: nodeRecord.role)

            // Clear initial weight because the node is not staked any more
            nodeRecord.initialWeight = 0
        }

        /// Removes nodes by setting their weight to zero and refunding
        /// staked and delegated tokens.
        access(all) fun removeAndRefundNodeRecord(_ nodeID: String) {
            // remove the refunded node from the approve list
            let approveList = FlowIDTableStaking.getApprovedList()
                ?? panic("Could not load approve list from storage")
            approveList[nodeID] = nil
            self.unsafeSetApprovedList(approveList)

            // refund it
            self.unsafeRemoveAndRefundNodeRecord(nodeID)
        }

        /// Starts the staking auction, the period when nodes and delegators
        /// are allowed to perform staking related operations
        access(all) fun startStakingAuction() {
            FlowIDTableStaking.account.load<Bool>(from: /storage/stakingEnabled)
            FlowIDTableStaking.account.save(true, to: /storage/stakingEnabled)
        }

        /// Ends the staking Auction by removing any unapproved nodes
        /// and setting stakingEnabled to false
        access(all) fun endStakingAuction() {
            let approvedNodeIDs = FlowIDTableStaking.getApprovedList()
                ?? panic("Could not read the approve list from storage")

            self.removeInvalidNodes(approvedNodeIDs: approvedNodeIDs)

            self.fillNodeRoleSlots()

            FlowIDTableStaking.account.load<Bool>(from: /storage/stakingEnabled)
            FlowIDTableStaking.account.save(false, to: /storage/stakingEnabled)
        }

        /// Iterates through all the registered nodes and if it finds
        /// a node that has insufficient tokens committed for the next epoch or isn't in the approved list
        /// it moves their committed tokens to their unstaked bucket
        ///
        /// Parameter: approvedNodeIDs: A list of nodeIDs that have been approved
        /// by the protocol to be a staker for the next epoch. The node software
        /// checks if the node that corresponds to each proposed ID is running properly
        /// and that its node info is correct
        access(all) fun removeInvalidNodes(approvedNodeIDs: {String: Bool}) {
            let movesPendingList = FlowIDTableStaking.getMovesPendingList()
                ?? panic("Could not copy moves pending list from storage")

            // We only iterate through movesPendingList here because any node
            // that has insufficient stake committed will be because it has submitted
            // a staking operation that would have gotten it into that state to be removed
            // and candidate nodes will also be on the movesPendingList
            // to get their initialWeight set to 100
            // Nodes removed from the approve list are already refunded at the time
            // of removal in the setApprovedList method
            for nodeID in movesPendingList.keys {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                let totalTokensCommitted = nodeRecord.nodeFullCommittedBalance()

                let greaterThanMin = FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: totalTokensCommitted, role: nodeRecord.role)
                let nodeIsApproved: Bool =  approvedNodeIDs[nodeID] ?? false

                // admin-approved node roles (execution/collection/consensus/verification)
                // must be approved AND have sufficient stake
                if nodeRecord.role != UInt8(5) && (!greaterThanMin || !nodeIsApproved) {
                    self.removeAndRefundNodeRecord(nodeID)
                    FlowIDTableStaking.removeFromCandidateNodeList(nodeID: nodeRecord.id, role: nodeRecord.role)
                    continue
                }

                // permissionless node roles (access)
                // NOTE: Access nodes which registered prior to the 100-FLOW stake requirement
                // (which must be approved) are not removed during a temporary grace period during 
                // which these grandfathered node operators may submit the necessary stake requirement.
                // Therefore Access nodes must either be approved OR have sufficient stake:
                //  - Old ANs must be approved, but are allowed to have zero stake
                //  - New ANs may be unapproved, but must have submitted sufficient stake
                if nodeRecord.role == UInt8(5) && !greaterThanMin && !nodeIsApproved {
                    self.removeAndRefundNodeRecord(nodeID)
                    continue
                }

                nodeRecord.initialWeight = 100
            }
        }

        /// Each node role only has a certain number of slots available per epoch
        /// so if there are more candidate nodes for that role than there are slots
        /// nodes are randomly selected from the list to be included.
        /// Nodes which are not selected for inclusion are removed and refunded in this function.
        /// All candidate nodes left staked after this function exits are implicitly selected to fill the 
        /// available slots, and will become participants at the next epoch transition.
        /// 
        access(all) fun fillNodeRoleSlots() {

            var currentNodeCount: {UInt8: UInt16} = FlowIDTableStaking.getCurrentRoleNodeCounts()

            let slotLimits: {UInt8: UInt16} = FlowIDTableStaking.getRoleSlotLimits()

            // Load and reset the candidate node list
            let candidateNodes = FlowIDTableStaking.account.load<{UInt8: {String: Bool}}>(from: /storage/idTableCandidateNodes) ?? {}
            let emptyCandidateNodes: {UInt8: {String: Bool}} = {1: {}, 2: {}, 3: {}, 4: {}, 5: {}}
            FlowIDTableStaking.account.save(emptyCandidateNodes, to: /storage/idTableCandidateNodes)

            for role in currentNodeCount.keys {

                let candidateNodesForRole = candidateNodes[role]!

                if currentNodeCount[role]! >= slotLimits[role]! {
                    // if all slots are full, remove and refund all pending nodes
                    for nodeID in candidateNodesForRole.keys {
                        self.removeAndRefundNodeRecord(nodeID)
                    }
                } else if currentNodeCount[role]! + UInt16(candidateNodesForRole.keys.length) > slotLimits[role]! {
                    
                    // Not all slots are full, but addition of all the candidate nodes exceeds the slot limit
                    // Calculate how many nodes to remove from the candidate list for this role
                    var numNodesToRemove: UInt16 = currentNodeCount[role]! + UInt16(candidateNodesForRole.keys.length) - slotLimits[role]!
                    
                    let numNodesToAdd = UInt16(candidateNodesForRole.keys.length) - numNodesToRemove

                    // Indicates which indicies in the candidate nodes array will be removed
                    var deletionList: {UInt16: Bool} = {}
                    
                    // Randomly select which indicies will be removed
                    while numNodesToRemove > 0 {
                        let selection = UInt16(unsafeRandom() % UInt64(candidateNodesForRole.keys.length))
                        // If the index has already, been selected, try again
                        // if it has not, mark it to be removed
                        if deletionList[selection] == nil {
                            deletionList[selection] = true
                            numNodesToRemove = numNodesToRemove - 1
                        }
                    }

                    // Remove and Refund the selected nodes
                    for nodeIndex in deletionList.keys {
                        let nodeID = candidateNodesForRole.keys[nodeIndex]
                        self.removeAndRefundNodeRecord(nodeID)
                    }

                    // Set the current node count for the role to the limit for the role, since they were all filled
                    currentNodeCount[role] = currentNodeCount[role]! + numNodesToAdd

                } else {
                    // Not all the slots are full, and the addition of all the candidate nodes
                    // does not exceed the slot limit
                    // No action is needed to mark the nodes as added because they are already included
                    currentNodeCount[role] = currentNodeCount[role]! + UInt16(candidateNodesForRole.keys.length)
                }
            }

            FlowIDTableStaking.account.load<{UInt8: UInt16}>(from: /storage/flowStakingRoleNodeCounts)
            FlowIDTableStaking.account.save(currentNodeCount, to: /storage/flowStakingRoleNodeCounts)
        }

        /// Called at the end of the epoch to pay rewards to node operators
        /// based on the tokens that they have staked
        access(all) fun payRewards(_ rewardsSummary: EpochRewardsSummary) {

            let rewardsBreakdownArray = rewardsSummary.breakdown
            let totalRewards = rewardsSummary.totalRewards
            
            // If there are no node operators to pay rewards to, do not mint new tokens
            if rewardsBreakdownArray.length == 0 {
                emit EpochTotalRewardsPaid(total: totalRewards, fromFees: 0.0, minted: 0.0, feesBurned: 0.0)

                // Clear the non-operational node list so it doesn't persist to the next rewards payment
                let emptyNodeList: {String: UFix64} = {}
                self.setNonOperationalNodesList(emptyNodeList)

                return
            } 

            let feeBalance = FlowFees.getFeeBalance()
            var mintedRewards: UFix64 = 0.0
            if feeBalance < totalRewards {
                mintedRewards = totalRewards - feeBalance
            }

            // Borrow the fee admin and withdraw all the fees that have been collected since the last rewards payment
            let feeAdmin = FlowIDTableStaking.borrowFeesAdmin()
            let rewardsVault <- feeAdmin.withdrawTokensFromFeeVault(amount: feeBalance)

            // Mint the remaining FLOW for rewards
            if mintedRewards > 0.0 {
                let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                    ?? panic("Could not borrow minter reference")
                rewardsVault.deposit(from: <-flowTokenMinter.mintTokens(amount: mintedRewards))
            }

            for rewardBreakdown in rewardsBreakdownArray {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(rewardBreakdown.nodeID)
                let nodeReward = rewardBreakdown.nodeRewards
                
                nodeRecord.tokensRewarded.deposit(from: <-rewardsVault.withdraw(amount: nodeReward))

                for delegator in rewardBreakdown.delegatorRewards.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)
                    let delegatorReward = rewardBreakdown.delegatorRewards[delegator]!
                        
                    delRecord.tokensRewarded.deposit(from: <-rewardsVault.withdraw(amount: delegatorReward))
                    emit DelegatorRewardsPaid(nodeID: rewardBreakdown.nodeID, delegatorID: delegator, amount: delegatorReward)
                }

                emit RewardsPaid(nodeID: rewardBreakdown.nodeID, amount: nodeReward)
            }

            var fromFees = feeBalance
            if feeBalance >= totalRewards {
                fromFees = totalRewards
            }
            emit EpochTotalRewardsPaid(total: totalRewards, fromFees: fromFees, minted: mintedRewards, feesBurned: rewardsVault.balance)

            // Clear the non-operational node list so it doesn't persist to the next rewards payment
            let emptyNodeList: {String: UFix64} = {}
            self.setNonOperationalNodesList(emptyNodeList)

            // Destroy the remaining fees, even if there are some left
            destroy rewardsVault
        }

        /// Calculates rewards for all the staked node operators and delegators
        access(all) fun calculateRewards(): EpochRewardsSummary {
            let stakedNodeIDs: {String: Bool} = FlowIDTableStaking.getParticipantNodeList()!

            // Get the sum of all tokens staked
            var totalStaked = FlowIDTableStaking.getTotalStaked()
            if totalStaked == 0.0 {
                return EpochRewardsSummary(totalRewards: 0.0, breakdown: [])
            }
            // Calculate the scale to be multiplied by number of tokens staked per node
            var totalRewardScale = FlowIDTableStaking.epochTokenPayout / totalStaked

            var rewardsBreakdownArray: [FlowIDTableStaking.RewardsBreakdown] = []

            // The total rewards that are withheld from the non-operational nodes
            var sumRewardsWithheld = 0.0

            // The total amount of stake from non-operational nodes and delegators
            var sumStakeFromNonOperationalStakers = 0.0

            // Iterate through all the non-operational nodes and calculate
            // their rewards that will be withheld
            let nonOperationalNodes = FlowIDTableStaking.getNonOperationalNodesList()
            for nodeID in nonOperationalNodes.keys {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                // Each node's rewards can be decreased to a different percentage
                // Its delegator's rewards are also decreased to the same percentage
                let rewardDecreaseToPercentage = nonOperationalNodes[nodeID]!

                sumStakeFromNonOperationalStakers = sumStakeFromNonOperationalStakers + nodeRecord.tokensStaked.balance

                // Calculate the normal reward amount, then the rewards left after the decrease
                var nodeRewardAmount = nodeRecord.tokensStaked.balance * totalRewardScale
                var nodeRewardsAfterWithholding = nodeRewardAmount * rewardDecreaseToPercentage

                // Add the remaining to the total number of rewards withheld
                sumRewardsWithheld = sumRewardsWithheld + (nodeRewardAmount - nodeRewardsAfterWithholding)

                let rewardsBreakdown = FlowIDTableStaking.RewardsBreakdown(nodeID: nodeID)

                // Iterate through all the withheld node's delegators
                // and calculate their decreased rewards as well
                for delegator in nodeRecord.delegators.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                    sumStakeFromNonOperationalStakers = sumStakeFromNonOperationalStakers + delRecord.tokensStaked.balance

                    // Calculate the amount of tokens that this delegator receives
                    // decreased to the percentage from the non-operational node
                    var delegatorRewardAmount = delRecord.tokensStaked.balance * totalRewardScale
                    var delegatorRewardsAfterWithholding = delegatorRewardAmount * rewardDecreaseToPercentage

                    // Add the withheld rewards to the total sum
                    sumRewardsWithheld = sumRewardsWithheld + (delegatorRewardAmount - delegatorRewardsAfterWithholding)

                    if delegatorRewardsAfterWithholding == 0.0 { continue }

                    // take the node operator's cut
                    if (delegatorRewardsAfterWithholding * FlowIDTableStaking.nodeDelegatingRewardCut) > 0.0 {

                        let nodeCutAmount = delegatorRewardsAfterWithholding * FlowIDTableStaking.nodeDelegatingRewardCut

                        nodeRewardsAfterWithholding = nodeRewardsAfterWithholding + nodeCutAmount

                        delegatorRewardsAfterWithholding = delegatorRewardsAfterWithholding - nodeCutAmount
                    }
                    rewardsBreakdown.setDelegatorReward(delegatorID: delegator, rewards: delegatorRewardsAfterWithholding)
                }

                rewardsBreakdown.nodeRewards = nodeRewardsAfterWithholding
                rewardsBreakdownArray.append(rewardsBreakdown)
            }

            var withheldRewardsScale = sumRewardsWithheld / (totalStaked - sumStakeFromNonOperationalStakers)
            let totalRewardsPlusWithheld = totalRewardScale + withheldRewardsScale

            /// iterate through all the nodes to pay
            for nodeID in stakedNodeIDs.keys {
                if nonOperationalNodes[nodeID] != nil { continue }

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                var nodeRewardAmount = nodeRecord.tokensStaked.balance * totalRewardsPlusWithheld

                if nodeRewardAmount == 0.0 || nodeRecord.role == UInt8(5)  { continue }

                let rewardsBreakdown = FlowIDTableStaking.RewardsBreakdown(nodeID: nodeID)

                // Iterate through all delegators and reward them their share
                // of the rewards for the tokens they have staked for this node
                for delegator in nodeRecord.delegators.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                    /// Calculate the amount of tokens that this delegator receives
                    var delegatorRewardAmount = delRecord.tokensStaked.balance * totalRewardsPlusWithheld

                    if delegatorRewardAmount == 0.0 { continue }

                    // take the node operator's cut
                    if (delegatorRewardAmount * FlowIDTableStaking.nodeDelegatingRewardCut) > 0.0 {

                        let nodeCutAmount = delegatorRewardAmount * FlowIDTableStaking.nodeDelegatingRewardCut

                        nodeRewardAmount = nodeRewardAmount + nodeCutAmount

                        delegatorRewardAmount = delegatorRewardAmount - nodeCutAmount
                    }
                    rewardsBreakdown.setDelegatorReward(delegatorID: delegator, rewards: delegatorRewardAmount)
                }
                
                rewardsBreakdown.nodeRewards = nodeRewardAmount
                rewardsBreakdownArray.append(rewardsBreakdown)
            }

            let summary = EpochRewardsSummary(totalRewards: FlowIDTableStaking.epochTokenPayout, breakdown: rewardsBreakdownArray)

            return summary
        }

        /// Called at the end of the epoch to move tokens between buckets
        /// for stakers
        /// Tokens that have been committed are moved to the staked bucket
        /// Tokens that were unstaking during the last epoch are fully unstaked
        /// Unstaking requests are filled by moving those tokens from staked to unstaking
        access(all) fun moveTokens() {
            pre {
                !FlowIDTableStaking.stakingEnabled(): "Cannot move tokens if the staking auction is still in progress"
            }

            let approvedNodeIDs = FlowIDTableStaking.getApprovedList()
                ?? panic("Could not read the approve list from storage")

            let movesPendingNodeIDs = FlowIDTableStaking.account.load<{String: {UInt32: Bool}}>(from: /storage/idTableMovesPendingList)
                ?? panic("No moves pending list in account storage")

            // Reset the movesPendingList
            let movesPendingList: {String: {UInt32: Bool}} = {}
            FlowIDTableStaking.account.save<{String: {UInt32: Bool}}>(movesPendingList, to: /storage/idTableMovesPendingList)

            let stakedNodeIDs: {String: Bool} = FlowIDTableStaking.getParticipantNodeList()!

            for nodeID in movesPendingNodeIDs.keys {
                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                let approved = approvedNodeIDs[nodeID] ?? false

                // mark the committed tokens as staked
                if nodeRecord.tokensCommitted.balance > 0.0 || approved {
                    FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + nodeRecord.tokensCommitted.balance
                    emit TokensStaked(nodeID: nodeRecord.id, amount: nodeRecord.tokensCommitted.balance)
                    nodeRecord.tokensStaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))
                    stakedNodeIDs[nodeRecord.id] = true
                }

                // marked the unstaking tokens as unstaked
                if nodeRecord.tokensUnstaking.balance > 0.0 {
                    emit TokensUnstaked(nodeID: nodeRecord.id, amount: nodeRecord.tokensUnstaking.balance)
                    nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensUnstaking.withdraw(amount: nodeRecord.tokensUnstaking.balance))
                }

                // unstake the requested tokens and move them to tokensUnstaking
                if nodeRecord.tokensRequestedToUnstake > 0.0 {
                    emit TokensUnstaking(nodeID: nodeRecord.id, amount: nodeRecord.tokensRequestedToUnstake)
                    nodeRecord.tokensUnstaking.deposit(from: <-nodeRecord.tokensStaked.withdraw(amount: nodeRecord.tokensRequestedToUnstake))
                    // If the node no longer has above the minimum, remove them from the list of active nodes
                    if !FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: nodeRecord.tokensStaked.balance, role: nodeRecord.role) {
                        stakedNodeIDs[nodeRecord.id] = nil
                    }
                    // unstaked tokens automatically mark the node as pending
                    // because they will move in the next epoch
                    FlowIDTableStaking.setNewMovesPending(nodeID: nodeID, delegatorID: nil)
                }

                let pendingDelegatorsList = movesPendingNodeIDs[nodeID]!

                // move all the delegators' tokens between buckets
                for delegator in pendingDelegatorsList.keys {
                    let delRecord = nodeRecord.borrowDelegatorRecord(delegator)

                    // If the delegator's committed tokens for the next epoch
                    // is less than the delegator minimum, unstake all their tokens
                    let actualCommittedForNextEpoch = delRecord.tokensCommitted.balance + delRecord.tokensStaked.balance - delRecord.tokensRequestedToUnstake
                    if actualCommittedForNextEpoch < FlowIDTableStaking.getDelegatorMinimumStakeRequirement() {
                        delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                        delRecord.tokensRequestedToUnstake = delRecord.tokensStaked.balance
                    }

                    FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + delRecord.tokensCommitted.balance

                    // mark their committed tokens as staked
                    if delRecord.tokensCommitted.balance > 0.0 {
                        emit DelegatorTokensStaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensCommitted.balance)
                        delRecord.tokensStaked.deposit(from: <-delRecord.tokensCommitted.withdraw(amount: delRecord.tokensCommitted.balance))
                    }

                    // marked the unstaking tokens as unstaked
                    if delRecord.tokensUnstaking.balance > 0.0 {
                        emit DelegatorTokensUnstaked(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensUnstaking.balance)
                        delRecord.tokensUnstaked.deposit(from: <-delRecord.tokensUnstaking.withdraw(amount: delRecord.tokensUnstaking.balance))
                    }

                    // unstake the requested tokens and move them to tokensUnstaking
                    if delRecord.tokensRequestedToUnstake > 0.0 {
                        emit DelegatorTokensUnstaking(nodeID: nodeRecord.id, delegatorID: delegator, amount: delRecord.tokensRequestedToUnstake)
                        delRecord.tokensUnstaking.deposit(from: <-delRecord.tokensStaked.withdraw(amount: delRecord.tokensRequestedToUnstake))
                        // unstaked tokens automatically mark the delegator as pending
                        // because they will move in the next epoch
                        FlowIDTableStaking.setNewMovesPending(nodeID: nodeID, delegatorID: delegator)
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

            // Start the new epoch's staking auction
            self.startStakingAuction()

            // Set the current Epoch participant node list
            FlowIDTableStaking.setParticipantNodeList(stakedNodeIDs)

            // Indicates that the tokens have moved and the epoch has ended
            // Tells what the new reward payout will be. The new payout is calculated and changed
            // before this method is executed and will not be changed for the rest of the epoch
            emit NewEpoch(totalStaked: FlowIDTableStaking.getTotalStaked(), totalRewardPayout: FlowIDTableStaking.epochTokenPayout)
        }
    }

    /// Any user can call this function to register a new Node
    /// It returns the resource for nodes that they can store in their account storage
    access(all) fun addNodeRecord(id: String,
                          role: UInt8,
                          networkingAddress: String,
                          networkingKey: String,
                          stakingKey: String,
                          tokensCommitted: @FungibleToken.Vault): @NodeStaker
    {
        pre {
            FlowIDTableStaking.stakingEnabled(): "Cannot register a node operator if the staking auction isn't in progress"
        }

        let newNode <- create NodeRecord(id: id,
                                         role: role,
                                         networkingAddress: networkingAddress,
                                         networkingKey: networkingKey,
                                         stakingKey: stakingKey,
                                         tokensCommitted: <-FlowToken.createEmptyVault())

        let minimum = self.minimumStakeRequired[role]!

        assert(
            self.isGreaterThanMinimumForRole(numTokens: tokensCommitted.balance, role: role),
            message: "Tokens committed for registration is not above the minimum (".concat(minimum.toString()).concat(") for the chosen node role (".concat(role.toString()).concat(")"))
        )

        FlowIDTableStaking.nodes[id] <-! newNode

        // return a new NodeStaker object that the node operator stores in their account
        let nodeStaker <-create NodeStaker(id: id)

        nodeStaker.stakeNewTokens(<-tokensCommitted)

        return <-nodeStaker
    }

    /// Registers a new delegator with a unique ID for the specified node operator
    /// and returns a delegator object to the caller
    access(all) fun registerNewDelegator(nodeID: String, tokensCommitted: @FungibleToken.Vault): @NodeDelegator {
        pre {
            FlowIDTableStaking.stakingEnabled(): "Cannot register a node operator if the staking auction isn't in progress"
        }

        let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

        assert (
            nodeRecord.role != UInt8(5),
            message: "Cannot register a delegator for an access node"
        )

        let minimum = self.getDelegatorMinimumStakeRequirement()
        assert(
            tokensCommitted.balance >= minimum,
            message: "Tokens committed for delegator registration is not above the minimum (".concat(minimum.toString()).concat(")")
        )

        assert (
            FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: nodeRecord.nodeFullCommittedBalance(), role: nodeRecord.role),
            message: "Cannot register a delegator if the node operator is below the minimum stake"
        )

        // increment the delegator ID counter for this node
        nodeRecord.delegatorIDCounter = nodeRecord.delegatorIDCounter + UInt32(1)

        // Create a new delegator record and store it in the contract
        nodeRecord.setDelegator(delegatorID: nodeRecord.delegatorIDCounter, delegator: <- create DelegatorRecord())

        emit NewDelegatorCreated(nodeID: nodeRecord.id, delegatorID: nodeRecord.delegatorIDCounter)

        // Create a new NodeDelegator object that the owner stores in their account
        let newDelegator <-create NodeDelegator(id: nodeRecord.delegatorIDCounter, nodeID: nodeRecord.id)

        newDelegator.delegateNewTokens(from: <-tokensCommitted)

        return <-newDelegator
    }

    /// borrow a reference to to one of the nodes in the record
    access(account) view fun borrowNodeRecord(_ nodeID: String): &NodeRecord {
        pre {
            FlowIDTableStaking.nodes[nodeID] != nil:
                "Specified node ID does not exist in the record"
        }
        return (&FlowIDTableStaking.nodes[nodeID] as &NodeRecord?)!
    }

    /// borrow a reference to the `FlowFees` admin resource for paying rewards
    access(account) fun borrowFeesAdmin(): &FlowFees.Administrator {
        let feesAdmin = self.account.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
            ?? panic("Could not borrow a reference to the FlowFees Admin object")

        return feesAdmin
    }

    /// Updates a claimed boolean for a specific path to indicate that
    /// a piece of node metadata has been claimed by a node
    access(account) fun updateClaimed(path: StoragePath, _ key: String, claimed: Bool) {
        let claimedDictionary = self.account.load<{String: Bool}>(from: path)
            ?? panic("Invalid path for dictionary")

        if claimed {
            claimedDictionary[key] = true
        } else {
            claimedDictionary.remove(key: key)
        }

        self.account.save(claimedDictionary, to: path)
    }

    /// Sets a list of approved node IDs for the current epoch
    access(contract) fun setParticipantNodeList(_ nodeIDs: {String: Bool}) {
        let list = self.account.load<{String: Bool}>(from: /storage/idTableCurrentList)

        self.account.save<{String: Bool}>(nodeIDs, to: /storage/idTableCurrentList)
    }

    /// Gets the current list of participant (staked in the current epoch) nodes as a dictionary.
    access(all) view fun getParticipantNodeList(): {String: Bool}? {
        return self.account.copy<{String: Bool}>(from: /storage/idTableCurrentList)
    }

    /// Gets the current list of participant nodes (like getCurrentNodeList) but as a list
    /// Kept for backwards compatibility
    access(all) view fun getStakedNodeIDs(): [String] {
        let nodeIDs = self.getParticipantNodeList()!
        return nodeIDs.keys
    }

    /// Adds a node and/or a delegator to the list of node IDs who have pending token movements
    /// or whose delegators have pending movements
    access(contract) fun setNewMovesPending(nodeID: String, delegatorID: UInt32?) {
        if self.nodes[nodeID] == nil {
            return
        }
        let movesPendingList = self.account.load<{String: {UInt32: Bool}}>(from: /storage/idTableMovesPendingList)
            ?? panic("No moves pending list in account storage")

        // Create an empty list of delegators with pending moves for the node ID
        var delegatorList: {UInt32: Bool} = {}

        // If there is already a list for the given node ID, overwrite the created one
        if let existingDelegatorList = movesPendingList[nodeID] {
            delegatorList = existingDelegatorList
        }

        // If this function call is to record a delegator's movement,
        // record the ID
        if let unwrappedDelegatorID = delegatorID {
            delegatorList[unwrappedDelegatorID] = true
        }

        // Save the modified list to the node's entry
        // If it was just a node, it will save an empty/unmodified delegator list
        movesPendingList[nodeID] = delegatorList

        self.account.save<{String: {UInt32: Bool}}>(movesPendingList, to: /storage/idTableMovesPendingList)
    }

    /// Gets a list of node IDs who have pending token movements
    /// or who's delegators have pending movements
    access(all) view fun getMovesPendingList(): {String: {UInt32: Bool}}? {
        return self.account.copy<{String: {UInt32: Bool}}>(from: /storage/idTableMovesPendingList)
    }

    /// Candidate Nodes Methods
    ///
    /// Candidate Nodes are newly committed nodes who aren't already staked
    /// There is a limit to the number of candidate nodes per node role per epoch
    /// The candidate node list is a dictionary that maps node roles
    /// to a list of node IDs of that role
    /// Gets the candidate node list size limits for each role
    access(all) view fun getCandidateNodeLimits(): {UInt8: UInt64}? {
        return self.account.copy<{UInt8: UInt64}>(from: /storage/idTableCandidateNodeLimits)
    }

    /// Adds the provided node ID to the candidate node list
    access(contract) fun addToCandidateNodeList(nodeID: String, roleToAdd: UInt8) {
        pre {
            roleToAdd >= UInt8(1) && roleToAdd <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
        }

        var candidateNodes = FlowIDTableStaking.account.load<{UInt8: {String: Bool}}>(from: /storage/idTableCandidateNodes) ?? {}
        var candidateNodesForRole = candidateNodes[roleToAdd]!

        if UInt64(candidateNodesForRole.keys.length) >= self.getCandidateNodeLimits()![roleToAdd]! {
            panic("Candidate node limit exceeded for node role ".concat(roleToAdd.toString()))
        }

        candidateNodesForRole[nodeID] = true
        candidateNodes[roleToAdd] = candidateNodesForRole

        FlowIDTableStaking.account.save(candidateNodes, to: /storage/idTableCandidateNodes)
    }

    /// Removes the provided node ID from the candidate node list
    access(contract) fun removeFromCandidateNodeList(nodeID: String, role: UInt8) {
        pre {
            role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
        }

        var candidateNodes = FlowIDTableStaking.account.load<{UInt8: {String: Bool}}>(from: /storage/idTableCandidateNodes) ?? {}
        var candidateNodesForRole = candidateNodes[role]!
        
        candidateNodesForRole.remove(key: nodeID)
        candidateNodes[role] = candidateNodesForRole

        FlowIDTableStaking.account.save(candidateNodes, to: /storage/idTableCandidateNodes)
    }

    /// Returns the current candidate node list
    access(all) view fun getCandidateNodeList(): {UInt8: {String: Bool}} {
        return FlowIDTableStaking.account.copy<{UInt8: {String: Bool}}>(from: /storage/idTableCandidateNodes)
            ?? {1: {}, 2: {}, 3: {}, 4: {}, 5: {}}
    }

    /// Get slot (count) limits for each node role
    access(all) fun getRoleSlotLimits(): {UInt8: UInt16} {
        return FlowIDTableStaking.account.copy<{UInt8: UInt16}>(from: /storage/flowStakingSlotLimits)
            ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    }

    /// Returns a dictionary that indicates how many participant nodes there are for each role
    access(all) fun getCurrentRoleNodeCounts(): {UInt8: UInt16} {
        if let currentCounts = FlowIDTableStaking.account.copy<{UInt8: UInt16}>(from: /storage/flowStakingRoleNodeCounts) {
            return currentCounts
        } else {
            // If the contract can't read the value from storage, construct it
            let participantNodeIDs = FlowIDTableStaking.getParticipantNodeList()!

            let roleCounts: {UInt8: UInt16} = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

            for nodeID in participantNodeIDs.keys {
                let nodeInfo = FlowIDTableStaking.NodeInfo(id: nodeID)
                roleCounts[nodeInfo.role] = roleCounts[nodeInfo.role]! + 1
            }
            return roleCounts
        }
    }

    /// Checks if the given string has all numbers or lowercase hex characters
    /// Used to ensure that there are no duplicate node IDs
    access(all) view fun isValidNodeID(_ input: String): Bool {
        let byteVersion = input.utf8

        for character in byteVersion {
            if ((character < 48) || (character > 57 && character < 97) || (character > 102)) {
                return false
            }
        }

        return true
    }

    /// Indicates if the staking auction is currently enabled
    access(all) view fun stakingEnabled(): Bool {
        return self.account.copy<Bool>(from: /storage/stakingEnabled) ?? false
    }

    /// Gets an array of the node IDs that are proposed for the next epoch
    /// During the staking auction, this will not include access nodes who
    /// haven't been selected by the slot selection algorithm yet
    /// After the staking auction ends, specifically after unapproved nodes have been
    /// removed and slots have been filled and for the rest of the epoch,
    /// This list will accurately represent the nodes that will be in the next epoch
    access(all) fun getProposedNodeIDs(): [String] {

        let nodeIDs = FlowIDTableStaking.getNodeIDs()
        let approvedNodeIDs: {String: Bool} = FlowIDTableStaking.getApprovedList()
            ?? panic("Could not read the approve list from storage")
        let proposedNodeIDs: {String: Bool} = {}

        for nodeID in nodeIDs {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            let totalTokensCommitted = nodeRecord.nodeFullCommittedBalance()

            let greaterThanMin = FlowIDTableStaking.isGreaterThanMinimumForRole(numTokens: totalTokensCommitted, role: nodeRecord.role)
            let nodeIsApproved: Bool =  approvedNodeIDs[nodeID] ?? false
            let nodeWeight = nodeRecord.initialWeight

            // admin-approved node roles (execution/collection/consensus/verification)
            // must be approved AND have sufficient stake
            if nodeRecord.role != UInt8(5) && greaterThanMin && nodeIsApproved {
                proposedNodeIDs[nodeID] = true
                continue
            }

            // permissionless node roles (access)
            // NOTE: Access nodes which registered prior to the 100-FLOW stake requirement
            // (which must be approved) are not removed during a temporary grace period during 
            // which these grandfathered node operators may submit the necessary stake requirement.
            // Therefore Access nodes must either be approved OR have sufficient stake:
            //  - Old ANs must be approved, but are allowed to have zero stake
            //  - New ANs may be unapproved, but must have submitted sufficient stake
            if nodeRecord.role == UInt8(5) &&
               (greaterThanMin || nodeIsApproved) &&
               nodeWeight > 0
            {
                proposedNodeIDs[nodeID] = true
                continue
            }
        }
        return proposedNodeIDs.keys
    }

    /// Gets an array of all the node IDs that have ever registered
    access(all) view fun getNodeIDs(): [String] {
        return FlowIDTableStaking.nodes.keys
    }

    /// Checks if the amount of tokens is greater than the minimum staking requirement
    /// for the specified node role
    access(all) view fun isGreaterThanMinimumForRole(numTokens: UFix64, role: UInt8): Bool {
        let minimumStake = self.minimumStakeRequired[role]
            ?? panic("Incorrect role provided for minimum stake. Must be 1, 2, 3, 4, or 5")

        return numTokens >= minimumStake
    }

    /// Indicates if the specified networking address is claimed by a node
    access(all) view fun getNetworkingAddressClaimed(address: String): Bool {
        return self.getClaimed(path: /storage/networkingAddressesClaimed, key: address)
    }

    /// Indicates if the specified networking key is claimed by a node
    access(all) view fun getNetworkingKeyClaimed(key: String): Bool {
        return self.getClaimed(path: /storage/networkingKeysClaimed, key: key)
    }

    /// Indicates if the specified staking key is claimed by a node
    access(all) view fun getStakingKeyClaimed(key: String): Bool {
        return self.getClaimed(path: /storage/stakingKeysClaimed, key: key)
    }

    /// Gets the claimed status of a particular piece of node metadata
    access(account) view fun getClaimed(path: StoragePath, key: String): Bool {
		let claimedDictionary = self.account.borrow<&{String: Bool}>(from: path)
            ?? panic("Invalid path for dictionary")
        return claimedDictionary[key] ?? false
    }

    /// Returns the list of approved node IDs that the admin has set
    access(all) view un getApprovedList(): {String: Bool}? {
        return self.account.copy<{String: Bool}>(from: /storage/idTableApproveList)
    }

    /// Returns the list of node IDs whose rewards will be reduced in the next payment
    access(all) view fun getNonOperationalNodesList(): {String: UFix64} {
        return self.account.copy<{String: UFix64}>(from: /storage/idTableNonOperationalNodesList)
            ?? panic("could not get non-operational node list")
    }

    /// Gets the minimum stake requirements for all the node types
    access(all) view fun getMinimumStakeRequirements(): {UInt8: UFix64} {
        return self.minimumStakeRequired
    }

    /// Gets the minimum stake requirement for delegators
    access(all) fun getDelegatorMinimumStakeRequirement(): UFix64 {
        return self.account.copy<UFix64>(from: /storage/delegatorStakingMinimum)
            ?? 0.0
    }

    /// Gets a dictionary that indicates the current number of tokens staked
    /// by all the nodes of each type
    access(all) view fun getTotalTokensStakedByNodeType(): {UInt8: UFix64} {
        return self.totalTokensStakedByNodeType
    }

    /// Gets the total number of FLOW that is currently staked
    /// by all of the staked nodes in the current epoch
    access(all) view fun getTotalStaked(): UFix64 {
        var totalStaked: UFix64 = 0.0
        for nodeType in FlowIDTableStaking.totalTokensStakedByNodeType.keys {
            // Do not count access nodes
            if nodeType != UInt8(5) {
                totalStaked = totalStaked + FlowIDTableStaking.totalTokensStakedByNodeType[nodeType]!
            }
        }
        return totalStaked
    }

    /// Gets the token payout value for the current epoch
    access(all) view fun getEpochTokenPayout(): UFix64 {
        return self.epochTokenPayout
    }

    /// Gets the cut percentage for delegator rewards paid to node operators
    access(all) view fun getRewardCutPercentage(): UFix64 {
        return self.nodeDelegatingRewardCut
    }

    /// Gets the ratios of rewards that different node roles recieve
    /// NOTE: Currently is not used
    access(all) view fun getRewardRatios(): {UInt8: UFix64} {
        return self.rewardRatios
    }

    init(_ epochTokenPayout: UFix64, _ rewardCut: UFix64, _ candidateNodeLimits: {UInt8: UInt64}) {
        self.account.save(true, to: /storage/stakingEnabled)

        self.nodes <- {}

        let claimedDictionary: {String: Bool} = {}
        self.account.save(claimedDictionary, to: /storage/stakingKeysClaimed)
        self.account.save(claimedDictionary, to: /storage/networkingKeysClaimed)
        self.account.save(claimedDictionary, to: /storage/networkingAddressesClaimed)

        self.NodeStakerStoragePath = /storage/flowStaker
        self.NodeStakerPublicPath = /public/flowStaker
        self.StakingAdminStoragePath = /storage/flowStakingAdmin
        self.DelegatorStoragePath = /storage/flowStakingDelegator

        self.minimumStakeRequired = {UInt8(1): 250000.0, UInt8(2): 500000.0, UInt8(3): 1250000.0, UInt8(4): 135000.0, UInt8(5): 100.0}
        self.account.save(50.0 as UFix64, to: /storage/delegatorStakingMinimum)
        self.totalTokensStakedByNodeType = {UInt8(1): 0.0, UInt8(2): 0.0, UInt8(3): 0.0, UInt8(4): 0.0, UInt8(5): 0.0}
        self.epochTokenPayout = epochTokenPayout
        self.nodeDelegatingRewardCut = rewardCut
        self.rewardRatios = {UInt8(1): 0.168, UInt8(2): 0.518, UInt8(3): 0.078, UInt8(4): 0.236, UInt8(5): 0.0}

        let approveList: {String: Bool} = {}
        self.setParticipantNodeList(approveList)
        self.account.save<{String: Bool}>(approveList, to: /storage/idTableApproveList)

        let nonOperationalList: {String: UFix64} = {}
        self.account.save<{String: UFix64}>(nonOperationalList, to: /storage/idTableNonOperationalNodesList)

        let movesPendingList: {String: {UInt32: Bool}} = {}
        self.account.save<{String: {UInt32: Bool}}>(movesPendingList, to: /storage/idTableMovesPendingList)

        let emptyCandidateNodes: {UInt8: {String: Bool}} = {1: {}, 2: {}, 3: {}, 4: {}, 5: {}}
        FlowIDTableStaking.account.save(emptyCandidateNodes, to: /storage/idTableCandidateNodes)

        // Save the candidate nodes limit
        FlowIDTableStaking.account.save<{UInt8: UInt64}>(candidateNodeLimits, to: /storage/idTableCandidateNodeLimits)

        let slotLimits: {UInt8: UInt16} = {1: 10000, 2: 10000, 3: 10000, 4: 10000, 5: 10000}
        // Save slot limits
        FlowIDTableStaking.account.save(slotLimits, to: /storage/flowStakingSlotLimits)

        let slotCounts: {UInt8: UInt16} = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        // Save slot counts
        FlowIDTableStaking.account.save(slotCounts, to: /storage/flowStakingRoleNodeCounts)

        self.account.save(<-create Admin(), to: self.StakingAdminStoragePath)
    }
}
 
