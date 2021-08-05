/*

    TestFlowIDTableStaking

    This is a test contract to act as an API for
    testing the lockbox and staking proxy contracts.

 */

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowIDTableStaking {

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

        init(
            id: String,
            role: UInt8,  /// role that the node will have for future epochs
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            tokensCommitted: @FungibleToken.Vault
        ) {

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey

            destroy tokensCommitted
        }
    }

        // Struct to create to get read-only info about a node
    pub struct NodeInfo {
        pub let id: String
        pub let role: UInt8
        pub let networkingAddress: String
        pub let networkingKey: String
        pub let stakingKey: String
        pub let tokensStaked: UFix64
        pub let totalTokensStaked: UFix64
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

    /// Resource that the node operator controls for staking
    pub resource NodeStaker {

        /// Unique ID for the node operator
        pub let id: String

        init(id: String) {
            self.id = id
        }

        pub fun updateNetworkingAddress(_ newAddress: String) {
            
        }

        /// Add new tokens to the system to stake during the next epoch
        pub fun stakeNewTokens(_ tokens: @FungibleToken.Vault) {

            destroy tokens
        }

        /// Stake tokens that are in the tokensUnstaked bucket
        /// but haven't been officially staked
        pub fun stakeUnstakedTokens(amount: UFix64) {

        }

        /// Stake tokens that are in the tokensRewarded bucket
        /// but haven't been officially staked
        pub fun stakeRewardedTokens(amount: UFix64) {

        }

        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        pub fun requestUnstaking(amount: UFix64) {

        }

        /// Requests to unstake all of the node operators staked and committed tokens,
        /// as well as all the staked and committed tokens of all of their delegators
        pub fun unstakeAll() {

        }

        /// Withdraw tokens from the unstaked bucket
        pub fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {
            let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)

        }

        /// Withdraw tokens from the rewarded bucket
        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }

    }

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
    pub resource NodeDelegator {

        /// Each delegator for a node operator has a unique ID
        pub let id: UInt32

        /// The ID of the node operator that this delegator delegates to
        pub let nodeID: String

        init(id: UInt32, nodeID: String) {
            self.id = id
            self.nodeID = nodeID
        }

        /// Delegate new tokens to the node operator
        pub fun delegateNewTokens(from: @FungibleToken.Vault) {

            destroy from
        }

        /// Delegate tokens from the unstaked bucket to the node operator
        pub fun delegateUnstakedTokens(amount: UFix64) {

        }

        /// Delegate tokens from the rewards bucket to the node operator
        pub fun delegateRewardedTokens(amount: UFix64) {

        }

        /// Request to unstake delegated tokens during the next epoch
        pub fun requestUnstaking(amount: UFix64) {

        }

        /// Withdraw tokens from the unstaked bucket
        pub fun withdrawUnstakedTokens(amount: UFix64): @FungibleToken.Vault {
            let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }

        /// Withdraw tokens from the rewarded bucket
        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            let flowTokenMinter = FlowIDTableStaking.account.borrow<&FlowToken.Minter>(from: /storage/flowTokenMinter)
                ?? panic("Could not borrow minter reference")

            return <- flowTokenMinter.mintTokens(amount: amount)
        }
    }

    /// Any node can call this function to register a new Node
    /// It returns the resource for nodes that they can store in
    /// their account storage
    pub fun addNodeRecord(
        id: String,
        role: UInt8,
        networkingAddress: String,
        networkingKey: String,
        stakingKey: String,
        tokensCommitted: @FungibleToken.Vault
    ): @NodeStaker {
        destroy tokensCommitted

        // return a new NodeStaker object that the node operator stores in their account
        return <-create NodeStaker(id: id)

    }

    pub fun registerNewDelegator(nodeID: String): @NodeDelegator {

        return <-create NodeDelegator(id: 1, nodeID: nodeID)
    }

    init(_ epochTokenPayout: UFix64, _ rewardCut: UFix64) {
    }
}
