import FungibleToken from 0xFUNGIBLETOKENADDRESS

pub contract FlowArcadeToken: FungibleToken {

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    // The storage path for the admin resource
    pub let AdminStoragePath: Path

    // The private path for the minter capability
    pub let AdminMinterPrivatePath: Path

    // The storage Path for minters' MinterProxy
    pub let MinterProxyStoragePath: Path

    // The public path for minters' MinterProxy capability
    pub let MinterProxyPublicPath: Path

    // The storage path for the vault resource
    pub let VaultStoragePath: Path

    // The storage path for the vault receiver
    pub let ReceiverPublicPath: Path

    // The storage path for the vault balance
    pub let BalancePublicPath: Path

    // Total supply of FATs in existence
    pub var totalSupply: UFix64

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault are governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        //
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @FlowArcadeToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            FlowArcadeToken.totalSupply = FlowArcadeToken.totalSupply - self.balance
            // Track the case where a non-zero balance is destroyed.
            // Burning FATs is a legitimate use case, so we do not guard against this,
            // but when the tokens are burned the burner probably wants to signal this.
            // If you wish to have a burn address, create an account with a FAT Vault,
            // send the tokens to it, then have the account owner perform the burn
            // (this can be exposed as a capability to automate it).
            if (self.balance > 0.0) {
                emit TokensBurned(amount: self.balance)
            }
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @FlowArcadeToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    // Minter
    //
    // Interface that can be used to pass around Minter capabilities.
    //
    pub resource interface Minter {
        pub fun mintTokens(amount: UFix64): @FlowArcadeToken.Vault {
            pre {
                amount > UFix64(0): "Amount minted must be greater than zero"
            }
        }
    }

    // Administrator
    //
    // A resource that can mint new tokens
    //
    //
    pub resource Administrator: Minter {

        pub fun mintTokens(amount: UFix64): @FlowArcadeToken.Vault {
            FlowArcadeToken.totalSupply = FlowArcadeToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

    }

    // MinterProxyPublic
    //
    // Interface that allows a Minter Capability to be set on a MinterProxy
    //
    pub resource interface MinterProxyPublic {
        // This should be Ca[ability<&Administrator{Minter}> but that is currently buggy.
        pub fun setMinterCapability(cap: Capability<&{Minter}>)
    }

    // MinterProxy
    //
    // Resource object holding a capability that can be used to mint new tokens.
    // The resource that this capability represents can be deleted by the admin
    // in order to unilaterally revoke minting capability if needed.

    pub resource MinterProxy: MinterProxyPublic {

        // access(self) so nobody else can copy the capability and use it.
        access(self) var minterCapability: Capability<&{Minter}>?

        // Anyone can call this, but only the admin can create Minter capabilities,
        // so the type system constrains this to being called by the admin.
        pub fun setMinterCapability(cap: Capability<&{Minter}>) {
            self.minterCapability = cap
        }

        pub fun mintTokens(amount: UFix64): @FlowArcadeToken.Vault {
            return <- self.minterCapability!
            .borrow()!
            .mintTokens(amount:amount)
        }

        init() {
            self.minterCapability = nil
        }

    }

    // createMinterProxy
    //
    // Function that creates a MinterProxy.
    // Anyone can call this, but the MinterProxy cannot mint without a Minter capability,
    // and only the admin can provide that.
    //
    pub fun createMinterProxy(): @MinterProxy {
        return <- create MinterProxy()
    }


    init(adminAccount: AuthAccount) {
        // If a user of the minter capability is compromised we would move the admin resource to revoke it.
        // But since that shouldn't happen we do store the paths to them here.
        self.AdminStoragePath = /storage/flowArcadeTokenAdmin
        self.AdminMinterPrivatePath = /private/flowArcadeTokenMinter
        self.MinterProxyPublicPath = /public/flowArcadeTokenMinterProxy
        self.MinterProxyStoragePath = /storage/flowArcadeTokenMinterProxy
        self.VaultStoragePath = /storage/flowArcadeTokenVault
        self.ReceiverPublicPath = /public/flowArcadeTokenReceiver
        self.BalancePublicPath = /public/flowArcadeTokenBalance

        self.totalSupply = 0.0

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: self.AdminStoragePath)
        adminAccount.link<&Administrator{Minter}>(self.AdminMinterPrivatePath, target: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: 0.0)
    }
}
 
