import NonFungibleToken from 0x1d7e57aa55817448
import CrossVMMetadataViews from 0x1d7e57aa55817448
import EVM from 0xe467b9dd11fa00df

import FlowEVMBridgeCustomAssociationTypes from 0x1e4aa0b87d10b141

/// The FlowEVMBridgeCustomAssociations is tasked with preserving custom associations between Cadence assets and their
/// EVM implementations. These associations should be validated before `saveCustomAssociation` is called by
/// leveraging the interfaces outlined in FLIP-318 (https://github.com/onflow/flips/issues/318) to ensure that the
/// declared association is valid and that neither implementation is bridge-defined.
///
access(all) contract FlowEVMBridgeCustomAssociations {

    /// Stored associations indexed by Cadence Type
    access(self) let associationsConfig: @{Type: {FlowEVMBridgeCustomAssociationTypes.CustomConfig}}
    /// Reverse lookup indexed on serialized EVM contract address
    access(self) let associationsByEVMAddress: {String: Type}

    /// Event emitted whenever a custom association is established
    access(all) event CustomAssociationEstablished(
        type: String,
        evmContractAddress: String,
        nativeVMRawValue: UInt8,
        updatedFromBridged: Bool,
        fulfillmentMinterType: String?,
        fulfillmentMinterOrigin: Address?,
        fulfillmentMinterCapID: UInt64?,
        fulfillmentMinterUUID: UInt64?,
        configUUID: UInt64
    )

    /// Retrieves the EVM address associated with the given Cadence Type if it has been registered as a cross-VM asset
    ///
    /// @param with: The Cadence Type to query against
    ///
    /// @return The EVM address configured as associated with the provided Cadence Type
    ///
    access(all)
    view fun getEVMAddressAssociated(with type: Type): EVM.EVMAddress? {
        return self.associationsConfig[type]?.getEVMContractAddress() ?? nil
    }

    /// Retrieves the Cadence Type associated with the given EVM address if it has been registered as a cross-VM asset
    ///
    /// @param with: The EVM contract address to query against
    ///
    /// @return The Cadence Type configured as associated with the provided EVM address
    ///
    access(all)
    view fun getTypeAssociated(with evmAddress: EVM.EVMAddress): Type? {
        return self.associationsByEVMAddress[evmAddress.toString()]
    }

    /// Returns an EVMPointer containing the data at the time of registration
    ///
    /// @param forType: The Cadence Type to query against
    ///
    /// @return a copy of the EVMPointer view as registered with the bridge
    ///
    access(all)
    fun getEVMPointerAsRegistered(forType: Type): CrossVMMetadataViews.EVMPointer? {
        if let config = &self.associationsConfig[forType] as &{FlowEVMBridgeCustomAssociationTypes.CustomConfig}? {
            return CrossVMMetadataViews.EVMPointer(
                cadenceType: config.getCadenceType(),
                cadenceContractAddress: config.getCadenceType().address!,
                evmContractAddress: config.getEVMContractAddress(),
                nativeVM: config.getNativeVM()
            )
        }
        return nil
    }

    /// Returns whether the related CustomConfig is currently paused or not. `nil` is returned if a CustomConfig is not
    /// found for the given Type
    ///
    /// @param forType: The Cadence Type for which to retrieve a registered CustomConfig
    ///
    /// @return true if the CustomConfig is paused, false if registered and unpaused, nil if unregistered as a custom
    ///     association
    ///
    access(all)
    view fun isCustomConfigPaused(forType: Type): Bool? {
        return self.borrowNFTCustomConfig(forType: forType)?.isPaused() ?? nil
    }

    /// Returns metadata about a registered CustomConfig
    ///
    /// @param forType: The Cadence Type of the registered cross-VM asset
    ///
    /// @return The CustomConfigInfo struct if the type is registered, nil otherwise
    ///
    access(all)
    fun getCustomConfigInfo(forType: Type): FlowEVMBridgeCustomAssociationTypes.CustomConfigInfo? {
        if let config = self.borrowNFTCustomConfig(forType: forType) {
            let fulfillmentMinterType = config.checkFulfillmentMinter() == true ? config.borrowFulfillmentMinter().getType() : nil
            return FlowEVMBridgeCustomAssociationTypes.CustomConfigInfo(
                updatedFromBridged: config.isUpdatedFromBridged(),
                isPaused: config.isPaused(),
                fulfillmentMinterType: fulfillmentMinterType,
                evmPointer: self.getEVMPointerAsRegistered(forType: forType)!
            )
        }
        return nil
    }

    /// Allows the bridge contracts to preserve a custom association. Will revert if a custom association already exists
    ///
    /// @param type: The Cadence Type of the associated asset.
    /// @param evmContractAddress: The EVM address defining the EVM implementation of the associated asset.
    /// @param nativeVM: The VM in which the asset is distributed by the project. The bridge will mint/escrow in the non-native
    ///     VM environment.
    /// @param updatedFromBridged: Whether the asset was originally onboarded to the bridge via permissionless
    ///     onboarding. In other words, whether there was first a bridge-defined implementation of the underlying asset.
    /// @param fulfillmentMinter: An authorized Capability allowing the bridge to fulfill bridge requests moving the
    ///     underlying asset from EVM. Required if the asset is EVM-native.
    ///
    access(account)
    fun saveCustomAssociation(
        type: Type,
        evmContractAddress: EVM.EVMAddress,
        nativeVM: CrossVMMetadataViews.VM,
        updatedFromBridged: Bool,
        fulfillmentMinter: Capability<auth(FlowEVMBridgeCustomAssociationTypes.FulfillFromEVM) &{FlowEVMBridgeCustomAssociationTypes.NFTFulfillmentMinter}>?
    ) {
        pre {
            self.associationsConfig[type] == nil:
            "Type \(type.identifier) already has a custom association with \(self.borrowNFTCustomConfig(forType: type)!.getEVMContractAddress().toString())"
            type.isSubtype(of: Type<@{NonFungibleToken.NFT}>()):
            "Only NFT cross-VM associations are currently supported but \(type.identifier) is not an NFT implementation"
            self.associationsByEVMAddress[evmContractAddress.toString()] == nil:
            "EVM Address \(evmContractAddress.toString()) already has a custom association with \(self.borrowNFTCustomConfig(forType: type)!.getCadenceType().identifier)"
            fulfillmentMinter?.check() ?? true:
            "The NFTFulfillmentMinter Capability issued from \(fulfillmentMinter!.address.toString()) is invalid. Ensure the Capability is properly issued and active."
        }
        let config <- FlowEVMBridgeCustomAssociationTypes.createNFTCustomConfig(
                type: type,
                evmContractAddress: evmContractAddress,
                nativeVM: nativeVM,
                updatedFromBridged: updatedFromBridged,
                fulfillmentMinter: fulfillmentMinter
            )
        emit CustomAssociationEstablished(
            type: type.identifier,
            evmContractAddress: evmContractAddress.toString(),
            nativeVMRawValue: nativeVM.rawValue,
            updatedFromBridged: updatedFromBridged,
            fulfillmentMinterType: fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.getType().identifier : nil,
            fulfillmentMinterOrigin: fulfillmentMinter?.address ?? nil,
            fulfillmentMinterCapID: fulfillmentMinter?.id ?? nil,
            fulfillmentMinterUUID: fulfillmentMinter != nil ? fulfillmentMinter!.borrow()!.uuid : nil,
            configUUID: config.uuid
        )
        self.associationsByEVMAddress[config.evmContractAddress.toString()] = type
        self.associationsConfig[type] <-! config
    }

    /// Allows bridge contracts to fulfill NFT bridging requests for EVM-native NFTs, using the provided
    /// NFTFulfillmentMinter Capability provided by the project on cross-VM registration to mint a new NFT.
    /// **NOTE:** Given the bridge's mint/escrow pattern for the non-native VM, any calls should first check that the 
    /// requested NFT is not locked in escrow before minting.
    ///
    /// @param forType: The Cadence Type of the NFT being fulfilled
    /// @param id: The ERC721 ID of the requested NFT
    ///
    /// @param
    access(account)
    fun fulfillNFTFromEVM(forType: Type, id: UInt256): @{NonFungibleToken.NFT} {
        post {
            result.getType() == forType:
            "Requested \(forType.identifier) but got \(result.getType().identifier) on fulfillment from EVM"
        }
        let config = self.borrowNFTCustomConfig(forType: forType)
            ?? panic("No CustomConfig found for type \(forType.identifier) - cannot fulfill NFT \(id) from EVM")
        let minter = config.borrowFulfillmentMinter()
        return <- minter.fulfillFromEVM(id: id)
    }

    /// Sets the associated CustomConfig as paused, preventing bridging operations on the associated implementations.
    /// Expect a no-op in the event the CustomConfig is already paused
    ///
    access(account) fun pauseCustomConfig(forType: Type) {
        let config = self.borrowNFTCustomConfig(forType: forType)
            ?? panic("No CustomConfig found for type \(forType.identifier) - cannot pause config that does not exist")
        if !config.isPaused() {
            config.setPauseStatus(true)
        }
    }

    /// Sets the associated CustomConfig as unpaused, preventing bridging operations on the associated implementations.
    /// Expect a no-op in the event the CustomConfig is already paused
    ///
    access(account) fun unpauseCustomConfig(forType: Type) {
        let config = self.borrowNFTCustomConfig(forType: forType)
            ?? panic("No CustomConfig found for type \(forType.identifier) - cannot unpause config that does not exist")
        if config.isPaused() {
            config.setPauseStatus(false)
        }
    }

    /// Returns a reference to the NFTCustomConfig if it exists, nil otherwise
    ///
    access(self) view fun borrowNFTCustomConfig(forType: Type): &FlowEVMBridgeCustomAssociationTypes.NFTCustomConfig? {
        let config = &self.associationsConfig[forType] as &{FlowEVMBridgeCustomAssociationTypes.CustomConfig}?
        return config as? &FlowEVMBridgeCustomAssociationTypes.NFTCustomConfig
    }


    init() {
        self.associationsConfig <- {}
        self.associationsByEVMAddress = {}
    }
}
