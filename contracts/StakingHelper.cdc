// import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0x179b6b1cb6755e


// Questions
// - What is the process of deploying this contract to test
// - Who will own StakingHelper resource
// - so we are going to treat 

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

    pub resource interface TokenReceiver {

    }

    pub resource Assistant: TokenReceiver {
        // Staking "side" parameters
        pub let stakingPair: KeySignaturePair

        // Networking parameters
        pub let networkingPair: KeySignaturePair
        pub let networkingAddress: String

        // FlowToken Vault to hold escrowed staking tokens
        pub let escrowVault: @FlowToken.Vault

        // Receiver Capability for account, where rewards are paid
        pub let awardVaultRef: Capability<&FungibleToken.Receiver>

        init(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&FungibleToken.Receiver>){
            pre{
                networkingAddress.length > 0: "The networkingAddress cannot be empty"
                // TODO: 
                // - Check that receiver exists
            }

            // TODO: more checks here

            // All checks passed - assign values
            self.stakingPair = stakingPair
            self.networkingPair = networkingPair
            self.networkingAddress = networkingAddress
            self.awardVaultRef = awardVaultRef

            // Create FlowToken vault to escrow tokens
            self.escrowVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
        }

        // Function to submit stake
        pub fun submit(){

        }

        pub fun transfer(vault: @FlowToken.Vault) {
            self.escrowVault.deposit(from: <- vault)
        }

        // Function to unbond stake
        pub fun unbond(amount: UFix64) {
            pre{
                // TODO:
                // Check that staked amount is bigger than amount
            }

            // TODO:
            // Request to unstake "amount" of tokens
        }

        // Function to withdraw rewards/unbound tokens from central staking contract
        pub fun widthdraw(amount: UFix64){

        }

        pub fun createAssistant( /* pass all the params here  */ ){
            // get node here
        }


        destroy (){
            // TODO: Decide what to do with escrowVault
            destroy self.escrowVault
        }
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
        
        // TODO: Additional logic on contract deployment
    }
}