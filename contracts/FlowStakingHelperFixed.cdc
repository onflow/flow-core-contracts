import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub contract StakingHelper {
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
        pub let escrowVault: @FlowToken.Vault

        // Receiver Capability for account, where rewards are paid
        pub let awardVaultRef: Capability<&FungibleToken.Receiver>

        // Optional to store NodeStaker object from staking contract
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?
        
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
    }

    pub fun createAssistant(stakingPair: KeySignaturePair, networkingPair: KeySignaturePair, networkingAddress: String, awardVaultRef: Capability<&FungibleToken.Receiver>): @Assistant {
        return <- create Assistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)
    }

    init(){
        self.AssistantStoragePath = /storage/flowStakingAssistant
    }
}