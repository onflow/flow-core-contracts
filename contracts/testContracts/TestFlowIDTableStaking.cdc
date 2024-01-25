/*

    TestFlowIDTableStaking

    This is a test contract to act as an API for
    testing the lockbox and staking proxy contracts.

 */

import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"
import Burner from "Burner"

access(all) contract FlowIDTableStaking {

    /*********** ID Table and Staking Composite Type Definitions *************/

    /// Contains information that is specific to a node in Flow
    /// only lives in this contract
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

        /// The address used for networking
        access(all) var networkingAddress: String

        /// the public key for networking
        access(all) var networkingKey: String

        /// the public key for staking
        access(all) var stakingKey: String

        init(
            id: String,
            role: UInt8,  /// role that the node will have for future epochs
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            tokensCommitted: @{FungibleToken.Vault}
        ) {

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey

            Burner.burn(<-tokensCommitted)
        }
    }

        // Struct to create to get read-only info about a node
    access(all) struct NodeInfo {
        access(all) let id: String
        access(all) let role: UInt8
        access(all) let networkingAddress: String
        access(all) let networkingKey: String
        access(all) let stakingKey: String
        access(all) let tokensStaked: UFix64
        access(all) let totalTokensStaked: UFix64
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

            self.id = nodeID
            self.role = 2
            self.networkingAddress = "address"
            self.networkingKey = "key"
            self.stakingKey = "key"
            self.tokensStaked = 0.0
            self.totalTokensStaked = 0.0
            self.tokensCommitted = 0.0
            self.tokensUnstaking = 0.0
            self.tokensUnstaked = 0.0
            self.tokensRewarded = 0.0
            self.delegators = []
            self.delegatorIDCounter = 0
            self.tokensRequestedToUnstake = 0.0
            self.initialWeight = 0
        }
    }

    access(all) entitlement NodeOperator

    /// Resource that the node operator controls for staking
    access(all) resource NodeStaker {

        /// Unique ID for the node operator
        access(all) let id: String

        init(id: String) {
            self.id = id
        }

        access(NodeOperator) fun updateNetworkingAddress(_ newAddress: String) {
            
        }

        /// Add new tokens to the system to stake during the next epoch
        access(NodeOperator) fun stakeNewTokens(_ tokens: @{FungibleToken.Vault}) {

            Burner.burn(<-tokens)
        }

        /// Stake tokens that are in the tokensUnstaked bucket
        /// but haven't been officially staked
        access(NodeOperator) fun stakeUnstakedTokens(amount: UFix64) {

        }

        /// Stake tokens that are in the tokensRewarded bucket
        /// but haven't been officially staked
        access(NodeOperator) fun stakeRewardedTokens(amount: UFix64) {

        }

        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        access(NodeOperator) fun requestUnstaking(amount: UFix64) {

        }

        /// Requests to unstake all of the node operators staked and committed tokens,
        /// as well as all the staked and committed tokens of all of their delegators
        access(NodeOperator) fun unstakeAll() {

        }

        /// Withdraw tokens from the unstaked bucket
        access(NodeOperator) fun withdrawUnstakedTokens(amount: UFix64): @{FungibleToken.Vault} {
            let flowTokenMinter = FlowIDTableStaking.account.storage.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)

        }

        /// Withdraw tokens from the rewarded bucket
        access(NodeOperator) fun withdrawRewardedTokens(amount: UFix64): @{FungibleToken.Vault} {
            let flowTokenMinter = FlowIDTableStaking.account.storage.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }

    }

    access(all) entitlement DelegatorOwner

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

            self.id = delegatorID
            self.nodeID = nodeID
            self.tokensCommitted = 0.0
            self.tokensStaked = 0.0
            self.tokensUnstaking = 0.0
            self.tokensUnstaked = 0.0
            self.tokensRewarded = 0.0
            self.tokensRequestedToUnstake = 0.0
        }

    }

    /// Resource object that the delegator stores in their account
    /// to perform staking actions
    access(all) resource NodeDelegator {

        /// Each delegator for a node operator has a unique ID
        access(all) let id: UInt32

        /// The ID of the node operator that this delegator delegates to
        access(all) let nodeID: String

        init(id: UInt32, nodeID: String) {
            self.id = id
            self.nodeID = nodeID
        }

        /// Delegate new tokens to the node operator
        access(DelegatorOwner) fun delegateNewTokens(from: @{FungibleToken.Vault}) {

            Burner.burn(<-from)
        }

        /// Delegate tokens from the unstaked bucket to the node operator
        access(DelegatorOwner) fun delegateUnstakedTokens(amount: UFix64) {

        }

        /// Delegate tokens from the rewards bucket to the node operator
        access(DelegatorOwner) fun delegateRewardedTokens(amount: UFix64) {

        }

        /// Request to unstake delegated tokens during the next epoch
        access(DelegatorOwner) fun requestUnstaking(amount: UFix64) {

        }

        /// Withdraw tokens from the unstaked bucket
        access(DelegatorOwner) fun withdrawUnstakedTokens(amount: UFix64): @{FungibleToken.Vault} {
            let flowTokenMinter = FlowIDTableStaking.account.storage.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        access(DelegatorOwner) fun withdrawRewardedTokens(amount: UFix64): @{FungibleToken.Vault} {
            let flowTokenMinter = FlowIDTableStaking.account.storage.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }
    }

    /// Any node can call this function to register a new Node
    /// It returns the resource for nodes that they can store in
    /// their account storage
    access(all) fun addNodeRecord(
        id: String,
        role: UInt8,
        networkingAddress: String,
        networkingKey: String,
        stakingKey: String,
        tokensCommitted: @{FungibleToken.Vault}
    ): @NodeStaker {
        Burner.burn(<-tokensCommitted)

        // return a new NodeStaker object that the node operator stores in their account
        return <-create NodeStaker(id: id)

    }

    access(all) fun registerNewDelegator(nodeID: String, tokensCommitted: @{FungibleToken.Vault}): @NodeDelegator {

        Burner.burn(<-tokensCommitted)

        return <-create NodeDelegator(id: 1, nodeID: nodeID)
    }

    /// Gets the minimum stake requirement for delegators
    access(all) fun getDelegatorMinimumStakeRequirement(): UFix64 {
        return self.account.storage.copy<UFix64>(from: /storage/delegatorStakingMinimum)
            ?? 0.0
    }

    init(_ epochTokenPayout: UFix64, _ rewardCut: UFix64, _ candidateLimits: {UInt8: UInt64}) {
    }
}
