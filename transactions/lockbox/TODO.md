## Overview

### Personas

- Token Admin (TA)
- Token Holder (TH)
- Node Operator (NO)
- Token Holder/Operator (TH-NO)

### Use Cases

1. TH-NO stakes directly
1. TH delegates directly
1. NO operates a node with StakingHelper
1. TH stake with StakingHelper

## Transactions

### Token Admin (TA)

- [ ] createAdminAccount (with `TokenAdminCollection`)
- [ ] createLockedAccount
- [ ] depositLockedTokens
- [ ] increaseUnlockLimit

### Token Holder (TH)

- [ ] createUnlockedAccount
- [ ] withdrawUnlockedTokens

#### Staking (with `Lockbox.NodeStakerProxy`)

- [ ] getOperatorNodeInfo (with `StakingProxy.NodeStakerProxyHolderPublic`)
- [ ] stakeLockedRewardedTokens

#### Delegating (with `Lockbox.NodeDelegatorProxy`)

- [ ] registerLockedDelegator
- [ ] delegateNewLockedTokens
- [ ] delegateLockedUnlockedTokens
- [ ] delegateLockedRewardedTokens
- [ ] requestUnstakingLockedDelegatedTokens
- [ ] unstakeAllLockedDelegatedTokens
- [ ] withdrawLockedUnlockedDelegatedTokens
- [ ] withdrawLockedRewardedDelegatedTokens

### Token Holder or Node Operator (TH-NO)

#### Staking (with `Lockbox.NodeStakerProxy`)

- [ ] stakeNewLockedTokens
- [ ] stakeLockedUnlockedTokens
- [ ] ~~stakeLockedRewardedTokens~~ _Can only be done by Token Holder._
- [ ] unstakeLockedTokens
- [ ] withdrawLockedUnlockedTokens
- [ ] withdrawLockedRewardedTokens

### Node Operator (NO)

- [ ] createOperatorAccount (with `StakingProxy.NodeStakerProxyHolder`)

#### Staking

- [ ] addNodeInfo
- [ ] removeNodeInfo
