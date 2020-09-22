/*
    Mock version of original contract with reduced functionality to test StakingHelper methods
 */

import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

pub contract FlowIDTableStaking {

    pub event NewNodeCreated(nodeID: String, amountCommitted: UFix64)
    pub event TokensCommitted(nodeID: String, amount: UFix64)
    pub event TokensStaked(nodeID: String, amount: UFix64)
    pub event TokensUnStaked(nodeID: String, amount: UFix64)
    pub event NodeRemovedAndRefunded(nodeID: String, amount: UFix64)
    pub event RewardsPaid(nodeID: String, amount: UFix64)
    pub event UnlockedTokensWithdrawn(nodeID: String, amount: UFix64)
    pub event RewardTokensWithdrawn(nodeID: String, amount: UFix64)

    pub resource NodeDelegator {
        /// Each delegator for a node operator has a unique ID
        pub let id: UInt32

        /// The ID of the node operator that this delegator delegates to
        pub let nodeID: String

        init(id: UInt32, nodeID: String) {
            self.id = id
            self.nodeID = nodeID
        }    
    }

    pub resource NodeStaker {
        pub let id: String
        pub let initialStake: UFix64

        /// The incrementing ID used to register new delegators
        access(self) var delegatorIDCounter: UInt32
        
        init(id: String, initialStake: UFix64) {
            self.id = id
            self.delegatorIDCounter = 0
            self.initialStake = initialStake
        }

        /// NOT IMPLEMENTED
        /// Add new tokens to the system to stake during the next epoch
        pub fun stakeNewTokens(_ tokens: @FungibleToken.Vault) {
            emit TokensCommitted(nodeID: self.id, amount: tokens.balance)
            
            destroy tokens
        }

        /// NOT IMPLEMENTED
        /// Stake tokens that are in the tokensUnlocked bucket 
        /// but haven't been officially staked
        pub fun stakeUnlockedTokens(amount: UFix64) {
           emit TokensCommitted(nodeID: self.id, amount: amount)    
        }

        /// NOT IMPLEMENTED
        /// Stake tokens that are in the tokensRewarded bucket 
        /// but haven't been officially staked
        pub fun stakeRewardedTokens(amount: UFix64) {
            emit TokensCommitted(nodeID: self.id, amount: amount)
        }

        /// NOT IMPLEMENTED
        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        pub fun requestUnStaking(amount: UFix64) {
            
        }

        /// NOT IMPLEMENTED
        /// Requests to unstake all of the node operators staked and committed tokens,
        /// as well as all the staked and committed tokens of all of their delegators
        pub fun unstakeAll() {

        }

        /// NOT IMPLEMENTED
        /// Withdraw tokens from the unlocked bucket
        pub fun withdrawUnlockedTokens(amount: UFix64): @FungibleToken.Vault {
            emit UnlockedTokensWithdrawn(nodeID: self.id, amount: amount)
            
            return <- FlowToken.createEmptyVault()
        }

        /// NOT IMPLEMENTED
        /// Withdraw tokens from the rewarded bucket
        pub fun withdrawRewardedTokens(amount: UFix64): @FungibleToken.Vault {
            emit RewardTokensWithdrawn(nodeID: self.id, amount: amount)

            return <- FlowToken.createEmptyVault()
        }

        // TODO: This should be in StakingHelper as well?
        pub fun createNewDelegator(): @NodeDelegator {
            return <-create NodeDelegator(id: self.delegatorIDCounter, nodeID: self.id)    
        }
    }

    pub fun addNodeRecord(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, tokensCommitted: @FungibleToken.Vault, cutPercentage: UFix64): @NodeStaker {
        let initialBalance = tokensCommitted.balance
        destroy tokensCommitted

        // return a new NodeStaker object that the node operator stores in their account
        return <-create NodeStaker(id: id, initialStake: initialBalance)    
    } 
}
 zsdd