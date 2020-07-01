import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import FlowRewards from 0xREWARDSADDRESS

// For limiting access to the OperatorAccess object
// Give a capability that is cast as OperatorNoUnstake
// to not allow the holder of the capability 
// to withdraw staked tokens

pub contract RewardsUtils {

    pub resource interface OperatorNoUnstake {
        // Add a delegator to this operator object to receive token rewards
        pub fun addDelegator(delegator: Capability) 

        // directly add tokens to the tokens that are staked
        pub fun stakeTokens(from: @FungibleToken.Vault) 

        // Generic deposit function to deposit the rewards for this operator
        // Forwards the deposited tokens to the delegator
        pub fun deposit(from: @FungibleToken.Vault) 
    }

    pub resource OperatorNoUnstake {
        pub var operatorAccess: @FlowRewards.OperatorAccess

        // Add a delegator to this operator object to receive token rewards
        pub fun addDelegator(delegator: Capability) {
            self.operatorAccess.addDelegator(delegator: delegator)
        }

        // directly add tokens to the tokens that are staked
        pub fun stakeTokens(from: @FungibleToken.Vault) {
            self.operatorAccess.stakeTokens(from: from)
        }

        // directly unstake tokens for this operator
        pub fun unstakeTokens(amount: UFix64): @FungibleToken.Vault {
            return <- self.operatorAccess.unstakeTokens(amount: amount)
        }

        // Generic deposit function to deposit the rewards for this operator
        // Forwards the deposited tokens to the delegator
        pub fun deposit(from: @FungibleToken.Vault) {
            self.operatorAccess.deposit(from: <-from)
        }
    }
}