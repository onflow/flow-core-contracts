import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0xe03daebed8ca0615

// Use service account to mint tokens

pub contract FlowStakingHelper {

    // Event that is emitted when tokens are deposited to the escrow vault
    pub event TokensDeposited(amount: UFix64)
    
    // Event that is emitted when tokens are successfully staked
    pub event StakeAccepted(amount: UFix64)

    // Publicly available path
    pub let HelperStoragePath: Path

    pub resource interface NodeHelper {
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        pub let escrowVault: @FungibleToken.Vault
        
        // Function to abort creation of node record and return tokens back
        pub fun abort(){
            pre{
                self.nodeStaker == nil: "NodeRecord was already initialized"
            }
        }

        // Return tokens from escrow back to custody provider
        pub fun withdrawEscrow(amount: UFix64) {   
            pre {
                amount <= self.escrowVault.balance:
                     "Amount is bigger than escrow"
            }
        }

        // Submit staking request to staking contract
        // Should be called ONCE to init the record in staking contract and get NodeRecord
        pub fun submit(id: String, role: UInt8 ) {   
            pre{
                // check that entry already exists? 
                self.nodeStaker == nil: "NodeRecord already initialized"
                id.length > 0: "id field can't be empty"
            }
        }

        // Request to unstake portion of staked tokens
        pub fun unstake(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
        }

        // Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }
        }
            
    }

    pub resource StakingHelper: NodeHelper {
        // TODO: do we need to restrict access to keys arguments? 
        // Staking parameters
        pub let stakingKey: String

        // Networking parameters
        pub let networkingKey: String
        pub let networkingAddress: String

        // FlowToken Vault to hold escrow tokens
        pub let escrowVault: @FungibleToken.Vault

        // Receiver Capability for account, where rewards are paid
        pub let stakerAwardVaultCapability: Capability
        pub let nodeAwardVaultCapability: Capability

        // Portion of reward that goes to node operator
        pub let cutPercentage: UFix64

        // Optional to store NodeStaker object from staking contract
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        
        init(stakingKey: String, networkingKey: String, networkingAddress: String, stakerAwardVaultCapability: Capability, nodeAwardVaultCapability: Capability, cutPercentage: UFix64){
            pre {
                networkingAddress.length > 0 : "The networkingAddress cannot be empty"
            }

            self.stakingKey = stakingKey
            self.networkingKey = networkingKey
            self.networkingAddress = networkingAddress
            self.stakerAwardVaultCapability = stakerAwardVaultCapability
            self.nodeAwardVaultCapability = nodeAwardVaultCapability
            self.cutPercentage = cutPercentage

            // init resource with empty node record
            self.nodeStaker <- nil

            // initiate empty FungibleToken Vault to store escrowed tokens
            self.escrowVault <- FlowToken.createEmptyVault()        
        }

        destroy() {
            self.withdrawEscrow(amount: self.escrowVault.balance)
                        
            destroy self.escrowVault
            destroy self.nodeStaker
        }
        
        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    depositEscrow
        // Access:  Custody Provider
        // Action:  Deposit tokens to escrow Vault   
        //
        pub fun depositEscrow(vault: @FungibleToken.Vault) {
            let amount = vault.balance 
            self.escrowVault.deposit(from: <- vault)

            emit TokensDeposited(amount: amount)
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdawEscrow
        // Access:  Custody Provider
        // Action:  Returns tokens from escrow back to custody provider
        //
        pub fun withdrawEscrow(amount: UFix64) {
            // We will create temporary Vault in order to preserve one living in StakingHelper
            let tempVault <- self.escrowVault.withdraw(amount: amount)
            
            self.stakerAwardVaultCapability.borrow<&{FungibleToken.Receiver}>()!.deposit(from: <- tempVault)
        }
        
        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    submit
        // Access:  Node Operator
        // Action:  Submits staking request to staking contract
        //
        pub fun submit(id: String, role: UInt8 ) {
            let stakingKey = self.stakingKey 
            let networkingKey = self.networkingKey 
            let networkingAddress = self.networkingAddress
            let cutPercentage = self.cutPercentage
            let tokensCommitted <- self.escrowVault.withdraw(amount: self.escrowVault.balance)
             
            self.nodeStaker <-! FlowIDTableStaking.addNodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <- tokensCommitted, cutPercentage: cutPercentage )            
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    abort
        // Access:  Custody Provider, Node Operator
        // Action:  Abort initialization and return tokens back to custody provider
        //
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

        
        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    abort
        // Access:  Custody Provider, Node Operator
        // Action:  Add more tokens to the stake
        //
        pub fun stakeNewTokens(amount: UFix64) {
            let tokens <- self.escrowVault.withdraw(amount: amount)

            if (self.nodeStaker != nil) {
                self.nodeStaker?.stakeNewTokens(<- tokens)
            } else {
                self.escrowVault.deposit(from: <- tokens)
            }
        }


        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    stake
        // Access:  Custody Provider, Node Operator
        // Action: Function to request to stake certain amount of tokens
        pub fun stakeUnlockedTokens(amount: UFix64) {
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            self.nodeStaker?.stakeUnlockedTokens(amount: amount)    
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    unstake
        // Access:  Custody Provider, Node Operator
        // Action: Function to request to unstake portion of staked tokens
        // 
        pub fun unstake(amount: UFix64) {
            self.nodeStaker?.requestUnStaking(amount: amount)
        }

         
        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdrawTokens
        // Access:  Custody Provider
        //
        // Action: Return unlocked tokens from staking contract
        pub fun withdrawTokens(amount: UFix64){
            if let vault <- self.nodeStaker?.withdrawUnlockedTokens(amount: amount) {
                // TODO: send them backto the staker and not escrow vault
                self.escrowVault.deposit(from: <- vault)
            } else {
                // TODO: Emit event that withdraw failed 
            }
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    withdrawReward
        // Access:  Custody Provider, Node Operator
        //
        // Action: Withdraw rewards from staking contract
        pub fun withdrawReward(amount: UFix64){
            pre{
                self.nodeStaker != nil: "NodeRecord was not initialized"    
            }

            let nodeVaultRef = self.nodeAwardVaultCapability.borrow<&FungibleToken.Vault>()
            let stakerVaultRef = self.stakerAwardVaultCapability.borrow<&FungibleToken.Vault>()

            if let rewardVault <- self.nodeStaker?.withdrawRewardedTokens(amount: amount){
                let nodeAmount = rewardVault.balance * self.cutPercentage

                let nodePart <- rewardVault.withdraw(amount: nodeAmount)
                nodeVaultRef!.deposit(from: <- nodePart)
                stakerVaultRef!.deposit(from: <- rewardVault)
            }
        }

        // ---------------------------------------------------------------------------------
        // Type:    METHOD
        // Name:    stakeRewards
        // Access:  Custody Provider, Node Operator
        //
        // Action: Stake rewards stored inside of staking contract without returning them to involved parties
        pub fun stakeRewards(amount: UFix64){
            self.nodeStaker?.stakeRewardedTokens(amount: amount)
        }
    }

    // ---------------------------------------------------------------------------------
    // Type:    METHOD
    // Name:    createHelper
    // Access:  Public
    //
    // Action: create new StakingHelper object with specified parameters
    pub fun createHelper(stakingKey: String, networkingKey: String, networkingAddress: String, stakerAwardVaultCapability: Capability, nodeAwardVaultCapability: Capability, cutPercentage: UFix64): @StakingHelper {
        return <- create StakingHelper(stakingKey: stakingKey, networkingKey: networkingKey, networkingAddress: networkingAddress, stakerAwardVaultCapability: stakerAwardVaultCapability, nodeAwardVaultCapability: nodeAwardVaultCapability, cutPercentage: cutPercentage)
    }

    init(){
        self.HelperStoragePath = /storage/flowStakingHelper
    }
}
 
