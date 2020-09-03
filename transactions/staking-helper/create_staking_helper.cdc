// Create StakingHelper resource and store it in account
// Node operator will call it to create StakingHelper for itself
import FungibleToken from 0x179b6b1cb6755e
import StakingHelper from 0xSTAKING_HELPER_ADDRESS

transaction(stakingPair: StakingHelper.KeySignaturePair, networkingPair: StakingHelper.KeySignaturePair, networkingAddress: String, awardReciever: Address ) {
    let operator: AuthAccount
    let path: Path
    let refPath: Path
    let awardVaultRef: Path

    prepare(acct: AuthAccount) {
        self.operator = acct

        self.path = StakingHelper.AssistantStoragePath
        self.refPath = /private/flowStakingHelperAssistant
        self.receiverVaultPath = /public/flowToken // TODO: Clarify what is the default path where FlowTokens are stored
        
        // Get capability from awardReciever account
        self.awardVaultRef = getAccount(awardReciever).getCapability(receiverVaultPath)

        // - create new StakingHelper resources - shall we take params from existing Node resource?
    }

    execute {
        // TODO:  shall we do creation of assets and storing them here?
                // Create new Assistant
        let assistant <- StakingHelper.createAssistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)

        // Store assistant object in storage and create private capability
        self.operator.save<@StakingHelper.Assistant>(<- assistant, to: self.path)
        self.operator.link<&StakingHelper.Assistant>(self.refPath, target: self.path)
    }

    post {
        getAccount(self.operator)
            .getCapability(self.refPath)!
            .check<&StakingHelper.Assistant>():
            "Assistant reference was not created correctly"
    }
}