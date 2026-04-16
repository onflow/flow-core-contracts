import "Burner"
import "FungibleToken"
import "FungibleTokenMetadataViews"
import "NonFungibleToken"
import "MetadataViews"
import "CrossVMMetadataViews"
import "ViewResolver"

import "EVM"

import "IBridgePermissions"
import "ICrossVM"
import "IEVMBridgeNFTMinter"
import "IEVMBridgeTokenMinter"
import "IFlowEVMNFTBridge"
import "IFlowEVMTokenBridge"
import "CrossVMNFT"
import "CrossVMToken"
import "FlowEVMBridgeCustomAssociationTypes"
import "FlowEVMBridgeCustomAssociations"
import "FlowEVMBridgeConfig"
import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeUtils"
import "FlowEVMBridgeNFTEscrow"
import "FlowEVMBridgeTokenEscrow"
import "FlowEVMBridgeTemplates"
import "SerializeMetadata"

/// The FlowEVMBridge contract is the main entrypoint for bridging NFT & FT assets between Flow & FlowEVM.
///
/// Before bridging, be sure to onboard the asset type which will configure the bridge to handle the asset. From there,
/// the asset can be bridged between VMs via the COA as the entrypoint.
///
/// See also:
/// - Code in context: https://github.com/onflow/flow-evm-bridge
/// - FLIP #237: https://github.com/onflow/flips/pull/233
///
access(all)
contract FlowEVMBridge : IFlowEVMNFTBridge, IFlowEVMTokenBridge {

    /*************
        Events
    **************/

    /// Emitted any time a new asset type is onboarded to the bridge
    access(all)
    event Onboarded(type: String, cadenceContractAddress: Address, evmContractAddress: String)
    /// Denotes a defining contract was deployed to the bridge account
    access(all)
    event BridgeDefiningContractDeployed(
        contractName: String,
        assetName: String,
        symbol: String,
        isERC721: Bool,
        evmContractAddress: String
    )
    /// Emitted whenever a bridged NFT is burned as a part of the bridging process. In the context of this contract,
    /// this only occurs when an EVM-native ERC721 updates from a bridged NFT to their own custom Cadence NFT.
    access(all)
    event BridgedNFTBurned(type: String, id: UInt64, evmID: UInt256, uuid: UInt64, erc721Address: String)

    /**************************
        Public Onboarding
    **************************/

    /// Onboards a given asset by type to the bridge. Since we're onboarding by Cadence Type, the asset must be defined
    /// in a third-party contract. Attempting to onboard a bridge-defined asset will result in an error as the asset has
    /// already been onboarded to the bridge.
    ///
    /// @param type: The Cadence Type of the NFT to be onboarded
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun onboardByType(_ type: Type, feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}) {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !FlowEVMBridgeConfig.isCadenceTypeBlocked(type):
            "This Cadence Type \(type.identifier) is currently blocked from being onboarded"
            self.typeRequiresOnboarding(type) == true: "Onboarding is not needed for this type"
            FlowEVMBridgeUtils.typeAllowsBridging(type):
            "This Cadence Type \(type.identifier) is currently opted-out of bridge onboarding"
            FlowEVMBridgeUtils.isCadenceNative(type: type): "Only Cadence-native assets can be onboarded by Type"
        }
        /* Custom cross-VM Implementation check */
        //
        // Register as a custom cross-VM implementation if detected
        if FlowEVMBridgeUtils.getEVMPointerView(forType: type) != nil {
            self.registerCrossVMNFT(type: type, fulfillmentMinter: nil, feeProvider: feeProvider)
            return
        }

        /* Provision fees */
        //
        // Withdraw from feeProvider and deposit to self
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: FlowEVMBridgeConfig.onboardFee)

        /* EVM setup */
        //
        // Deploy an EVM defining contract via the FlowBridgeFactory.sol contract
        let onboardingValues = self.deployEVMContract(forAssetType: type)

        /* Cadence escrow setup */
        //
        // Initialize bridge escrow for the asset based on its type
        if type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            FlowEVMBridgeNFTEscrow.initializeEscrow(
                forType: type,
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                erc721Address: onboardingValues.evmContractAddress
            )
        } else if type.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            let createVaultFunction = FlowEVMBridgeUtils.getCreateEmptyVaultFunction(forType: type)
                ?? panic("Could not retrieve createEmptyVault function for the given type")
            let vault <-createVaultFunction(type)
            assert(
                vault.getType() == type,
                message: "Requested to onboard type=\(type.identifier) but contract returned type=\(vault.getType().identifier)"
            )
            FlowEVMBridgeTokenEscrow.initializeEscrow(
                with: <-vault,
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                decimals: onboardingValues.decimals!,
                evmTokenAddress: onboardingValues.evmContractAddress
            )
        } else {
            panic("Attempted to onboard unsupported type: \(type.identifier)")
        }

        /* Confirmation */
        //
        assert(
            FlowEVMBridgeNFTEscrow.isInitialized(forType: type) || FlowEVMBridgeTokenEscrow.isInitialized(forType: type),
            message: "Failed to initialize escrow for given type"
        )

        emit Onboarded(
            type: type.identifier,
            cadenceContractAddress: FlowEVMBridgeUtils.getContractAddress(fromType: type)!,
            evmContractAddress: onboardingValues.evmContractAddress.toString()
        )
    }

    /// Onboards a given EVM contract to the bridge. Since we're onboarding by EVM Address, the asset must be defined in
    /// a third-party EVM contract. Attempting to onboard a bridge-defined asset will result in an error as onboarding
    /// is not required.
    ///
    /// @param address: The EVMAddress of the ERC721 or ERC20 to be onboarded
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun onboardByEVMAddress(
        _ address: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !FlowEVMBridgeConfig.isEVMAddressBlocked(address):
                "This EVM contract \(address.toString()) is currently blocked from being onboarded"
        }
        /* Custom cross-VM Implementation check */
        //
        let cadenceAddr = FlowEVMBridgeUtils.getDeclaredCadenceAddressFromCrossVM(evmContract: address)
        let cadenceType = FlowEVMBridgeUtils.getDeclaredCadenceTypeFromCrossVM(evmContract: address)
        // Register as a custom cross-VM implementation if detected
        if cadenceAddr != nil && cadenceType != nil {
            self.registerCrossVMNFT(type: cadenceType!, fulfillmentMinter: nil, feeProvider: feeProvider)
            return
        }

        /* Validate the EVM contract */
        //
        // Ensure the project has not opted out of bridge support
        assert(
            FlowEVMBridgeUtils.evmAddressAllowsBridging(address),
            message: "This contract is not supported as defined by the project's development team"
        )
        assert(
            self.evmAddressRequiresOnboarding(address) == true,
            message: "Onboarding is not needed for this contract"
        )

        /* Provision fees */
        //
        // Withdraw fee from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: FlowEVMBridgeConfig.onboardFee)

        /* Setup Cadence-defining contract */
        //
        // Deploy a defining Cadence contract to the bridge account
        self.deployDefiningContract(evmContractAddress: address)
    }

    /// Registers a custom cross-VM NFT implementation, allowing projects to integrate their Cadence & EVM contracts
    /// such that the VM bridge facilitates movement between VMs as the integrated implementations.
    ///
    /// @param type: The NFT Type to register as cross-VM NFT
    /// @param fulfillmentMinter: The optional NFTFulfillmentMinter Capability. This parameter is required for
    ///     EVM-native NFTs
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun registerCrossVMNFT(
        type: Type,
        fulfillmentMinter: Capability<auth(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM) &{FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter}>?,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            FlowEVMBridgeUtils.typeAllowsBridging(type):
            "This Cadence Type \(type.identifier) is currently opted-out of bridge onboarding"
            type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()):
            "The provided Type \(type.identifier) is not an NFT - only NFTs can register as cross-VM"
            !type.isSubtype(of: Type<@{FungibleToken.Vault}>()):
            "The provided Type \(type.identifier) is also a FungibleToken Vault - only NFTs can register as cross-VM"
            !FlowEVMBridgeConfig.isCadenceTypeBlocked(type):
            "Type \(type.identifier) has been blocked from onboarding"
            FlowEVMBridgeUtils.isCadenceNative(type: type):
            "Attempting to register a bridge-deployed NFT - cannot update a bridge-defined asset. If updating your EVM contract's Cadence association, deploy your Cadence NFT contract and register using the newly defined Cadence type"
            FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type) == nil:
            "A custom association has already been declared for type \(type.identifier) with EVM address \(FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type)!.toString()). Custom associations can only be declared once for any given Cadence Type or EVM contract"
            fulfillmentMinter?.check() ?? true:
            "NFTFulfillmentMinter Capability is invalid - Issue a new Capability<auth(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM) &{FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter}> and try again"
            fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.getType().address! == type.address! : true:
            "NFTFulfillmentMinter must be defined by a contract deployed to the registered type address \(type.address!) but found defining address of \(fulfillmentMinter!.borrow()!.getType().address!)"
        }
        /* Provision fees */
        //
        // Withdraw fee from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: FlowEVMBridgeConfig.onboardFee)

        /* Get pointers from both contracts */
        //
        // Get the Cadence side EVMPointer
        let evmPointer = FlowEVMBridgeUtils.getEVMPointerView(forType: type)
            ?? panic("The CrossVMMetadataViews.EVMPointer is not supported by the type \(type.identifier).")
        // EVM contract checks
        assert(!FlowEVMBridgeConfig.isEVMAddressBlocked(evmPointer.evmContractAddress),
            message: "Type \(type.identifier) has been blocked from onboarding.")
        assert(
            FlowEVMBridgeUtils.evmAddressAllowsBridging(evmPointer.evmContractAddress),
            message: "The EVM contract \(evmPointer.evmContractAddress.toString()) developers have opted out of VM bridge integration."
        )
        assert(
            FlowEVMBridgeCustomAssociations.getTypeAssociated(with: evmPointer.evmContractAddress) == nil,
            message: "A custom association has already been declared for EVM address \(evmPointer.evmContractAddress.toString()) with Cadence Type \(FlowEVMBridgeCustomAssociations.getTypeAssociated(with: evmPointer.evmContractAddress)?.identifier ?? "<UNKNOWN>"). Custom associations can only be declared once for any given Cadence Type or EVM contract"
        )
        assert(
            FlowEVMBridgeUtils.isERC721(evmContractAddress: evmPointer.evmContractAddress)
            && !FlowEVMBridgeUtils.isERC20(evmContractAddress: evmPointer.evmContractAddress),
            message: "Cross-VM NFTs must be implemented as ERC721 exclusively, but detected an invalid EVM interface at EVM contract \(evmPointer.evmContractAddress.toString())"
        )

        // Get pointer on EVM side
        let cadenceAddr = FlowEVMBridgeUtils.getDeclaredCadenceAddressFromCrossVM(evmContract: evmPointer.evmContractAddress)
            ?? panic("Could not retrieve a Cadence address declaration from the EVM contract \(evmPointer.evmContractAddress.toString())")
        let cadenceType = FlowEVMBridgeUtils.getDeclaredCadenceTypeFromCrossVM(evmContract: evmPointer.evmContractAddress)
            ?? panic("Could not retrieve a Cadence Type declaration from the EVM contract \(evmPointer.evmContractAddress.toString())")

        /* Pointer validation */
        //
        // Assert both point to each other
        assert(
            type.address == cadenceAddr,
            message: "Mismatched Cadence Address pointers: \(type.address!.toString()) and \(cadenceAddr.toString())"
        )
        assert(
            type == cadenceType,
            message: "Mismatched type pointers: \(type.identifier) and \(cadenceType.identifier)"
        )

        /* Cross-VM conformance check */
        //
        // Check supportsInterface() for CrossVMBridgeERC721Fulfillment if NFT is Cadence-native
        if evmPointer.nativeVM == CrossVMMetadataViews.VM.Cadence {
            assert(FlowEVMBridgeUtils.supportsCadenceNativeNFTEVMInterfaces(evmContract: evmPointer.evmContractAddress),
                message: "Corresponding EVM contract does not implement necessary EVM interfaces ICrossVMBridgeERC721Fulfillment and/or ICrossVMBridgeCallable. All Cadence-native cross-VM NFTs must implement these interfaces and grant the bridge COA the ability to fulfill bridge requests moving NFTs into EVM.")
            let designatedVMBridgeAddress = FlowEVMBridgeUtils.getVMBridgeAddressFromICrossVMBridgeCallable(evmContract: evmPointer.evmContractAddress)
                ?? panic("Could not recover declared VM bridge address from EVM contract \(evmPointer.evmContractAddress.toString()). Ensure the contract conforms to ICrossVMBridgeCallable and declare the vmBridgeAddress as \(FlowEVMBridgeUtils.getBridgeCOAEVMAddress().toString())")
            assert(designatedVMBridgeAddress.equals(FlowEVMBridgeUtils.getBridgeCOAEVMAddress()),
                message: "ICrossVMBridgeCallable declared \(designatedVMBridgeAddress.toString()) as vmBridgeAddress which must be declared as \(FlowEVMBridgeUtils.getBridgeCOAEVMAddress().toString())")
        }

        /* Native VM consistency check */
        //
        // Assess if the NFT has been previously onboarded to the bridge
        let legacyEVMAssoc = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: type)
        let legacyCadenceAssoc = FlowEVMBridgeConfig.getLegacyTypeAssociated(with: evmPointer.evmContractAddress)
        assert(legacyEVMAssoc == nil || legacyCadenceAssoc == nil,
            message: "Both the EVM contract \(evmPointer.evmContractAddress.toString()) and the Cadence Type \(type.identifier) have already been onboarded to the VM bridge - one side of this association will have to be redeployed and the declared association updated to a non-onboarded target in order to register as a custom cross-VM asset.")
        // Ensure the native VM is consistent if the NFT has been previously onboarded via the permissionless path
        if legacyEVMAssoc != nil {
            assert(evmPointer.nativeVM == CrossVMMetadataViews.VM.Cadence,
                message: "Attempting to register NFT \(type.identifier) as EVM-native after it has already been onboarded as Cadence-native. This NFT must be configured as Cadence-native with an ERC721 implementing CrossVMBridgeERC721Fulfillment base contract allowing the bridge to fulfill NFTs moving into EVM")
        } else if legacyCadenceAssoc != nil {
            assert(evmPointer.nativeVM == CrossVMMetadataViews.VM.EVM,
                message: "Attempting to register NFT \(type.identifier) as Cadence-native after it has already been onboarded as EVM-native. This NFT must be configured as EVM-native and provide an NFTFulfillmentMinter Capability so the bridge may fulfill NFTs moving into Cadence.")
        }

        FlowEVMBridgeCustomAssociations.saveCustomAssociation(
            type: type,
            evmContractAddress: evmPointer.evmContractAddress,
            nativeVM: evmPointer.nativeVM,
            updatedFromBridged: legacyEVMAssoc != nil || legacyCadenceAssoc != nil,
            fulfillmentMinter: fulfillmentMinter
        )

        if !FlowEVMBridgeNFTEscrow.isInitialized(forType: type) {
            let name = FlowEVMBridgeUtils.getName(evmContractAddress: evmPointer.evmContractAddress)
            let symbol = FlowEVMBridgeUtils.getSymbol(evmContractAddress: evmPointer.evmContractAddress)
            FlowEVMBridgeNFTEscrow.initializeEscrow(
                forType: type,
                name: name,
                symbol: symbol,
                erc721Address: evmPointer.evmContractAddress
            )
        }
    }

    /*************************
        NFT Handling
    **************************/

    /// Public entrypoint to bridge NFTs from Cadence to EVM as ERC721.
    ///
    /// @param token: The NFT to be bridged
    /// @param to: The NFT recipient in FlowEVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !token.isInstance(Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(token.getType()) == false: "NFT must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(token.getType()) == false: "Bridging is currently paused for this NFT"
        }
        let bridgedAssoc = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: token.getType())
        let customAssocByType = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: token.getType())
        let customAssocByEVMAddr =  bridgedAssoc != nil ? FlowEVMBridgeCustomAssociations.getTypeAssociated(with: bridgedAssoc!) : nil
        if bridgedAssoc != nil && customAssocByType == nil && customAssocByEVMAddr == nil {
            // Common case - bridge-defined counterpart in non-native VM
            return self.handleDefaultNFTToEVM(token: <-token, to: to, feeProvider: feeProvider)
        } else if customAssocByType != nil && customAssocByEVMAddr == nil {
            // NFT is registered as cross-VM
            return self.handleCrossVMNFTToEVM(token: <-token, to: to, feeProvider: feeProvider)
        } else if customAssocByType == nil && customAssocByEVMAddr != nil {
            // Dealing with a bridge-defined NFT after a custom association has been configured
            return self.handleUpdatedBridgedNFTToEVM(token: <-token, to: to, feeProvider: feeProvider)
        }
        // customAssocByType != nil && customAssocByEVMAddr != nil
        panic("Unknown error encountered bridging NFT \(token.getType().identifier) with ID \(token.id) to EVM recipient \(to.toString())")
    }

    /// Entrypoint to bridge ERC721 from EVM to Cadence as NonFungibleToken.NFT
    ///
    /// @param owner: The EVM address of the NFT owner. Current ownership and successful transfer (via
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on NFT in EVM contract
    /// @param id: The NFT ID to bridged
    /// @param evmContractAddress: Address of the EVM address defining the NFT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the NFT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged NFT
    ///
    access(account)
    fun bridgeNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !type.isSubtype(of: Type<@{FungibleToken.Vault}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "NFT must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(type) == false: "Bridging is currently paused for this NFT"
        }
        let bridgedAssoc = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: type)
        let customAssocByType = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type)
        let customAssocByEVMAddr =  bridgedAssoc != nil ? FlowEVMBridgeCustomAssociations.getTypeAssociated(with: bridgedAssoc!) : nil
        // Initialize the internal handler method that will be used to move the NFT from EVM
        var handler: (fun (EVM.EVMAddress, Type, UInt256, auth(FungibleToken.Withdraw) &{FungibleToken.Provider}, fun (EVM.EVMAddress): EVM.ResultDecoded): @{NonFungibleToken.NFT})? = nil
        if bridgedAssoc != nil && customAssocByType == nil && customAssocByEVMAddr == nil {
            // Common case - bridge-defined counterpart in non-native VM
            handler = self.handleDefaultNFTFromEVM
        } else if customAssocByType != nil && customAssocByEVMAddr == nil {
            // NFT is registered as cross-VM
            handler = self.handleCrossVMNFTFromEVM
        } else if customAssocByType == nil && customAssocByEVMAddr != nil {
            // Dealing with a bridge-defined NFT after a custom association has been configured
            handler = self.handleUpdatedBridgedNFTFromEVM
        } else {
            // customAssocByType != nil && customAssocByEVMAddr != nil
            panic("Unknown error encountered bridging NFT \(type.identifier) with ID \(id) from EVM owner \(owner.toString())")
        }
        // Return the bridged NFT, using the appropriate handler
        return <- handler!(owner: owner, type: type, id: id, feeProvider: feeProvider, protectedTransferCall: protectedTransferCall)
    }

    /**************************
        FT Handling
    ***************************/

    /// Public entrypoint to bridge FTs from Cadence to EVM as ERC20 tokens.
    ///
    /// @param vault: The fungible token Vault to be bridged
    /// @param to: The fungible token recipient in EVM
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    ///
    access(all)
    fun bridgeTokensToEVM(
        vault: @{FungibleToken.Vault},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !vault.isInstance(Type<@{NonFungibleToken.NFT}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(vault.getType()) == false: "FungibleToken must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(vault.getType()) == false: "Bridging is currently paused for this token"
        }
        /* Handle $FLOW requests via EVM interface & return */
        //
        let vaultType = vault.getType()

        // Gather the vault balance before acting on the resource
        let vaultBalance = vault.balance
        // Initialize fee amount to 0.0 and assign as appropriate for how the token is handled
        var feeAmount = 0.0

        /* TokenHandler coverage */
        //
        // Some tokens pre-dating bridge require special case handling - borrow handler and passthrough to fulfill
        if FlowEVMBridgeConfig.typeHasTokenHandler(vaultType) {
            let handler = FlowEVMBridgeConfig.borrowTokenHandler(vaultType)
                ?? panic("Could not retrieve handler for the given type")
            handler.fulfillTokensToEVM(tokens: <-vault, to: to)

            // Here we assume burning Vault in Cadence which doesn't require storage consumption
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
            FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)
            return
        }

        /* Escrow or burn tokens depending on native environment */
        //
        // In most all other cases, if Cadence-native then tokens must be escrowed
        if FlowEVMBridgeUtils.isCadenceNative(type: vaultType) {
            // Lock the FT balance & calculate the extra used by the FT if any
            let storageUsed = FlowEVMBridgeTokenEscrow.lockTokens(<-vault)
            // Calculate the bridge fee on current rates
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: storageUsed)
        } else {
            // Since not Cadence-native, bridge defines the token - burn the vault and calculate the fee
            Burner.burn(<-vault)
            feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        }

        /* Provision fees */
        //
        // Withdraw fee amount from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* Gather identifying information */
        //
        // Does the bridge control the EVM contract associated with this type?
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: vaultType)
            ?? panic("No EVMAddress found for vault type")
        // Convert the vault balance to a UInt256
        let bridgeAmount = FlowEVMBridgeUtils.convertCadenceAmountToERC20Amount(
                vaultBalance,
                erc20Address: associatedAddress
            )
        assert(bridgeAmount > UInt256(0), message: "Amount to bridge must be greater than 0")

        // Determine if the EVM contract is bridge-owned - affects how tokens are transmitted to recipient
        let isFactoryDeployed = FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress)

        /* Transmit tokens to recipient */
        //
        // Mint or transfer based on the bridge's EVM contract authority, making needed state assertions to confirm
        if isFactoryDeployed {
            FlowEVMBridgeUtils.mustMintERC20(to: to, amount: bridgeAmount, erc20Address: associatedAddress)
        } else {
            FlowEVMBridgeUtils.mustTransferERC20(to: to, amount: bridgeAmount, erc20Address: associatedAddress)
        }
    }

    /// Entrypoint to bridge ERC20 tokens from EVM to Cadence as FungibleToken Vaults
    ///
    /// @param owner: The EVM address of the FT owner. Current ownership and successful transfer (via
    ///     `protectedTransferCall`) is validated before the bridge request is executed.
    /// @param calldata: Caller-provided approve() call, enabling contract COA to operate on FT in EVM contract
    /// @param amount: The amount of tokens to be bridged
    /// @param evmContractAddress: Address of the EVM address defining the FT being bridged - also call target
    /// @param feeProvider: A reference to a FungibleToken Provider from which the bridging fee is withdrawn in $FLOW
    /// @param protectedTransferCall: A function that executes the transfer of the FT from the named owner to the
    ///     bridge's COA. This function is expected to return a Result indicating the status of the transfer call.
    ///
    /// @returns The bridged fungible token Vault
    ///
    access(account)
    fun bridgeTokensFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        amount: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (): EVM.ResultDecoded
    ): @{FungibleToken.Vault} {
        pre {
            !FlowEVMBridgeConfig.isPaused(): "Bridge operations are currently paused"
            !type.isSubtype(of: Type<@{NonFungibleToken.Collection}>()): "Mixed asset types are not yet supported"
            self.typeRequiresOnboarding(type) == false: "FungibleToken must first be onboarded"
            FlowEVMBridgeConfig.isTypePaused(type) == false: "Bridging is currently paused for this token"
        }
        /* Provision fees */
        //
        // Withdraw from feeProvider and deposit to self
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* TokenHandler case coverage */
        //
        // Some tokens pre-dating bridge require special case handling. If such a case, fulfill via the related handler
        if FlowEVMBridgeConfig.typeHasTokenHandler(type) {
            //  - borrow handler and passthrough to fulfill
            let handler = FlowEVMBridgeConfig.borrowTokenHandler(type)
                ?? panic("Could not retrieve handler for the given type")
            return <-handler.fulfillTokensFromEVM(
                owner: owner,
                type: type,
                amount: amount,
                protectedTransferCall: protectedTransferCall
            )
        }

        /* Gather identifying information */
        //
        // Get the EVMAddress of the ERC20 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        // Find the Cadence defining address and contract name
        let definingAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        let definingContractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
        // Convert the amount to a ufix64 so the amount can be settled on the Cadence side
        let ufixAmount = FlowEVMBridgeUtils.convertERC20AmountToCadenceAmount(amount, erc20Address: associatedAddress)
        assert(ufixAmount > 0.0, message: "Amount to bridge must be greater than 0")

        /* Execute the transfer call and make needed state assertions */
        //
        FlowEVMBridgeUtils.mustEscrowERC20(
            owner: owner,
            amount: amount,
            erc20Address: associatedAddress,
            protectedTransferCall: protectedTransferCall
        )

        /* Bridge-defined tokens are minted in Cadence */
        //
        // If the Cadence Vault is bridge-defined, mint the tokens
        if definingAddress == self.account.address {
            let minter = getAccount(definingAddress).contracts.borrow<&{IEVMBridgeTokenMinter}>(name: definingContractName)!
            return <- minter.mintTokens(amount: ufixAmount)
        }

        /* Cadence-native tokens are withdrawn from escrow */
        //
        // Confirm the EVM defining contract is bridge-owned before burning tokens
        assert(
            FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress),
            message: "Unexpected error bridging FT from EVM"
        )
        // Burn the EVM tokens that have now been transferred to the bridge in EVM
        let burnResult = FlowEVMBridgeUtils.callWithSigAndArgs(
            signature: "burn(uint256)",
            targetEVMAddress: associatedAddress,
            args: [amount],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(burnResult.status == EVM.Status.successful, message: "Burn of EVM tokens failed")

        // Unlock from escrow and return
        return <-FlowEVMBridgeTokenEscrow.unlockTokens(type: type, amount: ufixAmount)
    }

    /**************************
        Public Getters
    **************************/

    /// Returns the EVM address associated with the provided type
    ///
    access(all)
    view fun getAssociatedEVMAddress(with type: Type): EVM.EVMAddress? {
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
    }

    /// Retrieves the bridge contract's COA EVMAddress
    ///
    /// @returns The EVMAddress of the bridge contract's COA orchestrating actions in FlowEVM
    ///
    access(all)
    view fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return FlowEVMBridgeUtils.borrowCOA().address()
    }

    /// Returns whether an asset needs to be onboarded to the bridge
    ///
    /// @param type: The Cadence Type of the asset
    ///
    /// @returns Whether the asset needs to be onboarded
    ///
    access(all)
    view fun typeRequiresOnboarding(_ type: Type): Bool? {
        if !FlowEVMBridgeUtils.isValidCadenceAsset(type: type) {
            return nil
        }
        return FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) == nil &&
            !FlowEVMBridgeConfig.typeHasTokenHandler(type)
    }

    /// Returns whether an EVM-native asset needs to be onboarded to the bridge
    ///
    /// @param address: The EVMAddress of the asset
    ///
    /// @returns Whether the asset needs to be onboarded, nil if the defined asset is not supported by this bridge
    ///
    access(all)
    fun evmAddressRequiresOnboarding(_ address: EVM.EVMAddress): Bool? {
        // See if the bridge already has a known type associated with the given address
        if FlowEVMBridgeConfig.getTypeAssociated(with: address) != nil {
            return false
        }
        // Dealing with EVM-native asset, check if it's NFT or FT exclusively
        if FlowEVMBridgeUtils.isValidEVMAsset(evmContractAddress: address) {
            return true
        }
        // Not onboarded and not a valid asset, so return nil
        return nil
    }

    /**************************
        Internal Helpers
    ***************************/

    /// Deploys templated EVM contract via Solidity Factory contract supporting bridging of a given asset type
    ///
    /// @param forAssetType: The Cadence Type of the asset
    ///
    /// @returns The EVMAddress of the deployed contract
    ///
    access(self)
    fun deployEVMContract(forAssetType: Type): FlowEVMBridgeUtils.EVMOnboardingValues {
        pre {
            FlowEVMBridgeUtils.isValidCadenceAsset(type: forAssetType):
                "Asset type is not supported by the bridge"
        }
        let isNFT = forAssetType.isSubtype(of: Type<@{NonFungibleToken.NFT}>())

        let onboardingValues = FlowEVMBridgeUtils.getCadenceOnboardingValues(forAssetType: forAssetType)

        let deployedContractAddress = FlowEVMBridgeUtils.mustDeployEVMContract(
                name: onboardingValues.name,
                symbol: onboardingValues.symbol,
                cadenceAddress: onboardingValues.contractAddress,
                flowIdentifier: onboardingValues.identifier,
                contractURI: onboardingValues.contractURI,
                isERC721: isNFT
            )

        // Associate the deployed contract with the given type & return the deployed address
        FlowEVMBridgeConfig.associateType(forAssetType, with: deployedContractAddress)
        return FlowEVMBridgeUtils.EVMOnboardingValues(
            evmContractAddress: deployedContractAddress,
            name: onboardingValues.name,
            symbol: onboardingValues.symbol,
            decimals: isNFT ? nil : FlowEVMBridgeConfig.defaultDecimals,
            contractURI: onboardingValues.contractURI,
            cadenceContractName: FlowEVMBridgeUtils.getContractName(fromType: forAssetType)!,
            isERC721: isNFT
        )
    }

    /// Helper for deploying templated defining contract supporting EVM-native asset bridging to Cadence
    /// Deploys either NFT or FT contract depending on the provided type
    ///
    /// @param evmContractAddress: The EVMAddress currently defining the asset to be bridged
    ///
    access(self)
    fun deployDefiningContract(evmContractAddress: EVM.EVMAddress) {
        // Gather identifying information about the EVM contract
        let evmOnboardingValues = FlowEVMBridgeUtils.getEVMOnboardingValues(evmContractAddress: evmContractAddress)

        // Get Cadence code from template & deploy to the bridge account
        let cadenceCode: [UInt8] = FlowEVMBridgeTemplates.getBridgedAssetContractCode(
                evmOnboardingValues.cadenceContractName,
                isERC721: evmOnboardingValues.isERC721
            ) ?? panic("Problem retrieving code for Cadence-defining contract")
        if evmOnboardingValues.isERC721 {
            self.account.contracts.add(
                name: evmOnboardingValues.cadenceContractName,
                code: cadenceCode,
                evmOnboardingValues.name,
                evmOnboardingValues.symbol,
                evmContractAddress,
                evmOnboardingValues.contractURI
            )
        } else {
            self.account.contracts.add(
                name: evmOnboardingValues.cadenceContractName,
                code: cadenceCode,
                evmOnboardingValues.name,
                evmOnboardingValues.symbol,
                evmOnboardingValues.decimals!,
                evmContractAddress, evmOnboardingValues.contractURI
            )
        }

        emit BridgeDefiningContractDeployed(
            contractName: evmOnboardingValues.cadenceContractName,
            assetName: evmOnboardingValues.name,
            symbol: evmOnboardingValues.symbol,
            isERC721: evmOnboardingValues.isERC721,
            evmContractAddress: evmContractAddress.toString()
        )
    }

    /// Escrows the provided NFT and withdraws the bridging fee on the basis of a base fee + storage fee
    ///
    access(self)
    fun escrowNFTAndWithdrawFee(
        token: @{NonFungibleToken.NFT},
        from: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        // Lock the NFT & calculate the storage used by the NFT
        let storageUsed = FlowEVMBridgeNFTEscrow.lockNFT(<-token)
        // Calculate the bridge fee on current rates
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: storageUsed)
        // Withdraw fee from feeProvider and deposit
        FlowEVMBridgeUtils.depositFee(from, feeAmount: feeAmount)
    }

    /// Handle permissionlessly onboarded NFTs where the bridge deployed and manages the non-native contract
    ///
    access(self)
    fun handleDefaultNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        /* Gather identifying information */
        //
        let tokenType = token.getType()
        let tokenID = token.id
        let evmID = CrossVMNFT.getEVMID(from: &token as &{NonFungibleToken.NFT}) ?? UInt256(token.id)

        /* Metadata assignment */
        //
        // Grab the URI from the NFT if available
        var uri: String = ""
        var symbol: String = ""
        // Default to project-specified URI
        if let metadata = token.resolveView(Type<MetadataViews.EVMBridgedMetadata>()) as! MetadataViews.EVMBridgedMetadata? {
            uri = metadata.uri.uri()
            symbol = metadata.symbol
        } else {
            // Otherwise, serialize the NFT
            uri = SerializeMetadata.serializeNFTMetadataAsURI(&token as &{NonFungibleToken.NFT})
        }

        /* Secure NFT in escrow & deposit calculated fees */
        //
        // Withdraw fee from feeProvider and deposit
        self.escrowNFTAndWithdrawFee(token: <-token, from: feeProvider)

        /* Determine EVM handling */
        //
        // Does the bridge control the EVM contract associated with this type?
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: tokenType)
            ?? panic("No EVMAddress found for token type")
        let isFactoryDeployed = FlowEVMBridgeUtils.isEVMContractBridgeOwned(evmContractAddress: associatedAddress)

        /* Third-party controlled ERC721 handling */
        //
        // Not bridge-controlled, transfer existing ownership
        if !isFactoryDeployed {
            FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: associatedAddress, to: to, id: evmID)
            return
        }

        /* Bridge-owned ERC721 handling */
        //
        // Check if the ERC721 exists in the EVM contract - determines if bridge mints or transfers
        let exists = FlowEVMBridgeUtils.erc721Exists(erc721Address: associatedAddress, id: evmID)
        if exists {
            // Transfer the existing NFT & update the URI to reflect current metadata
            FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: associatedAddress, to: to, id: evmID)
            FlowEVMBridgeUtils.mustUpdateTokenURI(erc721Address: associatedAddress, id: evmID, uri: uri)
        } else {
            // Otherwise mint with current URI
            FlowEVMBridgeUtils.mustSafeMintERC721(erc721Address: associatedAddress, to: to, id: evmID, uri: uri)
        }
        // Update the bridged ERC721 symbol if different than the Cadence-defined EVMBridgedMetadata.symbol
        if symbol.length > 0 && symbol != FlowEVMBridgeUtils.getSymbol(evmContractAddress: associatedAddress) {
            FlowEVMBridgeUtils.tryUpdateSymbol(associatedAddress, symbol: symbol)
        }
        
    }

    /// Handler to move registered cross-VM NFTs to EVM
    ///
    access(self)
    fun handleCrossVMNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}) {
        let evmPointer = FlowEVMBridgeCustomAssociations.getEVMPointerAsRegistered(forType: token.getType())
            ?? panic("Could not find custom association for cross-VM NFT \(token.getType().identifier) with id \(token.id). Ensure this NFT has been registered as a cross-VM.")
        return evmPointer.nativeVM == CrossVMMetadataViews.VM.Cadence ?
            self.handleCadenceNativeCrossVMNFTToEVM(token: <-token, to: to, feeProvider: feeProvider) :
            self.handleEVMNativeCrossVMNFTToEVM(token: <-token, to: to, feeProvider: feeProvider)
    }

    /// Handler to move registered cross-VM Cadence-native NFTs to EVM
    ///
    access(self)
    fun handleCadenceNativeCrossVMNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        let type = token.getType()
        let id = UInt256(token.id)

        // Check on permissionlessly onboarded association & bridged token existence
        if let bridgedERC721 = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: type) {
            // Burn bridged ERC721 if exists - will be replaced by custom ERC721 implementation
            if FlowEVMBridgeUtils.erc721Exists(erc721Address: bridgedERC721, id: id) {
                FlowEVMBridgeUtils.mustBurnERC721(erc721Address: bridgedERC721, id: id)
            }
        }
        // Make ICrossVMBridgeERC721Fulfillment.fulfillToEVM call, passing any metadata resolved by the NFT allowing
        // the ERC721 implementation to update metadata if needed. The base CrossVMBridgeERC721Fulfillment contract
        // checks for existence and mints if needed or transfers from vm bridge escrow, following a mint/escrow
        // pattern.
        let customERC721 = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type)!
        let data = CrossVMMetadataViews.getEVMBytesMetadata(&token as &{ViewResolver.Resolver})
        FlowEVMBridgeUtils.mustFulfillNFTToEVM(erc721Address: customERC721, to: to, id: id, maybeBytes: data?.bytes)

        // Escrow the NFT & charge the bridge fee
        self.escrowNFTAndWithdrawFee(token: <-token, from: feeProvider)
    }

    /// Handler to move cross-VM EVM-native NFTs to EVM
    ///
    access(self)
    fun handleEVMNativeCrossVMNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        if !FlowEVMBridgeUtils.isCadenceNative(type: token.getType()) {
            // Bridge-defined token means this is a bridged token - passthrough to appropriate handler method
            return self.handleUpdatedBridgedNFTToEVM(token: <-token, to: to, feeProvider: feeProvider)
        }
        let type = token.getType()
        let id = UInt256(token.id)
        let customERC721 = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: token.getType())!

        // Escrow the NFT & charge the bridge fee
        self.escrowNFTAndWithdrawFee(token: <-token, from: feeProvider)

        // Transfer the ERC721 from escrow to the named recipient
        FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: customERC721, to: to, id: id)
    }

    /// Handler to move NFTs to EVM that were once bridge-defined but were later updated to a registered custom
    /// cross-VM implementation
    ///
    access(self)
    fun handleUpdatedBridgedNFTToEVM(
        token: @{NonFungibleToken.NFT},
        to: EVM.EVMAddress,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}
    ) {
        pre {
            !FlowEVMBridgeUtils.isCadenceNative(type: token.getType()):
            "Expected a bridge-defined NFT but was provided NFT of type \(token.getType().identifier)"
        }
        let bridgedAssociation = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: token.getType())!
        let updatedCadenceAssociation = FlowEVMBridgeCustomAssociations.getTypeAssociated(with: bridgedAssociation)
            ?? panic("Could not find a custom cross-VM association for NFT \(token.getType().identifier) #\(token.id). The handleUpdatedBridgedNFTToEVM route is intended for bridged Cadence NFTs associated with  ERC721 contracts that have registered as a custom cross-VM NFT collection.")

        // Ensure the updated/custom type is not paused - the top-level pause check only covers the
        // caller-supplied bridge-defined type, so we must re-check here after resolving the migration target
        assert(FlowEVMBridgeConfig.isTypePaused(updatedCadenceAssociation) == false,
            message: "Bridging is currently paused for type \(updatedCadenceAssociation.identifier)")

        // The force-casts to CrossVMNFT.EVMNFT below are safe: this handler is only reached when the token is a
        // bridge-defined NFT (pre-condition enforces !isCadenceNative). All bridge-defined NFTs are deployed from
        // the bridge's template contract, which unconditionally implements CrossVMNFT.EVMNFT. No user-controlled
        // contract can produce a bridge-defined type, so these casts cannot fail in practice.
        let tokenRef = (&token as &{NonFungibleToken.NFT}) as! &{CrossVMNFT.EVMNFT}
        let evmID = tokenRef.evmID
        let bridgedToken <- token as! @{CrossVMNFT.EVMNFT}
        emit BridgedNFTBurned(
            type: bridgedToken.getType().identifier,
            id: bridgedToken.id,
            evmID: bridgedToken.evmID,
            uuid: bridgedToken.uuid,
            erc721Address: bridgedAssociation.toString()
        )
        Burner.burn(<-bridgedToken)
        // No bridge fee is charged here. The bridge burns the legacy Cadence NFT and releases the ERC721 from
        // EVM-side escrow — no new assets are added to bridge storage, so no storage cost is incurred.
        // Transfer the ERC721 from escrow to the named recipient
        FlowEVMBridgeUtils.mustSafeTransferERC721(erc721Address: bridgedAssociation, to: to, id: evmID)
    }

    /// Handle permissionlessly onboarded NFTs where the bridge deployed and manages the non-native contract
    ///
    access(self)
    fun handleDefaultNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        /* Provision fee */
        //
        // Withdraw from feeProvider and deposit to self
        let feeAmount = FlowEVMBridgeUtils.calculateBridgeFee(bytes: 0)
        FlowEVMBridgeUtils.depositFee(feeProvider, feeAmount: feeAmount)

        /* Execute escrow transfer */
        //
        // Get the EVMAddress of the ERC721 contract associated with the type
        let associatedAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)
            ?? panic("No EVMAddress found for token type")
        // Execute the transfer call and make needed state assertions to confirm escrow from named owner
        FlowEVMBridgeUtils.mustEscrowERC721(
            owner: owner,
            id: id,
            erc721Address: associatedAddress,
            protectedTransferCall: protectedTransferCall
        )

        /* Gather identifying info */
        //
        // Derive the defining Cadence contract name & address & attempt to borrow it as IEVMBridgeNFTMinter
        let contractName = FlowEVMBridgeUtils.getContractName(fromType: type)!
        let contractAddress = FlowEVMBridgeUtils.getContractAddress(fromType: type)!
        let nftContract = getAccount(contractAddress).contracts.borrow<&{IEVMBridgeNFTMinter}>(name: contractName)
        // Get the token URI from the ERC721 contract
        let uri = FlowEVMBridgeUtils.getTokenURI(evmContractAddress: associatedAddress, id: id)

        /* Unlock escrowed NFTs */
        //
        // If the NFT is currently locked, unlock and return
        if let cadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
            let nft <- FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: cadenceID)

            // If the NFT is bridge-defined, update the URI from the source ERC721 contract
            if self.account.address == FlowEVMBridgeUtils.getContractAddress(fromType: type) {
                nftContract!.updateTokenURI(evmID: id, newURI: uri)
            }

            return <-nft
        }

        /* Mint bridge-defined NFT */
        //
        // Ensure the NFT is bridge-defined
        assert(self.account.address == contractAddress, message: "Unexpected error bridging NFT from EVM")

        // We expect the NFT to be minted in Cadence as it is bridge-defined
        let nft <- nftContract!.mintNFT(id: id, tokenURI: uri)
        return <-nft
    }

    /// Handler to move registered cross-VM NFTs from EVM
    ///
    access(self)
    fun handleCrossVMNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        let evmPointer = FlowEVMBridgeCustomAssociations.getEVMPointerAsRegistered(forType: type)
            ?? panic("Could not find custom association for cross-VM NFT \(type.identifier) with id \(id). Ensure this NFT has been registered as a cross-VM.")
        if evmPointer.nativeVM == CrossVMMetadataViews.VM.Cadence {
            return <- self.handleCadenceNativeCrossVMNFTFromEVM(
                owner: owner,
                type: type,
                id: id,
                feeProvider: feeProvider,
                protectedTransferCall: protectedTransferCall
            )
        } else { // EVM-native case as there are only two possible VMs
            return <- self.handleEVMNativeCrossVMNFTFromEVM(
                owner: owner,
                type: type,
                id: id,
                feeProvider: feeProvider,
                protectedTransferCall: protectedTransferCall
            )
        }
    }

    /// Handler to move registered Cadence-native cross-VM NFTs from EVM
    ///
    access(self)
    fun handleCadenceNativeCrossVMNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        pre {
            FlowEVMBridgeUtils.isCadenceNative(type: type):
            "Attempting to move bridge-defined NFT type \(type.identifier) from EVM as Cadence-native via handleCadenceNativeCrossVMNFTFromEVM"
        }
        let configInfo = FlowEVMBridgeCustomAssociations.getCustomConfigInfo(forType: type)!
        let customERC721 = configInfo.evmPointer.evmContractAddress
        let bridgedAssociation = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: type)
        let bridgedTokenExists = bridgedAssociation != nil ? FlowEVMBridgeUtils.erc721Exists(erc721Address: bridgedAssociation!, id: id) : false
        if configInfo.updatedFromBridged && bridgedTokenExists {
            let bridgedTokenOwner = FlowEVMBridgeUtils.ownerOf(id: id, evmContractAddress: bridgedAssociation!)!
            if bridgedTokenOwner.equals(owner) {
                FlowEVMBridgeUtils.mustEscrowERC721(
                    owner: owner,
                    id: id,
                    erc721Address: bridgedAssociation!,
                    protectedTransferCall: protectedTransferCall
                )
            } else if bridgedTokenOwner.equals(customERC721) {
                // Bridged token owned by custom ERC721 - treat as OpenZeppelin's ERC721Wrapper, escrow & unwrap
                FlowEVMBridgeUtils.mustEscrowERC721(
                    owner: owner,
                    id: id,
                    erc721Address: customERC721,
                    protectedTransferCall: protectedTransferCall
                )
                FlowEVMBridgeUtils.mustUnwrapERC721(
                    id: id,
                    erc721WrapperAddress: customERC721,
                    underlyingEVMAddress: bridgedAssociation!
                )
            } else {
                // Bridged token not wrapped nor owned by caller - could not determine owner
                panic("Bridged ERC721 \(bridgedAssociation!.toString()) ID \(id) still exists after \(type.identifier) was updated to associate with ERC721 \(customERC721.toString()), but the bridged token is neither wrapped nor owned by caller \(owner.toString()). Could not determine owner.")
            }
            // Burn the bridged ERC721, taking the bridged representation out of circulation in favor of custom ERC721
            FlowEVMBridgeUtils.mustBurnERC721(erc721Address: bridgedAssociation!, id: id)
        } else {
            FlowEVMBridgeUtils.mustEscrowERC721(
                owner: owner,
                id: id,
                erc721Address: customERC721,
                protectedTransferCall: protectedTransferCall
            )
        }
        // No bridge fee is charged here. The bridge is releasing a Cadence-native NFT from existing escrow — the
        // storage cost was already accounted for when the NFT was escrowed on the ToEVM path. Unlocking reduces
        // bridge storage rather than increasing it, so no new fee is warranted.
        // Cadence-native NFTs must be in escrow, so unlock & return
        let lockedCadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id)
            ?? panic("NFT of type \(type.identifier) with EVM ID \(id) is not in escrow — cannot bridge from EVM")
        return <-FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: lockedCadenceID)
    }

    /// Handler to move registered cross-VM EVM-native NFTs from EVM
    ///
    /// Note on `_type` vs `type`: this handler is only reached via `handleCrossVMNFTFromEVM`, which is dispatched
    /// when `customAssocByType != nil` — meaning the caller-supplied `type` is always the custom cross-VM type,
    /// not a legacy bridge-defined type. Therefore `isCadenceNative(type)` is always true for this handler, the
    /// `if !isCadenceNative` branch below is never entered, and `_type` is never reassigned away from `type`.
    /// The `isLocked` check and the `unlockNFT`/`fulfillNFTFromEVM` calls therefore always use the same type.
    ///
    access(self)
    fun handleEVMNativeCrossVMNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        pre {
            id <= UInt256(UInt64.max):
            "NFT ID \(id) is greater than the maximum Cadence ID \(UInt64.max) - cannot fulfill this NFT from EVM"
        }
        var _type = type
        let erc721Address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type)!

        // Burn if NFT is found to be bridge-defined as it's to be replaced by the registered custom cross-VM NFT
        if !FlowEVMBridgeUtils.isCadenceNative(type: type) {
            // Find and assign the updated custom Cadence NFT Type associated with the EVM-native ERC721
            _type = FlowEVMBridgeConfig.getTypeAssociated(with: erc721Address)!

            // Burn the bridged NFT token if it's locked
            if let cadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
                let bridgedToken <- FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: cadenceID) as! @{CrossVMNFT.EVMNFT}
                emit BridgedNFTBurned(
                    type: bridgedToken.getType().identifier,
                    id: bridgedToken.id,
                    evmID: bridgedToken.evmID,
                    uuid: bridgedToken.uuid,
                    erc721Address: erc721Address.toString()
                )
                Burner.burn(<-bridgedToken)
            }
        }

        FlowEVMBridgeUtils.mustEscrowERC721(owner: owner, id: id, erc721Address: erc721Address, protectedTransferCall: protectedTransferCall)

        // No bridge fee is charged here. EVM-native NFTs are fulfilled either by unlocking from existing Cadence
        // escrow (reducing bridge storage) or by minting via the project-provided NFTFulfillmentMinter (no bridge
        // storage involved). In neither case does the bridge account incur a new storage cost.
        if FlowEVMBridgeNFTEscrow.isLocked(type: type, id: UInt64(id)) {
            // Unlock the NFT from escrow
            return <-FlowEVMBridgeNFTEscrow.unlockNFT(type: _type, id: UInt64(id))
        } else {
            // Otherwise, fulfill via configured NFTFulfillmentMinter
            return <- FlowEVMBridgeCustomAssociations.fulfillNFTFromEVM(forType: _type, id: id)
        }
    }

    access(self)
    fun handleUpdatedBridgedNFTFromEVM(
        owner: EVM.EVMAddress,
        type: Type,
        id: UInt256,
        feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider},
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ): @{NonFungibleToken.NFT} {
        pre {
            !FlowEVMBridgeUtils.isCadenceNative(type: type): // expect this type to be bridge-defined
            "Expected a bridge-defined NFT but was provided NFT of type \(type.identifier)"
            id < UInt256(UInt64.max):
            "Requested ID \(id) exceeds UIn64.max - Cross-VM NFT IDs must be within UInt64 range across Cadence & EVM implementations"
        }
        // Assign the legacy and custom associations
        let bridgedAssoc = FlowEVMBridgeConfig.getLegacyEVMAddressAssociated(with: type)!
        let updatedTypeAssoc = FlowEVMBridgeConfig.getTypeAssociated(with: bridgedAssoc)!

        // Ensure the updated/custom type is not paused - the top-level pause check only covers the
        // caller-supplied legacy type, so we must re-check here after resolving the migration target
        assert(FlowEVMBridgeConfig.isTypePaused(updatedTypeAssoc) == false,
            message: "Bridging is currently paused for type \(updatedTypeAssoc.identifier)")

        // Confirm custom association is EVM-native
        let configInfo = FlowEVMBridgeCustomAssociations.getCustomConfigInfo(forType: updatedTypeAssoc)!
        assert(configInfo.evmPointer.nativeVM == CrossVMMetadataViews.VM.EVM,
            message: "Expected native VM for ERC721 \(bridgedAssoc.toString()) associated with NFT type \(type.identifier) to be EVM-native")

        FlowEVMBridgeUtils.mustEscrowERC721(owner: owner, id: id, erc721Address: bridgedAssoc, protectedTransferCall: protectedTransferCall)

        // Check if originally associated bridged token is in escrow, burning if so
        if let lockedCadenceID = FlowEVMBridgeNFTEscrow.getLockedCadenceID(type: type, evmID: id) {
            let bridgedToken <- FlowEVMBridgeNFTEscrow.unlockNFT(type: type, id: lockedCadenceID) as! @{CrossVMNFT.EVMNFT}
            emit BridgedNFTBurned(
                type: bridgedToken.getType().identifier,
                id: bridgedToken.id,
                evmID: bridgedToken.evmID,
                uuid: bridgedToken.uuid,
                erc721Address: bridgedAssoc.toString()
            )
            Burner.burn(<-bridgedToken)
        }
        // No bridge fee is charged here. The legacy bridge-defined NFT (if present in escrow) is burned, and the
        // custom type NFT is either unlocked from existing escrow or minted via the project's NFTFulfillmentMinter.
        // In all cases the bridge is releasing or burning assets rather than storing new ones, so no storage cost
        // is incurred and no fee is warranted.
        // Either unlock if locked or fulfill via configured NFTFulfillmentMinter
        if FlowEVMBridgeNFTEscrow.isLocked(type: updatedTypeAssoc, id: UInt64(id)) {
            return <- FlowEVMBridgeNFTEscrow.unlockNFT(type: updatedTypeAssoc, id: UInt64(id))
        } else {
            return <- FlowEVMBridgeCustomAssociations.fulfillNFTFromEVM(forType: updatedTypeAssoc, id: id)
        }
    }
}
