import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import StakingProxy from ??

pub contract Lockbox {

  // 1. Admin: Dapper Labs only
  // 2. Shared: Dapper Labs + Token Holder
  // 3. Holder: Token Holder only

  pub let LockedTokenManagerPath: Path

  pub let LockedTokenStakingProxyPrivatePath: Path
  pub let LockedTokenStakingProxyStoragePath: Path

  pub let LockedTokenAdminPrivatePath: Path
  pub let LockedTokenAdminCollectionPath: Path

  pub let LockedTokenProviderPrivatePath: Path

  // lives in Dapper Labs account
  pub resource interface TokenAdmin {
    pub fun increaseUnlockLimit(delta: UFix64)
  }

  pub resource interface StakingProxy {
    // submit req to stake
    pub fun stake(amount: UFix64)

    // submit req to unstake
    pub fun unstake(amount: UFix64)

    // move unstaked tokens back into lockbox
    pub fun claimStake(amount: UFix64)

    // move rewards back into lockbox
    pub fun claimRewards(amount: UFix64)
  }

  pub resource LockedTokenManager: FungibleToken.Receiver, FungibleToken.Provider, TokenAdmin, StakingProxy {
  
    pub var vault: Capability<&FlowToken.Vault>

    pub var unlockLimit: UFix64

    // FungibleToken.Receiver actions

    pub fun deposit(from: @Vault) {
      let balance = from.balance

      vault.deposit(from: <- from)

      self.increaseUnlockLimit(delta: balance)
    }

    // FungibleToken.Provider actions

    pub fun withdraw(amount: UFix64): @FlowToken.Vault {
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

    // Lockbox.TokenAdministrator actions

    pub fun increaseUnlockLimit(delta: UFix64) {  
      self.unlockLimit = self.unlockLimit + delta
    }

    // StakingProxy.Proxy actions

    pub fun stake(amount: UFix64) {
      // TODO
    }

    pub fun unstake(amount: UFix64) {
      // TODO
    }

    pub fun claimStake(amount: UFix64) {
      // TODO
    }

    pub fun claimRewards(amount: UFix64) {
      // TODO
    }

    init(vault: Capability<&FlowToken.Vault>) {
      self.vault = vault
      self.unlockLimit = 0.0

      self.LockedTokenManagerPath = /storage/lockedTokenManager

      self.LockedTokenStakingProxyPrivatePath = /private/lockedTokenStakingProxy
      self.LockedTokenStakingProxyStoragePath = /storage/lockedTokenStakingProxy

      self.LockedTokenAdminPrivatePath = /private/lockedTokenAdmin
      self.LockedTokenAdminCollectionPath = /storage/lockedTokenAdminCollection

      self.LockedTokenProviderPrivatePath = /private/lockedTokenProvider
      self.LockedTokenProviderStoragePath = /storage/lockedTokenProvider
    }
  }

  pub resource TokenAdminCollection {
    access(self) var accounts: {Address: Capability<&LockedTokenManager{TokenAdmin}>}

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
}
