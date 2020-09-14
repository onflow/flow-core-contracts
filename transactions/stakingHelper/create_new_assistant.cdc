// Create StakingHelper resource and store it in account
// Node operator will call it to create StakingHelper for itself
import FungibleToken from 0xee82856bf20e2aa6
import StakingHelper from 0xSTAKINGHELPERADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// TODO: destructure into basic types and then recreate struct in code
transaction(stakingKey: String, stakingSignature:String, networkingKey:String, networkingSignature: String, networkingAddress: String, awardReceiver: Address ) {
    let node: AuthAccount
    let provider: AuthAccount
    let storagePath: Path
    let linkPath: Path

    prepare(node: AuthAccount, provider: AuthAccount) {
        self.node = node
        self.provider = provider
        self.storagePath = StakingHelper.AssistantStoragePath
        self.linkPath = /private/flowStakingHelperAssistant
    }
     
    execute {

        // Create new account here
        let newAccount = AuthAccount(payer: self.node)

        // Create new Assistant
        let stakingPair = StakingHelper.KeySignaturePair(key: stakingKey, signature: stakingSignature)
        let networkingPair = StakingHelper.KeySignaturePair(key: networkingKey, signature: networkingSignature)
        let awardVaultRef = getAccount(awardReceiver).getCapability(/public/flowTokenReceiver)!

        let assistant <- StakingHelper.createAssistant(stakingPair: stakingPair, networkingPair: networkingPair, networkingAddress: networkingAddress, awardVaultRef: awardVaultRef)

        log("NEW ASSISTANT WAS CREATED");


        // TODO: Refactor around publicly available capability on account and store newAccount address in nodeOperator and custodyProvider

        // Store assistant object in storage and create private capability
        newAccount.save<@StakingHelper.Assistant>(<- assistant, to: self.storagePath)
        
        // TODO: NodeOperator shall get restricted capability
        
        let message = "hello, world"
        newAccount.save<String>(message, to: /storage/helloMessage);
        let messageLink = newAccount.link<&String>(/public/helloMessage, target: /storage/helloMessage)

        self.node.save<Capability>(messageLink, to: /storage/helloMessage);
        log(self.node.copy<Capability>(from: /storage/helloMessage)!.borrow<String>()!);

        // let assistantLink = newAccount.link<&StakingHelper.Assistant>(self.linkPath, target: self.storagePath)
        // let nodeCapability = newAccount.link<&StakingHelper.Assistant>(self.linkPath, target: self.storagePath)
        // let providerCapability = newAccount.link<&StakingHelper.Assistant>(self.linkPath, target: self.storagePath)
        
        // self.node.save(assistantLink, to: self.storagePath)
        // self.provider.save(assistantLink, to: self.storagePath)

        //self.node.link<&StakingHelper.NodeAssistant>(self.linkPath, target: self.storagePath)
        // self.node.link<&Capability>(self.linkPath, target: self.storagePath)
        // self.provider.link<&Capability>(self.linkPath, target: self.storagePath)
        
        // log(self.node.copy<Capability>(from: self.storagePath)!.borrow<@StakingHelper.Assistant>());
        
        // let ref = self.node.borrow<&StakingHelper.Assistant>(from: self.storagePath)!

        /*  
        let ref = self.node
            .load<Capability>(from: self.storagePath)!
            .borrow<&StakingHelper.Assistant>()
        */
        // log(ref)
    }

    /*  
    post {
        self.node.copy<Capability>(from: self.storagePath)
            //.getCapability(self.linkPath)!
            .check<&StakingHelper.Assistant>():
            "Node reference to Assistant was not created correctly"

        self.provider
            .getCapability(self.linkPath)!
            .check<&StakingHelper.Assistant>():
            "Provider reference to Assistant was not created correctly"
    }
     */
}