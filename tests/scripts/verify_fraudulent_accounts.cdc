// Cadence script that takes a list of addresses, FungibleToken types, and amounts
// and verifies that the addresses have zero of those token types in their vaults
// and that the service account has the amounts of each token in its vaults

import "FungibleToken"
import "FungibleTokenMetadataViews"
import "MetadataViews"
import "EVM"

access(all) struct Balances {
    access(all) let flowTokenBalance: UFix64
    access(all) let coaBalance: EVM.Balance
    access(all) let WBTCBalance: UFix64
    access(all) let USDFBalance: UFix64
    access(all) let TRUMPBalance: UFix64
    access(all) let ceUSDTBalance: UFix64
    access(all) let stgUSDCBalance: UFix64
    access(all) let pyUSDBalance: UFix64
    access(all) let frothBalance: UFix64
    access(all) let betaBalance: UFix64
    access(all) let USDCeBalance: UFix64
    access(all) let ceDAIBalance: UFix64
    access(all) let WETHBridgedBalance: UFix64
    access(all) let ceWETHBalance: UFix64
    access(all) let WETHBalance: UFix64
    access(all) let ceBNBBalance: UFix64
    access(all) let ceBUSDBalance: UFix64

    init(flowTokenBalance: UFix64, 
         coaBalance: EVM.Balance, 
         WBTCBalance: UFix64, 
         USDFBalance: UFix64, 
         TRUMPBalance: UFix64, 
         ceUSDTBalance: UFix64, 
         stgUSDCBalance: UFix64, 
         pyUSDBalance: UFix64, 
         frothBalance: UFix64, 
         betaBalance: UFix64, 
         USDCeBalance: UFix64, 
         ceDAIBalance: UFix64, 
         WETHBridgedBalance: UFix64, 
         ceWETHBalance: UFix64, 
         WETHBalance: UFix64, 
         ceBNBBalance: UFix64, 
         ceBUSDBalance: UFix64) 
    {
        self.flowTokenBalance = flowTokenBalance
        self.coaBalance = coaBalance
        self.WBTCBalance = WBTCBalance
        self.USDFBalance = USDFBalance
        self.TRUMPBalance = TRUMPBalance
        self.ceUSDTBalance = ceUSDTBalance
        self.stgUSDCBalance = stgUSDCBalance
        self.pyUSDBalance = pyUSDBalance
        self.frothBalance = frothBalance
        self.betaBalance = betaBalance
        self.USDCeBalance = USDCeBalance
        self.ceDAIBalance = ceDAIBalance
        self.WETHBridgedBalance = WETHBridgedBalance
        self.ceWETHBalance = ceWETHBalance
        self.WETHBalance = WETHBalance
        self.ceBNBBalance = ceBNBBalance
        self.ceBUSDBalance = ceBUSDBalance
    }
}

access(all) fun main(address: Address): Balances {
    let account = getAccount(address)

    let tokenTypes = [
"A.1e4aa0b87d10b141.EVMVMBridgedToken_2aabea2058b5ac2d339b163c6ab6f2b6d53aabed.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_717dae2baf7656be9a9b01dee31d571a9d4c9579.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_99af3eea856556646c98c8b9b2548fe815240750.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_b73bf8e6a4477a952e0338e6cc00cc0ce5ad04ba.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_d8ad8ae8375aa31bff541e17dc4b4917014ebdaa.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_f1815bd50389c46847f0bda824ec8da914045d14.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_2f6f07cdcf3588944bf4c42ac74ff24bf56e7590.Vault",
"A.1e4aa0b87d10b141.EVMVMBridgedToken_d3378b419feae4e3a4bb4f3349dba43a1b511760.Vault"]

    var WBTCBalance: UFix64? = nil
    var USDFBalance: UFix64? = nil
    var TRUMPBalance: UFix64? = nil
    var stgUSDCBalance: UFix64? = nil
    var pyUSDBalance: UFix64? = nil
    var frothBalance: UFix64? = nil
    var betaBalance: UFix64? = nil
    var WETHBridgedBalance: UFix64? = nil

    for tokenType in tokenTypes {
        // Get the path and type data for the provided token type identifier
        let vaultData = MetadataViews.resolveContractViewFromTypeIdentifier(
            resourceTypeIdentifier: tokenType,
            viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
        ) as? FungibleTokenMetadataViews.FTVaultData
            ?? panic("Could not construct valid FTVaultData type and view from identifier \(tokenType)")

        let vaultDisplay = MetadataViews.resolveContractViewFromTypeIdentifier(
            resourceTypeIdentifier: tokenType,
            viewType: Type<FungibleTokenMetadataViews.FTDisplay>()
        ) as? FungibleTokenMetadataViews.FTDisplay
            ?? panic("Could not construct valid FTDisplay type and view from identifier \(tokenType)")

        if vaultDisplay.name == "Wrapped BTC" {   
            WBTCBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "USD Flow" {
            USDFBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "OFFICIAL TRUMP" {
            TRUMPBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0       
        } else if vaultDisplay.name == "Bridged USDC (Stargate)" {
            stgUSDCBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "PYUSD0" {
            pyUSDBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "Froth" {
            frothBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "BETA" {
            betaBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else if vaultDisplay.name == "WETH" {
            WETHBridgedBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(vaultData.metadataPath)?.balance ?? 0.0
        } else {
            panic("Unknown token display name \(vaultDisplay.name)")
        }
    }

    let flowTokenBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/flowTokenBalance)?.balance ?? 0.0
    let coaBalance = account.capabilities.borrow<&EVM.CadenceOwnedAccount>(/public/evm)?.balance() ?? EVM.Balance(attoflow: 0)

    let ceUSDTBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/ceUSDTVault)?.balance ?? 0.0
    let USDCeBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/usdcFlowMetadata)?.balance ?? 0.0
    let ceDAIBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/ceDAIVault)?.balance ?? 0.0
    let ceWETHBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/ceWETHVault)?.balance ?? 0.0
    let WETHBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/WETHVault)?.balance ?? 0.0
    let ceBNBBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/ceBNBVault)?.balance ?? 0.0
    let ceBUSDBalance = account.capabilities.borrow<&{FungibleToken.Vault}>(/public/ceBUSDVault)?.balance ?? 0.0

    return Balances(flowTokenBalance: flowTokenBalance,
                    coaBalance: coaBalance,
                    WBTCBalance: WBTCBalance ?? 666.0,
                    USDFBalance: USDFBalance ?? 666.0,
                    TRUMPBalance: TRUMPBalance ?? 666.0,
                    ceUSDTBalance: ceUSDTBalance,
                    stgUSDCBalance: stgUSDCBalance ?? 666.0,
                    pyUSDBalance: pyUSDBalance ?? 666.0,
                    frothBalance: frothBalance ?? 666.0,
                    betaBalance: betaBalance ?? 666.0,
                    USDCeBalance: USDCeBalance,
                    ceDAIBalance: ceDAIBalance,
                    WETHBridgedBalance: WETHBridgedBalance ?? 666.0,
                    ceWETHBalance: ceWETHBalance,
                    WETHBalance: WETHBalance,
                    ceBNBBalance: ceBNBBalance,
                    ceBUSDBalance: ceBUSDBalance)
}