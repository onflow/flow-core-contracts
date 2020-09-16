import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub contract StakingHelper {
    
    pub event EscrowDeposited(amount: UFix64)
    pub event StakeAccepted(nodeID: String, amount: UFix64)

    pub let AssistantStoragePath: Path

    pub resource interface NodeAssistant {
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        pub let escrowVault: @FungibleToken.Vault
        
        /// Function to abort creation of node record and return tokens back
        pub fun abort(){
            pre{
                self.nodeStaker == nil: "NodeRecord was already initialized"
            }
        }

        /// Return tokens from escrow back to custody provider
        pub fun withdrawEscrow(amount: UFix64) {   
            pre {
                amount <= self.escrowVault.balance:
                     "Amount is bigger than escrow"
            }
        }

        /// Submit staking request to staking contract
        /// Should be called ONCE to init the record in staking contract and get NodeRecord
        pub fun submit(id: String, role: UInt8 ) {   
            pre{
                // check that entry already exists? 
                self.nodeStaker == nil: "NodeRecord already initialized"
                id.length > 0: "id field can't be empty"
            }
        }

        /// Request to unstake portion of staked tokens
        pub fun unstake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
        }

        /// Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
        }
            
    }

    pub resource Assistant: NodeAssistant {
        /// Staking parameters
        pub let stakingKey: String

        /// Networking parameters
        pub let networkingKey: String
        pub let networkingAddress: String

        /// FlowToken Vault to hold escrow tokens
        pub let escrowVault: @FungibleToken.Vault

        /// Receiver Capability for account, where rewards are paid
        pub let operatorAwardVault: Capability

        pub let nodeAwardVault: Capability

        /// Optional to store NodeStaker object from staking contract
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        
        init(stakingKey: String, networkingKey: String, networkingAddress: String, awardVaultRef: Capability){
            pre {
                networkingAddress.length > 0 : "The networkingAddress cannot be empty"
            }

            self.stakingKey = stakingKey
            self.networkingKey = networkingKey
            self.networkingAddress = networkingAddress
            self.awardVaultRef = awardVaultRef
            self.nodeStaker <- nil

            // Initiaate empty FungibleToken Vault to store escrowed tokens
            self.escrowVault <- FlowToken.createEmptyVault()        
        }

        destroy() {
            // TODO: deposit into owner vault
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
            // We will create temporary Vault in order to preserve one living in Assistant
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
        pub fun submit(id: String, role: UInt8 ) {
            let stakingKey = self.stakingKey 
            let networkingKey = self.networkingKey 
            let networkingAddress = self.networkingAddress 
            
            let tokensCommitted <- self.escrowVault.withdraw(amount: self.escrowVault.balance)
             
            // TODO: Admin capability should be of restricted type
            self.nodeStaker <-! FlowIDTableStaking.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <- tokensCommitted )            
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
            self.nodeStaker?.requestUnStaking(amount: amount)
        }

         
        /// ---------------------------------------------------------------------------------
        /// Type:    METHOD
        /// Name:    withdrawTokens
        /// Access:  Custody Provider, Node Operator
        ///
        /// Action: Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64){
            if let vault <- self.nodeStaker?.withdrawUnlockedTokens(amount: amount) {
                self.escrowVault.deposit(from: <- vault)
            } else {
                // TODO: Emit event that withdraw failed 
            }
        }
    }

    /// ---------------------------------------------------------------------------------
    /// Type:    METHOD
    /// Name:    createAssistant
    /// Access:  Public
    ///
    /// Action: create new Assistant object with specified parameters
    pub fun createAssistant(stakingKey: String, networkingKey: String, networkingAddress: String, awardVaultRef: Capability): @Assistant {
        return <- create Assistant(stakingKey: stakingKey, networkingKey: networkingKey, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
    }
}