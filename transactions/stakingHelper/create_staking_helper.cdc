// Create StakingHelper resource and store it in account
// Node operator will call it to create StakingHelper for itself
import FungibleToken from 0x179b6b1cb6755e
import StakingHelper from 0xSTAKING_HELPER_ADDRESS

// TODO: destructure into basic types and then recreate struct in code
transaction(stakingPair: StakingHelper.KeySignaturePair, networkingPair: StakingHelper.KeySignaturePair, networkingAddress: String, awardReciever: Address ) {
    let node: AuthAccount
    let provider: AuthAccount
    let path: Path
    let refPath: Path
    let awardVaultRef: Path

    prepare(node: AuthAccount, provider: AuthAccount) {
        self.operator = node
        self.provider = provider
        self.path = StakingHelper.AssistantStoragePath
        self.refPath = /private/flowStakingHelperAssistant
        self.custodyRefPath = /private/flowStakingHelperAssistant
        
        self.receiverVaultPath = /public/flowTokenReceiver 
        // Get capability from awardReciever account
        self.awardVaultRef = getAccount(awardReciever).getCapability(receiverVaultPath)

        // - create new StakingHelper resources - shall we take params from existing Node resource?
    }

    execute {

        // Create new account here
        let newAccount = AuthAccount(payer: self.node)

        // TODO:  shall we do creation of assets and storing them here?
                // Create new Assistant
        let assistant <- StakingHelper.createAssistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)

        // Store assistant object in storage and create private capability
        newAccount.save<@StakingHelper.Assistant>(<- assistant, to: self.path)
        
        let nodeCapability = newAccount.link<&StakingHelper.Assistant>(self.refPath, target: self.path)
        let providerCapability = newAccount.link<&StakingHelper.Assistant>(self.refPath, target: self.path)
        
        self.node.save<&StakingHelper.Assistant>(nodeCapability, to: self.path)
        self.provider.save<&StakingHelper.Assistant>(nodeCapability, to: self.path)

        // self.node.link<&StakingHelper.Assistant>(self.refPath, target: self.path)
        // self.provider.link<&StakingHelper.NodeAssistant>(self.custodyRefPath, target: self.path)
    }

    post {
        getAccount(self.operator)
            .getCapability(self.refPath)!
            .check<&StakingHelper.Assistant>():
            "Assistant reference was not created correctly"
    }
}