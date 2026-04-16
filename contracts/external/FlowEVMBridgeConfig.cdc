import "EVM"
import "NonFungibleToken"

import "FlowEVMBridgeHandlerInterfaces"
import "FlowEVMBridgeCustomAssociations"

/// This contract is used to store configuration information shared by FlowEVMBridge contracts
///
access(all)
contract FlowEVMBridgeConfig {

    /******************
        Entitlements
    *******************/

    access(all) entitlement Gas
    access(all) entitlement Fee
    access(all) entitlement Pause
    access(all) entitlement Blocklist

    /*************
        Fields
    **************/

    /// Amount of FLOW paid to onboard a Type or EVMAddress to the bridge
    access(all)
    var onboardFee: UFix64
    /// Flat rate fee for all bridge requests
    access(all)
    var baseFee: UFix64
    /// Default ERC20.decimals() value
    access(all)
    let defaultDecimals: UInt8
    /// The gas limit for all EVM calls related to bridge operations
    access(all)
    var gasLimit: UInt64
    /// Flag enabling pausing of bridge operations
    access(self)
    var paused: Bool
    /// Mapping of Type to its associated EVMAddress. The contained struct values also store the operational status of
    /// the association, allowing for pausing of operations by Type
    access(self) let registeredTypes: {Type: TypeEVMAssociation}
    /// Reverse mapping of registeredTypes. Note the EVMAddress is stored as a hex string since the EVMAddress type
    /// as of contract development is not a hashable or equatable type and making it so is not supported by Cadence
    access(self)
    let evmAddressHexToType: {String: Type}
    /// Mapping of Type to its associated EVMAddress as relevant to the bridge
    access(self)
    let typeToTokenHandlers: @{Type: {FlowEVMBridgeHandlerInterfaces.TokenHandler}}

    /********************
        Path Constants
    *********************/

    /// StoragePath where bridge Cadence Owned Account is stored
    access(all)
    let coaStoragePath: StoragePath
    /// StoragePath where bridge config Admin is stored
    access(all)
    let adminStoragePath: StoragePath
    /// PublicPath where a public Capability on the bridge config Admin is exposed
    access(all)
    let adminPublicPath: PublicPath
    /// StoragePath to store the Provider capability used as a bridge fee Provider
    access(all)
    let providerCapabilityStoragePath: StoragePath

    /*************
        Events
    **************/

    /// Emitted whenever the onboarding fee is updated
    ///
    access(all)
    event BridgeFeeUpdated(old: UFix64, new: UFix64, isOnboarding: Bool)
    /// Emitted whenever a TokenHandler is configured
    ///
    access(all)
    event HandlerConfigured(targetType: String, targetEVMAddress: String?, isEnabled: Bool)
    /// Emitted whenever the bridge is paused or unpaused globally - true for paused, false for unpaused
    ///
    access(all)
    event BridgePauseStatusUpdated(paused: Bool)
    /// Emitted whenever a specific asset is paused or unpaused - true for paused, false for unpaused
    ///
    access(all)
    event AssetPauseStatusUpdated(paused: Bool, type: String, evmAddress: String)
    /// Emitted whenever an association is updated
    ///
    access(all)
    event AssociationUpdated(type: String, evmAddress: String)

    /*************
        Getters
     *************/

    /// Returns whether all bridge operations are currently paused or active
    ///
    access(all)
    view fun isPaused(): Bool {
        return self.paused
    }

    /// Returns whether operations for a given Type are paused.
    ///
    /// Note: the return type is `Bool?` for API compatibility, but this function currently always returns a
    /// non-nil `Bool`. The three sub-expressions all produce concrete `Bool` values via nil-coalescing or direct
    /// comparison. A `nil` return cannot occur under current logic. Call sites should use `== false` (rather than
    /// `!= true`) so that a hypothetical future `nil` is treated conservatively as "paused" rather than
    /// "not paused". The doc comment claim that `nil` means "not yet onboarded" does not reflect actual behavior
    /// and is retained only for historical reference.
    ///
    access(all)
    view fun isTypePaused(_ type: Type): Bool? {
        // Paused if the type has a token handler & it's disabled, a custom config has been paused or the bridge config has been paused
        return !(self.borrowTokenHandler(type)?.isEnabled() ?? true)
            || FlowEVMBridgeCustomAssociations.isCustomConfigPaused(forType: type) ?? false
            || self.registeredTypes[type]?.isPaused == true
    }

    /// Retrieves the EVMAddress associated with a given Type if it has been onboarded to the bridge
    ///
    access(all)
    view fun getEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        if self.typeHasTokenHandler(type) {
            return self.borrowTokenHandler(type)!.getTargetEVMAddress()
        }
        let customAssociation = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type)
        return customAssociation ?? self.registeredTypes[type]?.evmAddress
    }

    /// Retrieves the type associated with a given EVMAddress if it has been onboarded to the bridge
    ///
    access(all)
    view fun getTypeAssociated(with evmAddress: EVM.EVMAddress): Type? {
        let evmAddressHex = evmAddress.toString()
        let customAssociation = FlowEVMBridgeCustomAssociations.getTypeAssociated(with: evmAddress)
        return customAssociation ?? self.evmAddressHexToType[evmAddressHex]
    }

    /// Returns whether the given EVMAddress is currently blocked from onboarding to the bridge
    ///
    access(all)
    view fun isEVMAddressBlocked(_ evmAddress: EVM.EVMAddress): Bool {
        return self.borrowEVMBlocklist().isBlocked(evmAddress)
    }

    /// Returns whether the given Cadence Type is currently blocked from onboarding to the bridge
    ///
    access(all)
    view fun isCadenceTypeBlocked(_ type: Type): Bool {
        return self.borrowCadenceBlocklist().isBlocked(type)
    }

    /// Returns the project-defined Type has been registered as a replacement for the originally bridge-defined asset
    /// type. This would arise in the event an EVM-native project onboarded to the bridge via permissionless onboarding
    /// & later registered their own Cadence NFT contract as associated with their ERC721 per FLIP-318 mechanisms.
    /// If there is not a related custom cross-VM Type registered with the bridge, `nil` is returned.
    ///
    access(all)
    view fun getUpdatedCustomCrossVMTypeForLegacyType(_ type: Type): Type? {
        if !type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) || type.address! != self.account.address {
            // only bridge-defined NFT Types can have an updated custom cross-VM implementation
            return nil
        }
        if let legacyEVMAssoc = self.getLegacyEVMAddressAssociated(with: type) {
            // return the new Type associated with the originally associated EVM contract address
            return FlowEVMBridgeCustomAssociations.getTypeAssociated(with: legacyEVMAssoc)
        }
        return nil
    }

    /// Returns the bridge-defined Type that was originally associated with the related EVM contract given some
    /// externally defined contract. This would arise in the event an EVM-native project onboarded to the bridge via
    /// permissionless onboarding & later registered their own Cadence NFT contract as associated with their ERC721 per
    /// FLIP-318 mechanisms. If there is not a related bridge-defined Type registered with the bridge, `nil` is returned.
    ///
    access(all)
    view fun getLegacyTypeForCustomCrossVMType(_ type: Type): Type? {
        if !type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) || type.address! == self.account.address {
            // only externally-defined NFT Types can have an updated custom cross-VM implementation
            return nil
        }
        if let customEVMAssoc = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type ) {
            // return the original bridged NFT Type associated with the custom cross-VM EVM contract address
            return self.evmAddressHexToType[customEVMAssoc.toString()]
        }
        return nil
    }

    /// Returns the project-defined EVM contract address has been registered as a replacement for the originally bridge-
    /// defined asset EVM contract. This would arise in the event an Cadence-native project onboarded to the bridge via
    /// permissionless onboarding & later registered their own EVM contract as associated with their Cadence NFT per
    /// FLIP-318 mechanisms. If there is not a related custom cross-VM EVM contract registered with the bridge, `nil` is
    /// returned.
    ///
    access(all)
    view fun getUpdatedCustomCrossVMEVMAddressForLegacyEVMAddress(_ evmAddress: EVM.EVMAddress): EVM.EVMAddress? {
        if let legacyType = self.getLegacyTypeAssociated(with: evmAddress) {
            // return the new EVM address associated with the originally associated Type
            return FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: legacyType)
        }
        return nil
    }

    /// Returns the bridge-defined EVM contract address that was originally associated with the related Cadence NFT
    /// given some externally defined contract. This would arise in the event a Cadence-native project onboarded to the
    /// bridge via permissionless onboarding & later registered their own EVM contract as associated with their
    /// Cadence NFT per FLIP-318 mechanisms. If there is not a related bridge-defined EVM contract registered with the
    /// bridge, `nil` is returned.
    ///
    access(all)
    view fun getLegacyEVMAddressForCustomCrossVMAddress(_ evmAddress: EVM.EVMAddress): EVM.EVMAddress? {
        if let customType = FlowEVMBridgeCustomAssociations.getTypeAssociated(with: evmAddress) {
            // return the original bridged NFT Type associated with the custom cross-VM EVM contract address
            return self.registeredTypes[customType]?.evmAddress
        }
        return nil
    }

    /****************************
        Bridge Account Methods
     ****************************/

    /// Returns whether the given Type has a TokenHandler configured
    ///
    access(account)
    view fun typeHasTokenHandler(_ type: Type): Bool {
        return self.typeToTokenHandlers[type] != nil
    }

    /// Returns whether the given EVMAddress has a TokenHandler configured
    ///
    access(account)
    view fun evmAddressHasTokenHandler(_ evmAddress: EVM.EVMAddress): Bool {
        let associatedType = self.getTypeAssociated(with: evmAddress)
        return associatedType != nil ? self.typeHasTokenHandler(associatedType!) : false
    }

    /// Returns the Type associated with the provided EVM contract address if the association was established via
    /// the permissionless onboarding path
    ///
    access(account)
    view fun getLegacyTypeAssociated(with evmAddress: EVM.EVMAddress): Type? {
        return self.evmAddressHexToType[evmAddress.toString()] ?? nil
    }

    /// Returns the EVM contract address associated with the provided Type if the association was established via
    /// the permissionless onboarding path
    ///
    access(account)
    view fun getLegacyEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        if self.typeHasTokenHandler(type) {
            return self.borrowTokenHandler(type)!.getTargetEVMAddress()
        }
        return self.registeredTypes[type]?.evmAddress ?? nil
    }

    /// Enables bridge contracts to add new associations between types and EVM addresses
    ///
    access(account)
    fun associateType(_ type: Type, with evmAddress: EVM.EVMAddress) {
        pre {
            self.getEVMAddressAssociated(with: type) == nil:
            "Type ".concat(type.identifier).concat(" already associated with an EVMAddress ")
                .concat(self.registeredTypes[type]!.evmAddress.toString())
            self.getTypeAssociated(with: evmAddress) == nil:
            "EVMAddress ".concat(evmAddress.toString()).concat(" already associated with Type ")
                .concat(self.evmAddressHexToType[evmAddress.toString()]!.identifier)
        }
        self.registeredTypes[type] = TypeEVMAssociation(associated: evmAddress)
        let evmAddressHex = evmAddress.toString()
        self.evmAddressHexToType[evmAddressHex] = type

        emit AssociationUpdated(type: type.identifier, evmAddress: evmAddressHex)
    }

    /// Adds a TokenHandler to the bridge configuration
    ///
    access(account)
    fun addTokenHandler(_ handler: @{FlowEVMBridgeHandlerInterfaces.TokenHandler}) {
        pre {
            handler.getTargetType() != nil: "Cannot configure Handler without a target Cadence Type set"
            self.getEVMAddressAssociated(with: handler.getTargetType()!) == nil:
                "Cannot configure Handler for Type that has already been onboarded to the bridge"
            self.borrowTokenHandler(handler.getTargetType()!) == nil:
                "Cannot configure Handler for Type that already has a Handler configured"
        }
        let type = handler.getTargetType()!
        var targetEVMAddressHex: String? = nil
        if let targetEVMAddress = handler.getTargetEVMAddress() {
            targetEVMAddressHex = targetEVMAddress.toString()

            let associatedType = self.getTypeAssociated(with: targetEVMAddress)
            assert(
                associatedType == nil,
                message: "Handler target EVMAddress is already associated with a different Type"
            )
            self.associateType(type, with: targetEVMAddress)
        }

        emit HandlerConfigured(
            targetType: type.identifier,
            targetEVMAddress: targetEVMAddressHex,
            isEnabled: handler.isEnabled()
        )

        self.typeToTokenHandlers[type] <-! handler
    }

    /// Returns an unentitled reference to the TokenHandler associated with the given Type
    ///
    access(account)
    view fun borrowTokenHandler(
        _ type: Type
    ): &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToTokenHandlers[type]
    }

    /// Returns an entitled reference to the TokenHandler associated with the given Type
    ///
    access(self)
    view fun borrowTokenHandlerAdmin(
        _ type: Type
    ): auth(FlowEVMBridgeHandlerInterfaces.Admin) &{FlowEVMBridgeHandlerInterfaces.TokenHandler}? {
        return &self.typeToTokenHandlers[type]
    }

    /// Returns an entitled reference to the bridge EVMBlocklist
    ///
    access(self)
    view fun borrowEVMBlocklist(): auth(Blocklist) &EVMBlocklist {
        return self.account.storage.borrow<auth(Blocklist) &EVMBlocklist>(from: /storage/evmBlocklist)
            ?? panic("Missing or mis-typed EVMBlocklist in storage")
    }

    /// Returns an entitled reference to the bridge CadenceBlocklist
    ///
    access(self)
    view fun borrowCadenceBlocklist(): auth(Blocklist) &CadenceBlocklist {
        return self.account.storage.borrow<auth(Blocklist) &CadenceBlocklist>(from: /storage/cadenceBlocklist)
            ?? panic("Missing or mis-typed CadenceBlocklist in storage")
    }

    /// Sets the pause status of a given type, reverting if the type has no associated EVM address as either bridge-
    /// defined or registered as a custom cross-VM association
    ///
    access(self)
    fun updatePauseStatus(_ type: Type, pause: Bool) {
        var evmAddress = ""
        var updated = false
        if let customAssoc = FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type) {
            updated = FlowEVMBridgeCustomAssociations.isCustomConfigPaused(forType: type)! != pause
            // Called methods no-op internally, so check for status update is skipped here
            pause ? FlowEVMBridgeCustomAssociations.pauseCustomConfig(forType: type)
                : FlowEVMBridgeCustomAssociations.unpauseCustomConfig(forType: type)
            // Assign the EVM address based on the CustomConfig value
            evmAddress = customAssoc.toString()
        }
        if let bridgedAssoc = &FlowEVMBridgeConfig.registeredTypes[type] as &TypeEVMAssociation? {
            if evmAddress.length == 0 {
                // Assign as bridge association only if custom association does not exist
                evmAddress = bridgedAssoc.evmAddress.toString()
            }
            // No-op if already meets pause status, otherwise update as specified
            if (pause && !bridgedAssoc.isPaused) || (!pause && bridgedAssoc.isPaused) {
                updated = true
                pause ? bridgedAssoc.pause() : bridgedAssoc.unpause()
            }
        }
        assert(evmAddress.length > 0,
            message: "There was no association found for type \(type.identifier). To block the type from onboarding, use the CadenceBlocklist.")
        if updated { emit AssetPauseStatusUpdated(paused: pause, type: type.identifier, evmAddress: evmAddress) }
    }

    /*****************
        Constructs
     *****************/

    /// Entry in the registeredTypes mapping, associating a Type with an EVMAddress and its operational status. Since
    /// the registeredTypes mapping is indexed on Type, this struct does not additionally store the Type to reduce
    /// redundant storage.
    ///
    access(all) struct TypeEVMAssociation {
        /// The EVMAddress associated with the Type
        access(all) let evmAddress: EVM.EVMAddress
        /// Flag indicating whether operations for the associated Type are paused
        access(all) var isPaused: Bool

        init(associated evmAddress: EVM.EVMAddress) {
            self.evmAddress = evmAddress
            self.isPaused = false
        }

        /// Pauses operations for this association
        ///
        access(contract) fun pause() {
            self.isPaused = true
        }

        /// Unpauses operations for this association
        ///
        access(contract) fun unpause() {
            self.isPaused = false
        }
    }

    /// EVMBlocklist resource stores a mapping of EVM addresses that are blocked from onboarding to the bridge
    ///
    access(all) resource EVMBlocklist {
        /// Mapping of serialized EVM addresses to their blocked status
        ///
        access(all) let blocklist: {String: Bool}

        init() {
            self.blocklist = {}
        }

        /// Returns whether the given EVM address is blocked from onboarding to the bridge
        ///
        access(all) view fun isBlocked(_ evmAddress: EVM.EVMAddress): Bool {
            return self.blocklist[evmAddress.toString()] ?? false
        }

        /// Blocks the given EVM address from onboarding to the bridge
        ///
        access(Blocklist) fun block(_ evmAddress: EVM.EVMAddress) {
            self.blocklist[evmAddress.toString()] = true
        }

        /// Removes the given EVM address from the blocklist
        ///
        access(Blocklist) fun unblock(_ evmAddress: EVM.EVMAddress) {
            self.blocklist.remove(key: evmAddress.toString())
        }
    }

    /// CadenceBlocklist resource stores a mapping of Cadence Types that are blocked from onboarding to the bridge
    ///
    access(all) resource CadenceBlocklist {
        /// Mapping of serialized Cadence Type to their blocked status
        ///
        access(all) let blocklist: {Type: Bool}

        init() {
            self.blocklist = {}
        }

        /// Returns whether the given Type is blocked from onboarding to the bridge
        ///
        access(all) view fun isBlocked(_ type: Type): Bool {
            return self.blocklist[type] ?? false
        }

        /// Blocks the given Type from onboarding to the bridge
        ///
        access(Blocklist) fun block(_ type: Type) {
            self.blocklist[type] = true
        }

        /// Removes the given type from the blocklist
        ///
        access(Blocklist) fun unblock(_ type: Type) {
            self.blocklist.remove(key: type)
        }
    }

    /*****************
        Config Admin
     *****************/

    /// Admin resource enables updates to the bridge fees
    ///
    access(all)
    resource Admin {

        /// Sets the TokenMinter for the given Type. If a TokenHandler does not exist for the given Type, the operation
        /// reverts. The provided minter must be of the expected type for the TokenHandler and the handler cannot have
        /// a minter already set.
        ///
        /// @param targetType: Cadence type indexing the relevant TokenHandler
        /// @param minter: TokenMinter minter to set for the TokenHandler
        ///
        access(all)
        fun setTokenHandlerMinter(targetType: Type, minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            pre {
                FlowEVMBridgeConfig.typeHasTokenHandler(targetType):
                    "Cannot set minter for Type that does not have a TokenHandler configured"
                FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType) != nil:
                    "No handler found for target Type"
                FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)!.getExpectedMinterType() == minter.getType():
                    "Invalid minter type"
            }
            FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)!.setMinter(<-minter)
        }

        /// Sets the gas limit for all EVM calls related to bridge operations
        ///
        /// @param lim the new gas limit
        ///
        access(Gas)
        fun setGasLimit(_ limit: UInt64) {
            FlowEVMBridgeConfig.gasLimit = limit
        }

        /// Updates the onboarding fee
        ///
        /// @param new: UFix64 - new onboarding fee
        ///
        /// @emits BridgeFeeUpdated with the old and new rates and isOnboarding set to true
        ///
        access(Fee)
        fun updateOnboardingFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.onboardFee, new: new, isOnboarding: true)
            FlowEVMBridgeConfig.onboardFee = new
        }

        /// Updates the base fee
        ///
        /// @param new: UFix64 - new base fee
        ///
        /// @emits BridgeFeeUpdated with the old and new rates and isOnboarding set to false
        ///
        access(Fee)
        fun updateBaseFee(_ new: UFix64) {
            emit BridgeFeeUpdated(old: FlowEVMBridgeConfig.baseFee, new: new, isOnboarding: false)
            FlowEVMBridgeConfig.baseFee = new
        }

        /// Pauses the bridge, preventing all bridge operations
        ///
        /// @emits BridgePauseStatusUpdated with true
        ///
        access(Pause)
        fun pauseBridge() {
            if FlowEVMBridgeConfig.isPaused() {
                return
            }
            FlowEVMBridgeConfig.paused = true
            emit BridgePauseStatusUpdated(paused: true)
        }

        /// Unpauses the bridge, allowing bridge operations to resume
        ///
        /// @emits BridgePauseStatusUpdated with true
        ///
        access(Pause)
        fun unpauseBridge() {
            if !FlowEVMBridgeConfig.isPaused() {
                return
            }
            FlowEVMBridgeConfig.paused = false
            emit BridgePauseStatusUpdated(paused: false)
        }

        /// Pauses all operations for a given asset type
        ///
        /// @param type: The Type for which to pause bridge operations
        ///
        /// @emits AssetPauseStatusUpdated with the pause status and serialized type & associated EVM address
        ///
        access(Pause)
        fun pauseType(_ type: Type) {
            pre {
                FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) != nil || FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type) != nil:
                "Could not find a bridged or custom association for type \(type.identifier) - cannot pause a type without an association"
            }
            FlowEVMBridgeConfig.updatePauseStatus(type, pause: true)
        }

        /// Unpauses all operations for a given asset type
        ///
        /// @param type: The Type for which to unpause bridge operations
        ///
        /// @emits AssetPauseStatusUpdated with the pause status and serialized type & associated EVM address
        ///
        access(Pause)
        fun unpauseType(_ type: Type) {
            pre {
                FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) != nil || FlowEVMBridgeCustomAssociations.getEVMAddressAssociated(with: type) != nil:
                "Could not find a bridged or custom association for type \(type.identifier) - cannot unpause a type without an association"
            }
            FlowEVMBridgeConfig.updatePauseStatus(type, pause: false)
        }

        /// Sets the target EVM contract address on the handler for a given Type, associating the Cadence type with the
        /// provided EVM address. If a TokenHandler does not exist for the given Type, the operation reverts.
        ///
        /// @param targetType: Cadence type to associate with the target EVM address
        /// @param targetEVMAddress: target EVM address to associate with the Cadence type
        ///
        /// @emits HandlerConfigured with the target Type, target EVM address, and whether the handler is enabled
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun setHandlerTargetEVMAddress(targetType: Type, targetEVMAddress: EVM.EVMAddress) {
            pre {
                FlowEVMBridgeConfig.getEVMAddressAssociated(with: targetType) == nil:
                    "Type already associated with an EVM Address"
                FlowEVMBridgeConfig.getTypeAssociated(with: targetEVMAddress) == nil:
                    "EVM Address already associated with another Type"
            }
            post {
                FlowEVMBridgeConfig.getEVMAddressAssociated(with: targetType)!.equals(targetEVMAddress):
                "Problem associating target Type and target EVM Address"
            }
            FlowEVMBridgeConfig.associateType(targetType, with: targetEVMAddress)

            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
                ?? panic("No handler found for target Type")
            handler.setTargetEVMAddress(targetEVMAddress)

            emit HandlerConfigured(
                targetType: targetType.identifier,
                targetEVMAddress: targetEVMAddress.toString(),
                isEnabled: handler.isEnabled()
            )
        }

        /// Enables the TokenHandler for the given Type. If a TokenHandler does not exist for the given Type, the
        /// operation reverts.
        ///
        /// @param targetType: Cadence type indexing the relevant TokenHandler
        ///
        /// @emits HandlerConfigured with the target Type, target EVM address, and whether the handler is enabled
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun enableHandler(targetType: Type) {
            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
                ?? panic("No handler found for target Type ".concat(targetType.identifier))
            handler.enableBridging()

            let targetEVMAddressHex = handler.getTargetEVMAddress()?.toString()
                ?? panic("Handler cannot be enabled without a target EVM Address")

            emit HandlerConfigured(
                targetType: handler.getTargetType()!.identifier,
                targetEVMAddress: targetEVMAddressHex,
                isEnabled: handler.isEnabled()
            )
        }

        /// Disables the TokenHandler for the given Type. If a TokenHandler does not exist for the given Type, the
        /// operation reverts.
        ///
        /// @param targetType: Cadence type indexing the relevant TokenHandler
        ///
        /// @emits HandlerConfigured with the target Type, target EVM address, and whether the handler is enabled
        ///
        access(FlowEVMBridgeHandlerInterfaces.Admin)
        fun disableHandler(targetType: Type) {
            let handler = FlowEVMBridgeConfig.borrowTokenHandlerAdmin(targetType)
                ?? panic("No handler found for target Type".concat(targetType.identifier))
            handler.disableBridging()

            emit HandlerConfigured(
                targetType: handler.getTargetType()!.identifier,
                targetEVMAddress: handler.getTargetEVMAddress()?.toString(),
                isEnabled: handler.isEnabled()
            )
        }
    }

    init() {
        self.onboardFee = 0.0
        self.baseFee = 0.0
        self.defaultDecimals = 18
        self.gasLimit = 15_000_000
        self.paused = true

        self.registeredTypes = {}
        self.evmAddressHexToType = {}

        self.typeToTokenHandlers <- {}

        self.adminStoragePath = /storage/flowEVMBridgeConfigAdmin
        self.adminPublicPath = /public/flowEVMBridgeConfigAdmin
        self.coaStoragePath = /storage/evm
        self.providerCapabilityStoragePath = /storage/bridgeFlowVaultProvider

        // Create & save Admin, issuing a public unentitled Admin Capability
        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
        let adminCap = self.account.capabilities.storage.issue<&Admin>(self.adminStoragePath)
        self.account.capabilities.publish(adminCap, at: self.adminPublicPath)

        // Initialize the blocklists
        self.account.storage.save(<-create EVMBlocklist(), to: /storage/evmBlocklist)
        self.account.storage.save(<-create CadenceBlocklist(), to: /storage/cadenceBlocklist)
    }
}
