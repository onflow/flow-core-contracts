// Q: Shall we store the address, which sends tokens to escrow Vault
// A: Same as award reciever

// Q: Is it OK if we use structs in arguments to make it more readable
// A: recreate in transaction

import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0x179b6b1cb6755e

pub contract StakingHelper {

    // pub event EscrowDeposited(amount: UFix64)
    // pub event StakeAccepted(nodeID: String, amount: UFix64)

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

        pub fun abort(){
            pre {
                self.nodeStaker == nil: "NodeRecord was already initialized"
            }
        }

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


        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    depositEscrow
        // Access:  Custody Provider
        // Action:  Deposit tokens to escrow Vault   
        //
        pub fun depositEscrow(vault: @FlowToken.Vault) {
            self.escrowVault.deposit(from: <- vault)
            // TODO: Shall we emit custom event here? 
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdawEscrow
        // Access:  Custody Provider
        // Action:  Returns tokens from escrow back to custody provider
        //
        pub fun withdrawEscrow(amount: UFix64) {
            pre {
                amount <= self.escrowVault.balance: "Amount is bigger than escrow"
            }

            // We will create temporary Vault in order to preserve one living in Assistant
            let tempVault <- escrowVault.withdraw(amount: escrowVault.balance)
            awardVaultRef.deposit(from: <- tempVault)

            post {
                self.escrowVault >= 0: "Amount can't be negatuve"
            }
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    submit
        // Access:  Custody Provider, Node Operator
        // Action:  Submits staking request to staking contract
        //
        pub fun submit(id: String, role: UInt8) {
            pre{
                // check that entry already exists? 
                self.nodeStaker == nil: "NodeRecord already initialized"
                id.length > 0: "id field can't be empty"
            }

            let stakingKey = self.stakingPair.key 
            let networkingKey = self.networkingPair.key 
            let networkingAddress =  self.networkingAddress 
            let tokensCommitted <- self.escrowVault

            self.nodeStaker <- FlowIDTableStaking.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: tokensCommitted )

            // TODO: Shall we check if escrowVault is empty before calling 
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdawEscrow
        // Access:  Custody Provider, Node Operator
        // Action:  Abort initialization and return tokens back to custody provider
        //
        pub fun abort() {

            self.withdrawEscrow(amount: escrowVault.balance)

            post{
                // Check that escrowVault is empty
                escrowVault.balance == 0: "Escrow Vault is not empty"
            }
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    stake
        // Access:  Custody Provider, Node Operator
        // Action: Function to request to stake all tokens
        pub fun stake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            self.nodeStaker.stakeUnlockedTokens(amount: amount)    
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    unstake
        // Access:  Custody Provider, Node Operator
        // Action: Function to request to unstake portion of staked tokens
        // 
        pub fun unstake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            self.nodeStaker.requestUnStaking(amount: amount)
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdrawTokens
        // Access:  Custody Provider, Node Operator
        //
        // Action: Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64){
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
            
            let vault <- self.nodeStaker.withdrawUnlockedTokens(amount: amount)
            self.escrowVault.deposit(from: <- vault)
        }
    }

    // Public method, which will allow node operators to create new Assistant resource
    pub fun createAssistant(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&FungibleToken.Receiver>): @Assistant {
        return <- create Assistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
    }
}
