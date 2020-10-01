import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0x179b6b1cb6755e31

pub contract Lockbox {

    // 1. Admin: Dapper Labs only
    // 2. Shared: Dapper Labs + Token Holder
    // 3. Holder: Token Holder only

    /// path to store the locked token manager resource 
    /// in the shared account
    pub let LockedTokenManagerPath: Path

    /// path to store the private locked token admin link
    /// in the shared account
    pub let LockedTokenAdminPrivatePath: Path

    /// path to store the admin collection 
    /// in the admin account
    pub let LockedTokenAdminCollectionPath: Path

    /// path to store the token holder resource
    /// in the unlocked account
    pub let TokenHolderStoragePath: Path

    /// path to store the node operator struct
    /// in the node operators account for staking helper
    pub let NodeOperatorCapabilityStoragePath: Path

    /// stored in Admin account
    pub resource interface TokenAdmin {
        pub fun increaseUnlockLimit(delta: UFix64)
    }

    /// stored in the shared account 
    pub resource LockedTokenManager: FungibleToken.Receiver, FungibleToken.Provider, TokenAdmin {
    
        pub var vault: Capability<&FlowToken.Vault>

        pub var nodeStaker: @FlowIDTableStaking.NodeStaker?

        pub var nodeDelegator: @FlowIDTableStaking.NodeDelegator?

        pub var unlockLimit: UFix64

        init(vault: Capability<&FungibleToken.Vault>) {
            self.vault = vault
            self.nodeStaker = nil
            self.nodeDelegator = nil
            self.unlockLimit = 0.0
        }

        // FungibleToken.Receiver actions

        pub fun deposit(from: @FungibleToken.Vault) {
            let balance = from.balance

            self.vault.deposit(from: <- from)

            self.increaseUnlockLimit(delta: balance)
        }

        // FungibleToken.Provider actions

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.unlockLimit >= amount: "Requested amount exceeds unlocked token limit"
            }

            post {
                self.unlockLimit == before(self.unlockLimit) - amount: "Updated unlocked token limit is incorrect"
            }

            let vault <- self.vault.withdraw(amount: amount)

            self.decreaseUnlockLimit(delta: amount)

            return <- vault
        }

        access(self) fun decreaseUnlockLimit(delta: UFix64) {  
            self.unlockLimit = self.unlockLimit - delta
        }

        // Lockbox.TokenAdmin actions

        pub fun increaseUnlockLimit(delta: UFix64) {  
            self.unlockLimit = self.unlockLimit + delta
        }

        // Lockbox.TokenHolder actions

        pub fun registerNode(id: String, role: UInt8, networkingAddr: String, networkingKey: String, stakingKey: String) {
            self.nodeStaker <- FlowIDTableStaking.addNodeRecord(self.nodeInfo)
        }

        pub fun registerDelegator(nodeID: String) {
            self.nodeDelegator <- FlowIDTableStaking.registerDelegator(nodeID: nodeID)
        }

        pub fun createTokenHolder(tokenManager: Capability<&LockedTokenManager>): @TokenHolder {
            return <- create TokenHolder(tokenManager: tokenManager)
        }
    }

    // stored in Holder unlocked account
    pub resource TokenHolder {

        access(self) var tokenManager: Capability<&LockedTokenManager>

        access(self) var nodeStakerProxy: LockedNodeStakerProxy?

        access(self) var nodeDelegatorProxy: LockedNodeDelegatorProxy?

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid capability"
            }
            self.tokenManager = tokenManager
            self.nodeStakerProxy = nil
            self.nodeDelegatorProxy = nil
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-from)
        }

        // FungibleToken.Provider actions

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            let tokenManagerRef = self.tokenManager.borrow()!

            return <- tokenManagerRef.withdraw(amount: amount)
        }

        pub fun createNodeStaker(id: String, role: UInt8, networkingAddr: String, networkingKey: String, stakingKey: String) {
            pre {
                self.nodeStakerProxy == nil && self.nodeDelegatorProxy == nil: "Already initialized"
            }

            let tokenManagerRef = self.tokenManager.borrow()!

            // register node
            tokenManagerRef.registerNode(id: id, role: role, networkingAddr: networkingAddr, networkingKey: networkingKey, stakingKey: stakingKey)

            self.nodeStakerProxy = LockedNodeStakerProxy(tokenManager: self.tokenManager)
        }

        pub fun createNodeDelagtor(nodeID: String) {
            pre {
                self.nodeStakerProxy == nil && self.nodeDelegatorProxy == nil: "Already initialized"
            }

            let tokenManagerRef = self.tokenManager.borrow()!

            // register delegator
            tokenManagerRef.registerDelegator(nodeID: nodeID)

            self.nodeDelegatorProxy = LockedNodeDelegatorProxy(tokenManager: self.tokenManager)
        }

        pub fun borrowStaker(): LockedNodeStakerProxy {
            return self.nodeStakerProxy!
        }

        pub fun borrowDelegator(): LockedNodeDelegatorProxy {
            return self.nodeDelegatorProxy!
        }
    }

    pub struct LockedNodeStakerProxy: StakingProxy.NodeStakerProxy {

        access(self) var tokenManager: Capability<&LockedTokenManager>

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid capability"
            }
            self.tokenManager = tokenManager
        }

        pub fun stakeNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.nodeStaker?.stakeNewTokens(from: <-vaultRef.withdraw(amount: amount))
        }

        pub fun stakeUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.stakeUnlockedTokens(amount: amount)
        }

        // TODO: only callable by token holder
        pub fun stakeRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.stakeRewardedTokens(amount:amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        pub fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.requestUnStaking(amount: amount)
        }

        pub fun unstakeAll(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeStaker?.unstakeAll()
        }

        pub fun withdrawUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            let withdrawnTokens <- tokenManagerRef.nodeStaker?.withdrawUnlockedTokens(amount: amount)!

            vaultRef.deposit(from: <-withdrawnTokens)
        }

        pub fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-tokenManagerRef.nodeStaker?.withdrawRewardedTokens(amount: amount))
        }
    }

    pub struct LockedNodeDelegatorProxy: StakingProxy.NodeDelegatorProxy {

        access(self) var tokenManager: Capability<&LockedTokenManager>

        init(tokenManager: Capability<&LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid capability"
            }
            self.tokenManager = tokenManager
        }

        pub fun delegateNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.nodeDelegator?.delegatorNewTokens(from: <-vaultRef.withdraw(amount: amount))
        }

        pub fun delegateUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.delegateUnlockedTokens(amount: amount)
        }

        pub fun delegateRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.delegateRewardedTokens(amount: amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        pub fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.nodeDelegator?.requestUnStaking(amount: amount)
        }

        pub fun withdrawUnlockedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            let vaultRef = tokenManagerRef.vault.borrow()!

            vaultRef.deposit(from: <-tokenManagerRef.nodeDelegator?.withdrawUnlockedTokens(amount: amount))
        }

        pub fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            tokenManagerRef.deposit(from: <-tokenManagerRef.nodeDelegator?.withdrawRewardedTokens(amount: amount))
        }
    }


    pub resource TokenAdminCollection {
        access(self) var accounts: {Address: Capability<&LockedTokenManager{TokenAdmin}>}

        init() {
            self.accounts = {}
        }

        pub fun addAccount(
            address: Address, 
            tokenAdmin: Capability<&LockedTokenManager{TokenAdmin}>,
        ) {
            self.accounts[address] = tokenAdmin
        }

        pub fun getAccount(address: Address): Capability<&LockedTokenManager{TokenAdmin}> {
            return self.accounts[address]!
        }
    }

    pub fun createTokenAdminCollection(): @TokenAdminCollection {
        return <- create TokenAdminCollection()
    }

    pub fun createNewLockedTokenManager(vault: Capability<&FlowToken.Vault>): @LockedTokenManager {
        return <- create LockedTokenManager(vault: vault)
    }

    init() {
        self.LockedTokenManagerPath = /storage/lockedTokenManager

        self.LockedTokenAdminPrivatePath = /private/lockedTokenAdmin
        self.LockedTokenAdminCollectionPath = /storage/lockedTokenAdminCollection

        self.TokenHolderStoragePath = /storage/flowTokenHolder

        self.NodeOperatorCapabilityStoragePath = /storage/nodeOperator
    }
}