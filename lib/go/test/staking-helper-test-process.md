# Setup

### Deployment
- [x] Deploy `FlowIDTableStaking` contract
- [x] Deploy `FlowStakingHelper` contract

### Accounts
- [x] Create `NodeOperator` account
- [x] Create `CustodyProvider` account

### Transactions
##### Creation
- [ ] Call `createAssistant` on `StakingHelper` contract to create new Assistant resource
    - [ ] Check event for new account created
    - [ ] Check full capability `Assistant` was created on `CustodyProvider` account
    - [ ] Check restricted capability `NodeAssistant` was created on `NodeProvider` account

- [ ] Call **`NOT-IMPLEMENTED-METHOD`** to give `TokenHolder` capability to `CustodyProvider`
- [ ] `TokenHolder` commits tokens via provided capability by calling `depositEscrow`


##### Abort
- [ ] Call `abort` by `NodeOperator` account
    - [ ] Check escrow balance to equal to 0
    - [ ] Check `CustodyProvider` balance to increase by the value of escrow


- [ ] Call `abort` by `CustodyProvider` account
    - [ ] Check escrow balance to equal to 0
    - [ ] Check `CustodyProvider` balance to increase by the value of escrow

    
##### Submit
- [ ] Call `submit` method by either `NodeOperator` or `CustodyProvider` account
    - [ ] Check `nodeStaker` on Assistant capability
    - [ ] Check `nodeStaker` on NodeAssistant capability


- [ ] Call `abort` by `CustodyProvider` account and ensure transaction will be reverted


##### Escrow
- [ ] Call `depositEscrow` by `CustodyProvider`
    - [ ] Check balance change in `escrowVault`


- [ ] Call `withdrawEscrow` by `CustodyProvider`
    - [ ] Check balance change in `escrowVault`
    
    
- [ ] Call `stake` by `NodeOperator`
    - [ ] Check balance change in `escrowVault`
    - [ ] Check balance change in `tokensStaked` on `nodeStaker`

- [ ] Call `unstake` by `NodeOperator`
    - [ ] Check balance change in `tokensRequestedToUnstake` on `nodeStaker`
    
- [ ] Call `withdrawTokens` by `NodeOperator`
    - [ ] Check balance change in `tokensUnlocked` on `nodeStaker`
    - [ ] Check balance change in `escrowVault`