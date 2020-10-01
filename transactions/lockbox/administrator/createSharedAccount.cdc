import Lockbox from ??

// createSharedAccount
transaction(adminPublicKey: [UInt8], userPublicKey: [UInt8])  {
  prepare(admin: AuthAccount) {
    let sharedAccount = AuthAccount(payer: admin)
    let userAccount = AuthAccount(payer: admin)

    sharedAccount.addPublicKey(adminPublicKey)
    sharedAccount.addPublicKey(userPublicKey)

    // TODO: add separate full-weight key for user
    userAccount.addPublicKey(userPublicKey)

    let vaultCapability = sharedAccount
      .getCapability<&FlowToken.Vault>(/storage/flowTokenVault)!

    let lockedTokenManager = Lockbox.createNewLockedTokenManager(vault: vaultCapability)

    sharedAccount.save(<- lockedTokenManager, to: Lockbox.LockedTokenManagerPath)

    let stakingProxyCapability = sharedAccount
      .link<&Lockbox.LockedTokenManager{Lockbox.StakingProxy}>(
        Lockbox.LockedTokenStakingProxyPrivatePath,
        target: Lockbox.LockedTokenManagerPath
      )

    userAccount.save(
      stakingProxyCapability, 
      to: Lockbox.LockedTokenStakingProxyStoragePath,
    )

    let tokenAdminCapability = sharedAccount
      .link<&Lockbox.LockedTokenManager{Lockbox.TokenAdmin}>(
        Lockbox.LockedTokenAdminPrivatePath,
        target: Lockbox.LockedTokenManagerPath
      )

    let tokenAdminCollection = admin
      .borrow<&Lockbox.TokenAdminCollection>(from: Lockbox.LockedTokenAdminCollectionPath)

    tokenAdminCollection.addAccount(sharedAccount.address, tokenAdminCapability)

    // Override the default FlowToken receiver
    sharedAccount.unlink(/public/flowTokenReceiver)
    sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
      /public/flowTokenReceiver,
      target: Lockbox.LockedTokenManagerPath
    )

    sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
      /public/lockedFlowTokenReceiver,
      target: /storage/flowTokenVault
    )

    let lockedTokenProviderCapability = sharedAccount
      .link<&Lockbox.LockedTokenManager{FungibleToken.Provider}>(
        Lockbox.LockedTokenProviderPrivatePath,
        target: Lockbox.LockedTokenManagerPath
      )

    userAccount.save(
      lockedTokenProviderCapability, 
      to: Lockbox.LockedTokenProviderStoragePath,
    )
  }
}
