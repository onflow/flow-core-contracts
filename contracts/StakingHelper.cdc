// Q: Shall we store the address, which sends tokens to escrow Vault
// A: Same as award reciever

// Q: Is it OK if we use structs in arguments to make it more readable
// A: recreate in transaction

import FlowIDTableStaking from 0xFLOWTABLESTAKING
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0x179b6b1cb6755e

pub contract StakingHelper {

    pub event StakeAccepted(nodeID: String, amount: UFix64)
    pub let AssistantStoragePath: Path

    pub struct KeySignaturePair {
        pub let key: String
        pub let signature: String

        init (key: String, signature: String){
            self.key = key
            self.signature = signature
        }
    }

    pub resource interface NodeAssistant {

        // return tokens from escrow back to custody provider
        pub fun withdrawEscrow(amount: UFix64) {

        }

        // Function to submit staking request to staking contract
        // (probably) should be called ONCE to init the record in staking contract and get NodeRecord
        pub fun submit() {

        }

        // Function to request to unstake portion of staked tokens
        pub fun unstake(amount: UFix64) {

        }

        // Function to return unlocked tokens from staking contract
        pub fun withdrawStake(amount: UFix64){

        }
    }

    pub resource Assistant: NodeAssistant {
        // Staking parameters
        pub let stakingPair: KeySignaturePair

        // Networking parameters
        pub let networkingPair: KeySignaturePair
        pub let networkingAddress: String

        // FlowToken Vault to hold escrow tokens
        pub let escrowVault: @FlowToken.Vault

        // Receiver Capability for account, where rewards are paid
        pub let awardVaultRef: Capability<&FungibleToken.Receiver>

        // Optional to store NodeStaker object from staking contract
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?

        // Core methods to create and destroy instance of Assistant resource
        init(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&FungibleToken.Receiver>){
            pre {
                networkingAddress.length > 0 : "The networkingAddress cannot be empty"
            }

            self.stakingPair = stakingPair
            self.networkingPair = networkingPair
            self.networkingAddress = networkingAddress
            self.awardVaultRef = awardVaultRef
            self.nodeStaker <- nil
        }

        destroy() {
            // Decide what to do with  resources
            destroy self.escrowVault
            destroy self.nodeStaker
        }

        pub fun depositEscrow(vault: @FlowToken.Vault) {
            self.escrowVault.deposit(from: <- vault)
        }

        // return tokens from escrow back to custody provider
        pub fun withdrawEscrow(amount: UFix64) {
            // Q: Shall we accept argument with account address or capability
            // to know where to return tokens?
        }

        // Function to submit staking request to staking contract
        // (probably) should be called ONCE to init the record in staking contract and get NodeRecord
        pub fun submit() {
            
        }

        // Function to request to unstake portion of staked tokens
        pub fun unstake(amount: UFix64) {

        }

        // Function to return unlocked tokens from staking contract
        pub fun withdrawStake(amount: UFix64){

        }
    }

    pub fun createAssistant(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&FungibleToken.Receiver>): @Assistant {
        return <- create Assistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
    }
}