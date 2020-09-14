import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub contract StakingHelper {
    
    pub event EscrowDeposited(amount: UFix64)
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

    pub resource Assistant {
        // Staking parameters
        pub let stakingPair: KeySignaturePair

        // Networking parameters
        pub let networkingPair: KeySignaturePair
        pub let networkingAddress: String

        // FlowToken Vault to hold escrow tokens
        pub let escrowVault: @FungibleToken.Vault

        // Receiver Capability for account, where rewards are paid
        pub let awardVaultRef: Capability

        // Optional to store NodeStaker object from staking contract
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        
        init(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability){
            pre {
                networkingAddress.length > 0 : "The networkingAddress cannot be empty"
            }

            self.stakingPair = stakingPair
            self.networkingPair = networkingPair
            self.networkingAddress = networkingAddress
            self.awardVaultRef = awardVaultRef
            self.nodeStaker <- nil

            // TODO: Check that proper type of Vault is created
            self.escrowVault <- FlowToken.createEmptyVault()
        
        }

        destroy() {
            // Decide what to do with  resources
            destroy self.escrowVault
            destroy self.nodeStaker
        }
        
        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    depositEscrow
        /// Access:  Custody Provider
        /// Action:  Deposit tokens to escrow Vault   
        ///
        pub fun depositEscrow(vault: @FlowToken.Vault) {
            self.escrowVault.deposit(from: <- vault)
            // TODO: Shall we emit custom event here? 
        }


        
        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    withdawEscrow
        /// Access:  Custody Provider
        /// Action:  Returns tokens from escrow back to custody provider
        ///
        pub fun withdrawEscrow(amount: UFix64) {
            
            pre {
                amount <= self.escrowVault.balance:
                     "Amount is bigger than escrow"
            }
            

            // We will create temvporary Vault in order to preserve one living in Assistant
            let tempVault <- self.escrowVault.withdraw(amount: self.escrowVault.balance)
            
            self.awardVaultRef.borrow<&{FungibleToken.Receiver}>()!
                .deposit(from: <- tempVault);            
            
        }
        
        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    submit
        /// Access:  Node Operator
        /// Action:  Submits staking request to staking contract
        ///
        // TODO: How are we gonna get adminCapability
        pub fun submit(id: String, role: UInt8, adminCapability: Capability<&FlowIDTableStaking.Admin> ) {
             
            pre{
                // check that entry already exists? 
                self.nodeStaker == nil: "NodeRecord already initialized"
                id.length > 0: "id field can't be empty"
            }

            let stakingKey = self.stakingPair.key 
            let networkingKey = self.networkingPair.key 
            let networkingAddress = self.networkingAddress 
            
            let tempVault <- self.escrowVault.withdraw(amount: self.escrowVault.balance)
            let tokensCommitted <- tempVault
             
            // TODO: Admin capability should be of restricted type
            let adminRef = adminCapability.borrow()!
            self.nodeStaker <-! adminRef.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <- tokensCommitted )
            
            // TODO: Shall we check if escrowVault is empty before calling 
        }

        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    abort
        /// Access:  Custody Provider, Node Operator
        /// Action:  Abort initialization and return tokens back to custody provider
        ///
        pub fun abort() {
            self.withdrawEscrow(amount: self.escrowVault.balance)
            
            // TODO: post condition throwing error here...
            /* 
            post {
                // Check that escrowVault is empty
                self.escrowVault.balance == 0: "Escrow Vault is not empty"
            }
            */            
        }

        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    stake
        /// Access:  Custody Provider, Node Operator
        /// Action: Function to request to stake certain amount of tokens
        pub fun stake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            self.nodeStaker?.stakeUnlockedTokens(amount: amount)    
        }

        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    unstake
        /// Access:  Custody Provider, Node Operator
        /// Action: Function to request to unstake portion of staked tokens
        /// 
        pub fun unstake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            self.nodeStaker?.requestUnStaking(amount: amount)
        }

         
        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    withdrawTokens
        /// Access:  Custody Provider, Node Operator
        ///
        /// Action: Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64){
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
            
            if let vault <- self.nodeStaker?.withdrawUnlockedTokens(amount: amount) {
                self.escrowVault.deposit(from: <- vault)
            } else {
                // TODO: Emit event that withdraw failed 
            }
        }
    }

    pub fun createAssistant(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&AnyResource{FungibleToken.Receiver}>): @Assistant {
        return <- create Assistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
    }
}