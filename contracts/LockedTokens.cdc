/*

    LockedTokens implements the functionality required to manage FLOW
    buyers locked tokens from the token sale.

    Each token holder gets two accounts. One account is their locked token
    account. It will be jointly controlled by the user and the token administrator.
    The token administrator must co-sign the transfer of any locked tokens.
    The token admin cannot interact with the account
    without approval from the token holder,
    except to deposit additional locked FLOW
    or to unlock existing FLOW at each milestone in the token vesting period.

    The second account is the unlocked user account. This account is
    in full possesion and control of the user and they can do whatever
    they want with it. This account will store a capability that allows
    them to withdraw tokens when they become unlocked and also to
    perform staking operations with their locked tokens.

    When a user account is created, both accounts are initialized with
    their respective objects: LockedTokenManager for the shared account,
    and TokenHolder for the unlocked account. The user calls functions
    on TokenHolder to withdraw tokens from the shared account and to
    perform staking actions with the locked tokens

 */

import "FlowToken"
import "FungibleToken"
import "FlowIDTableStaking"
import "FlowStorageFees"
import "StakingProxy"

access(all) contract LockedTokens {

    access(all) event SharedAccountRegistered(address: Address)
    access(all) event UnlockedAccountRegistered(address: Address)

    access(all) event UnlockLimitIncreased(address: Address, increaseAmount: UFix64, newLimit: UFix64)

    access(all) event LockedAccountRegisteredAsNode(address: Address, nodeID: String)
    access(all) event LockedAccountRegisteredAsDelegator(address: Address, nodeID: String)

    access(all) event LockedTokensDeposited(address: Address, amount: UFix64)

    /// Path to store the locked token manager resource
    /// in the shared account
    access(all) let LockedTokenManagerStoragePath: StoragePath

    /// Path to store the private capability for the token
    /// manager
    access(all) let LockedTokenManagerPrivatePath: PrivatePath

    /// Path to store the private locked token admin link
    /// in the shared account
    access(all) let LockedTokenAdminPrivatePath: PrivatePath

    /// Path to store the admin collection
    /// in the admin account
    access(all) let LockedTokenAdminCollectionStoragePath: StoragePath

    /// Path to store the token holder resource
    /// in the unlocked account
    access(all) let TokenHolderStoragePath: StoragePath

    /// Public path to store the capability that allows
    /// reading information about a locked account
    access(all) let LockedAccountInfoPublicPath: PublicPath

    /// Path that an account creator would store
    /// the resource that they use to create locked accounts
    access(all) let LockedAccountCreatorStoragePath: StoragePath

    /// Path that an account creator would publish
    /// their capability for the token admin to
    /// deposit the account creation capability
    access(all) let LockedAccountCreatorPublicPath: PublicPath

    /// The TokenAdmin capability allows the token administrator to unlock tokens at each
    /// milestone in the vesting period.
    access(all) resource interface TokenAdmin {
        access(UnlockTokens) fun increaseUnlockLimit(delta: UFix64)
    }

    /// Entitlement for the token admin to unlock tokens from
    /// the token sale and various grants
    access(all) entitlement UnlockTokens

    /// Entitlement for the token admin to use to recover leased tokens
    /// directly from accounts who have leased tokens to operate nodes
    /// Since there are no existing capabilities with this entitlement,
    /// it is only used when authorizing a transaction that already
    /// has access to the account
    access(all) entitlement RecoverLease

    /// This token manager resource is stored in the shared account to manage access
    /// to the locked token vault and to the staking/delegating resources.
    access(all) resource LockedTokenManager: FungibleToken.Receiver, FungibleToken.Provider, TokenAdmin {

        /// This is a reference to the default FLOW vault stored in the shared account.
        ///
        /// All locked FLOW tokens are stored in this vault, which can be accessed in two ways:
        ///   1) Directly, in a transaction co-signed by both the token holder and token administrator
        ///   2) Indirectly via the LockedTokenManager, in a transaction signed by the token holder
        access(account) var vault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>

        /// The amount of tokens that the user can withdraw.
        /// It is decreased when the user withdraws
        access(all) var unlockLimit: UFix64

        /// Optional NodeStaker resource. Will only be filled if the user
        /// signs up to be a node operator
        access(contract) var nodeStaker: @FlowIDTableStaking.NodeStaker?

        /// Optional NodeDelegator resource. Will only be filled if the user
        /// signs up to be a delegator
        access(contract) var nodeDelegator: @FlowIDTableStaking.NodeDelegator?

        init(vault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>) {
            self.vault = vault
            self.nodeStaker <- nil
            self.nodeDelegator <- nil
            self.unlockLimit = 0.0
        }

        // FungibleToken.Receiver actions
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@FlowToken.Vault>(): true}
        }

        /// Returns whether or not the given type is accepted by the Receiver
        /// A vault that can accept any type should just return true by default
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            if let isSupported = self.getSupportedVaultTypes()[type] { 
                return isSupported 
            } else { return false }
        }

        /// Deposits unlocked tokens to the vault
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self.depositUnlockedTokens(from: <-from)
        }

        access(self) fun depositUnlockedTokens(from: @{FungibleToken.Vault}) {
            let vaultRef = self.vault.borrow()!

            let balance = from.balance

            vaultRef.deposit(from: <- from)

            self.increaseUnlockLimit(delta: balance)
        }

        // FungibleToken.Provider actions

        /// Asks if the amount can be withdrawn from this vault
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            let vaultRef = self.vault.borrow()!
            return amount <= vaultRef.balance && amount <= self.unlockLimit
        }

        /// Withdraws unlocked tokens from the vault
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            return <-self.withdrawUnlockedTokens(amount: amount)
        }

        access(self) fun withdrawUnlockedTokens(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                self.unlockLimit >= amount: "Requested amount exceeds unlocked token limit"
            }

            post {
                self.unlockLimit == before(self.unlockLimit) - amount: "Updated unlocked token limit is incorrect"
            }

            let vaultRef = self.vault.borrow()!

            let vault <- vaultRef.withdraw(amount: amount)

            self.decreaseUnlockLimit(delta: amount)

            return <-vault
        }

        access(all) view fun getBalance(): UFix64 {
            let vaultRef = self.vault.borrow()!
            return vaultRef.balance
        }

        access(self) fun decreaseUnlockLimit(delta: UFix64) {
            self.unlockLimit = self.unlockLimit - delta
        }

        // LockedTokens.TokenAdmin actions

        /// Called by the admin every time a vesting release happens
        access(UnlockTokens) fun increaseUnlockLimit(delta: UFix64) {
            self.unlockLimit = self.unlockLimit + delta
            emit UnlockLimitIncreased(address: self.owner!.address, increaseAmount: delta, newLimit: self.unlockLimit)
        }

        // LockedTokens.TokenHolder actions

        /// Registers a new node operator with the Flow Staking contract
        /// and commits an initial amount of locked tokens to stake
        access(account) fun registerNode(nodeInfo: StakingProxy.NodeInfo,
                                         stakingKeyPoP: String,
                                         amount: UFix64
        ) {
            if let nodeStaker <- self.nodeStaker <- nil {
                let stakingInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

                assert(
                    stakingInfo.tokensStaked + stakingInfo.tokensCommitted + stakingInfo.tokensUnstaking + stakingInfo.tokensUnstaked + stakingInfo.tokensRewarded == 0.0,
                    message: "Cannot register a new node until all tokens from the previous node have been withdrawn"
                )

                destroy nodeStaker
            }

            let vaultRef = self.vault.borrow()!

            let tokens <- vaultRef.withdraw(amount: amount)

            let nodeStaker <- self.nodeStaker <- FlowIDTableStaking.addNodeRecord(id: nodeInfo.id,
                                                    role: nodeInfo.role,
                                                    networkingAddress: nodeInfo.networkingAddress,
                                                    networkingKey: nodeInfo.networkingKey,
                                                    stakingKey: nodeInfo.stakingKey,
                                                    stakingKeyPoP: stakingKeyPoP,
                                                    tokensCommitted: <-tokens)

            destroy nodeStaker

            emit LockedAccountRegisteredAsNode(address: self.owner!.address, nodeID: nodeInfo.id)
        }

        /// Registers a new Delegator with the Flow Staking contract
        /// the caller has to specify the ID of the node operator
        /// they are delegating to
        access(account) fun registerDelegator(nodeID: String, amount: UFix64) {
            if let delegator <- self.nodeDelegator <- nil {
                let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)

                assert(
                    delegatorInfo.tokensStaked + delegatorInfo.tokensCommitted + delegatorInfo.tokensUnstaking + delegatorInfo.tokensUnstaked + delegatorInfo.tokensRewarded == 0.0,
                    message: "Cannot register a new delegator until all tokens from the previous node have been withdrawn"
                )

                destroy delegator
            }

            let vaultRef = self.vault.borrow()!

            assert(
                vaultRef.balance >= FlowIDTableStaking.getDelegatorMinimumStakeRequirement(),
                message: "Must have the delegation minimum FLOW requirement in the locked vault to register a node"
            )

            let tokens <- vaultRef.withdraw(amount: amount)

            let delegator <- self.nodeDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-tokens)

            destroy delegator

            emit LockedAccountRegisteredAsDelegator(address: self.owner!.address, nodeID: nodeID)
        }

        access(account) view fun borrowNode(): auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker? {
            let nodeRef = &self.nodeStaker as auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker?
            return nodeRef
        }

        access(account) view fun borrowDelegator(): auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator? {
            let delegatorRef = &self.nodeDelegator as auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator?
            return delegatorRef
        }

        /// The following two functions are late additions to replicate functionality
        /// that was lost with the Crescendo upgrade
        /// They allow the account that owns the TokenManager to borrow a reference to
        /// the node or delegator directly from its storage
        /// This is only used by the Flow Foundation to recover leases that it has given to node operators
        access(RecoverLease) view fun borrowNodeForLease(): auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker? {
            return self.borrowNode()
        }

        access(RecoverLease) view fun borrowDelegatorForLease(): auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator? {
            return self.borrowDelegator()
        }

        access(UnlockTokens) fun removeNode(): @FlowIDTableStaking.NodeStaker? {
            let node <- self.nodeStaker <- nil

            return <-node
        }

        access(UnlockTokens) fun removeDelegator(): @FlowIDTableStaking.NodeDelegator? {
            let del <- self.nodeDelegator <- nil

            return <-del
        }
    }

    access(all) entitlement TokenOperations

    /// This interfaces allows anybody to read information about the locked account.
    /// Kept for backwards compatibility
    access(all) resource interface LockedAccountInfo {
        access(all) fun getLockedAccountAddress(): Address
        access(all) view fun getLockedAccountBalance(): UFix64
        access(all) fun getUnlockLimit(): UFix64
        access(all) view fun getNodeID(): String?
        access(all) view fun getDelegatorID(): UInt32?
        access(all) view fun getDelegatorNodeID(): String?
    }

    /// Stored in Holder unlocked account
    access(all) resource TokenHolder: FungibleToken.Receiver, FungibleToken.Provider, LockedAccountInfo {

        /// The address of the shared (locked) account.
        access(all) var address: Address

        /// Capability that is used to access the LockedTokenManager
        /// in the shared account
        access(account) var tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>

        /// Used to perform staking actions if the user has signed up
        /// as a node operator
        access(self) var nodeStakerProxy: LockedNodeStakerProxy?

        /// Used to perform delegating actions if the user has signed up
        /// as a delegator
        access(self) var nodeDelegatorProxy: LockedNodeDelegatorProxy?

        init(lockedAddress: Address, tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Must pass a LockedTokenManager capability"
            }

            self.address = lockedAddress
            self.tokenManager = tokenManager

            // Create a new staker proxy that can be accessed in transactions
            self.nodeStakerProxy = LockedNodeStakerProxy(tokenManager: self.tokenManager)

            // create a new delegator proxy that can be accessed in transactions
            self.nodeDelegatorProxy = LockedNodeDelegatorProxy(tokenManager: self.tokenManager)
        }

        /// Utility function to borrow a reference to the LockedTokenManager object
        access(account) view fun borrowTokenManager(): auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager {
            return self.tokenManager.borrow()!
        }

        /// Returns the locked account address for this token holder.
        access(all) view fun getLockedAccountAddress(): Address {
            return self.address
        }

        /// Returns the locked account balance for this token holder.
        /// Subtracts the minimum storage reservation from the value because that portion
        /// of the locked balance is not available to use
        access(all) view fun getLockedAccountBalance(): UFix64 {

            let balance = self.borrowTokenManager().getBalance()

            if balance < FlowStorageFees.minimumStorageReservation {
                return 0.0
            }
            return balance - FlowStorageFees.minimumStorageReservation
        }

        // Returns the unlocked limit for this token holder.
        access(all) view fun getUnlockLimit(): UFix64 {
            return self.borrowTokenManager().unlockLimit
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {Type<@FlowToken.Vault>(): true}
        }

        /// Returns whether or not the given type is accepted by the Receiver
        /// A vault that can accept any type should just return true by default
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            if let isSupported = self.getSupportedVaultTypes()[type] { 
                return isSupported 
            } else { return false }
        }

        /// Deposits tokens in the locked vault, which marks them as
        /// unlocked and available to withdraw
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            self.borrowTokenManager().deposit(from: <-from)
        }

        // FungibleToken.Provider actions

        /// Asks if the amount can be withdrawn from this vault
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.getLockedAccountBalance()
        }

        /// Withdraws tokens from the locked vault. This will only succeed
        /// if the withdraw amount is less than or equal to the limit
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            return <- self.borrowTokenManager().withdraw(amount: amount)
        }

        /// The user calls this function if they want to register as a node operator
        /// They have to provide all the info for their node
        access(TokenOperations) fun createNodeStaker(nodeInfo: StakingProxy.NodeInfo, stakingKeyPoP: String, amount: UFix64) {

            self.borrowTokenManager().registerNode(nodeInfo: nodeInfo, stakingKeyPoP: stakingKeyPoP, amount: amount)

            // Create a new staker proxy that can be accessed in transactions
            self.nodeStakerProxy = LockedNodeStakerProxy(tokenManager: self.tokenManager)
        }

        /// The user calls this function if they want to register as a node operator
        /// They have to provide the node ID for the node they want to delegate to
        access(TokenOperations) fun createNodeDelegator(nodeID: String) {

            self.borrowTokenManager().registerDelegator(nodeID: nodeID, amount: FlowIDTableStaking.getDelegatorMinimumStakeRequirement())

            // create a new delegator proxy that can be accessed in transactions
            self.nodeDelegatorProxy = LockedNodeDelegatorProxy(tokenManager: self.tokenManager)
        }

        /// Borrow a "reference" to the staking object which allows the caller
        /// to perform all staking actions with locked tokens.
        access(TokenOperations) fun borrowStaker(): LockedNodeStakerProxy {
            pre {
                self.nodeStakerProxy != nil:
                    "The NodeStakerProxy doesn't exist!"
            }
            return self.nodeStakerProxy!
        }

        access(all) view fun getNodeID(): String? {
            let tokenManager = self.tokenManager.borrow()!

            return tokenManager.nodeStaker?.id
        }

        /// Borrow a "reference" to the delegating object which allows the caller
        /// to perform all delegating actions with locked tokens.
        access(TokenOperations) fun borrowDelegator(): LockedNodeDelegatorProxy {
            pre {
                self.nodeDelegatorProxy != nil:
                    "The NodeDelegatorProxy doesn't exist!"
            }
            return self.nodeDelegatorProxy!
        }

        access(all) view fun getDelegatorID(): UInt32? {
            let tokenManager = self.tokenManager.borrow()!

            return tokenManager.nodeDelegator?.id
        }

        access(all) view fun getDelegatorNodeID(): String? {
            let tokenManager = self.tokenManager.borrow()!

            return tokenManager.nodeDelegator?.nodeID
        }

    }

    /// Used to perform staking actions
    access(all) struct LockedNodeStakerProxy: StakingProxy.NodeStakerProxy {

        access(self) var tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>

        init(tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid token manager capability"
            }
            self.tokenManager = tokenManager
        }

        access(self) fun nodeObjectExists(_ managerRef: &LockedTokenManager): Bool {
            return managerRef.nodeStaker != nil
        }

        /// Change node networking address
        access(all) fun updateNetworkingAddress(_ newAddress: String) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot change networking address if there is no node object!"
            )

            tokenManagerRef.borrowNode()?.updateNetworkingAddress(newAddress)
        }

        /// Stakes new locked tokens
        access(all) fun stakeNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.borrowNode()?.stakeNewTokens(<-vaultRef.withdraw(amount: amount))
        }

        /// Stakes unstaked tokens from the staking contract
        access(all) fun stakeUnstakedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            tokenManagerRef.borrowNode()?.stakeUnstakedTokens(amount: amount)
        }

        /// Stakes rewarded tokens. Rewarded tokens are freely withdrawable
        /// so if they are staked, the withdraw limit should be increased
        /// because staked tokens are effectively treated as locked tokens
        access(all) fun stakeRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            tokenManagerRef.borrowNode()?.stakeRewardedTokens(amount: amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        /// Requests unstaking for the node
        access(all) fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            tokenManagerRef.borrowNode()?.requestUnstaking(amount: amount)
        }

        /// Requests to unstake all of the node's tokens and all of
        /// the tokens that have been delegated to the node
        access(all) fun unstakeAll() {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            tokenManagerRef.borrowNode()?.unstakeAll()
        }

        /// Withdraw the unstaked tokens back to
        /// the locked token vault. This does not increase the withdraw
        /// limit because staked/unstaked tokens are considered to still
        /// be locked in terms of the vesting schedule
        access(all) fun withdrawUnstakedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            let vaultRef = tokenManagerRef.vault.borrow()!

            let withdrawnTokens <- tokenManagerRef.borrowNode()?.withdrawUnstakedTokens(amount: amount)!

            vaultRef.deposit(from: <-withdrawnTokens)
        }

        /// Withdraw reward tokens to the locked vault,
        /// which increases the withdraw limit
        access(all) fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.nodeObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no node object!"
            )

            tokenManagerRef.deposit(from: <-tokenManagerRef.borrowNode()?.withdrawRewardedTokens(amount: amount)!)
        }
    }

    /// Used to perform delegating actions in transactions
    access(all) struct LockedNodeDelegatorProxy: StakingProxy.NodeDelegatorProxy {

        access(self) var tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>

        init(tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>) {
            pre {
                tokenManager.borrow() != nil: "Invalid LockedTokenManager capability"
            }
            self.tokenManager = tokenManager
        }

        access(self) fun delegatorObjectExists(_ managerRef: &LockedTokenManager): Bool {
            return managerRef.nodeDelegator != nil
        }

        /// delegates tokens from the locked token vault
        access(all) fun delegateNewTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            let vaultRef = tokenManagerRef.vault.borrow()!

            tokenManagerRef.borrowDelegator()?.delegateNewTokens(from: <-vaultRef.withdraw(amount: amount))
        }

        /// Delegate tokens from the unstaked staking bucket
        access(all) fun delegateUnstakedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            tokenManagerRef.borrowDelegator()?.delegateUnstakedTokens(amount: amount)
        }

        /// Delegate rewarded tokens. Increases the unlock limit
        /// because these are freely withdrawable
        access(all) fun delegateRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            tokenManagerRef.borrowDelegator()?.delegateRewardedTokens(amount: amount)

            tokenManagerRef.increaseUnlockLimit(delta: amount)
        }

        /// Request to unstake tokens
        access(all) fun requestUnstaking(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            tokenManagerRef.borrowDelegator()?.requestUnstaking(amount: amount)
        }

        /// withdraw unstaked tokens back to the locked vault
        /// This does not increase the withdraw limit
        access(all) fun withdrawUnstakedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            let vaultRef = tokenManagerRef.vault.borrow()!

            vaultRef.deposit(from: <-tokenManagerRef.borrowDelegator()?.withdrawUnstakedTokens(amount: amount)!)
        }

        /// Withdraw rewarded tokens back to the locked vault,
        /// which increases the withdraw limit because these
        /// are considered unstaked in terms of the vesting schedule
        access(all) fun withdrawRewardedTokens(amount: UFix64) {
            let tokenManagerRef = self.tokenManager.borrow()!

            assert(
                self.delegatorObjectExists(tokenManagerRef),
                message: "Cannot stake if there is no delegator object!"
            )

            tokenManagerRef.deposit(from: <-tokenManagerRef.borrowDelegator()?.withdrawRewardedTokens(amount: amount)!)
        }
    }

    access(all) entitlement AccountCreator

    access(all) resource interface AddAccount {
        access(AccountCreator) fun addAccount(
            sharedAccountAddress: Address,
            unlockedAccountAddress: Address,
            tokenAdmin: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>)
    }

    /// Resource that the Flow token admin
    /// stores in their account to manage the vesting schedule
    /// for all the token holders
    access(all) resource TokenAdminCollection: AddAccount {

        /// Mapping of account addresses to LockedTokenManager capabilities
        access(self) var accounts: {Address: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>}

        init() {
            self.accounts = {}
        }

        /// Add a new account's locked token manager capability
        /// to the record
        access(AccountCreator) fun addAccount(
            sharedAccountAddress: Address,
            unlockedAccountAddress: Address,
            tokenAdmin: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>)
        {
            self.accounts[sharedAccountAddress] = tokenAdmin
            emit SharedAccountRegistered(address: sharedAccountAddress)
            emit UnlockedAccountRegistered(address: unlockedAccountAddress)
        }

        /// Get an accounts capability
        access(all) fun getAccount(address: Address): Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>? {
            return self.accounts[address]
        }

        access(all) fun createAdminCollection(): @TokenAdminCollection {
            return <-create TokenAdminCollection()
        }
    }

    access(all) resource interface LockedAccountCreatorPublic {
        access(all) fun addCapability(cap: Capability<auth(LockedTokens.AccountCreator) &TokenAdminCollection>)
    }

    // account creators store this resource in their account
    // in order to be able to register accounts who have locked tokens
    access(all) resource LockedAccountCreator: LockedAccountCreatorPublic, AddAccount {

        access(self) var addAccountCapability: Capability<auth(LockedTokens.AccountCreator) &TokenAdminCollection>?

        init() {
            self.addAccountCapability = nil
        }

        access(all) fun addCapability(cap: Capability<auth(LockedTokens.AccountCreator) &TokenAdminCollection>) {
            pre {
                cap.borrow() != nil: "Invalid token admin collection capability"
            }
            self.addAccountCapability = cap
        }

        access(AccountCreator) fun addAccount(sharedAccountAddress: Address,
                           unlockedAccountAddress: Address,
                           tokenAdmin: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>) {

            pre {
                self.addAccountCapability != nil:
                    "Cannot add account until the token admin has deposited the account registration capability"
                tokenAdmin.borrow() != nil:
                    "Invalid tokenAdmin capability"
            }

            let adminRef = self.addAccountCapability!.borrow()!

            adminRef.addAccount(sharedAccountAddress: sharedAccountAddress,
                           unlockedAccountAddress: unlockedAccountAddress,
                           tokenAdmin: tokenAdmin)
        }
    }

    /// Public function to create a new Locked Token Manager
    /// every time a new user account is created
    access(all) fun createLockedTokenManager(vault: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>): @LockedTokenManager {
        return <- create LockedTokenManager(vault: vault)
    }

    // Creates a new TokenHolder resource for this LockedTokenManager
    /// that the user can store in their unlocked account.
    access(all) fun createTokenHolder(lockedAddress: Address, tokenManager: Capability<auth(FungibleToken.Withdraw, LockedTokens.UnlockTokens) &LockedTokenManager>): @TokenHolder {
        return <- create TokenHolder(lockedAddress: lockedAddress, tokenManager: tokenManager)
    }

    access(all) fun createLockedAccountCreator(): @LockedAccountCreator {
        return <-create LockedAccountCreator()
    }

    init(admin: auth(Storage) &Account) {
        self.LockedTokenManagerStoragePath = /storage/lockedTokenManager
        self.LockedTokenManagerPrivatePath = /private/lockedTokenManager

        self.LockedTokenAdminPrivatePath = /private/lockedTokenAdmin
        self.LockedTokenAdminCollectionStoragePath = /storage/lockedTokenAdminCollection

        self.TokenHolderStoragePath = /storage/flowTokenHolder
        self.LockedAccountInfoPublicPath = /public/lockedAccountInfo

        self.LockedAccountCreatorStoragePath = /storage/lockedAccountCreator
        self.LockedAccountCreatorPublicPath = /public/lockedAccountCreator

        /// create a single admin collection and store it
        admin.storage.save(<-create TokenAdminCollection(), to: self.LockedTokenAdminCollectionStoragePath)
    }
}
