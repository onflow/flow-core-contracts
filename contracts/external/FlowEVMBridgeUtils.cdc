import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
import "CrossVMMetadataViews"
import "FungibleTokenMetadataViews"
import "ViewResolver"
import "FlowToken"
import "FlowStorageFees"

import "EVM"

import "SerializeMetadata"
import "FlowEVMBridgeConfig"
import "CrossVMNFT"
import "IBridgePermissions"

/// This contract serves as a source of utility methods leveraged by FlowEVMBridge contracts

/***************************************************************************************
 Clarification of Flow EVM Bridge Security Model

 The bridge operates under a "trust-but-verify" model for EVM contracts:

 Trust Assumptions
 - ERC20/ERC721 contracts correctly implement their respective standards.
 - `balanceOf()`, `ownerOf()`, and similar view functions return accurate state.
 - `transfer()`, `transferFrom()`, and similar mutating functions perform real state changes.
 - Emitted events correspond to actual state transitions.

 Security Boundaries
 The bridge provides the following security guarantees:

 1. Type Isolation: Each bridged ERC20/ERC721 maps to a unique Cadence type
    (e.g., `EVMVMBridgedToken_0x{ADDRESS}.Vault`). Cadence's type system ensures
    complete isolation between different token types.

 2. Cross-Asset Protection: A vulnerability or malicious behavior in one bridged
    asset CANNOT affect any other bridged asset. Each type has independent accounting.

 3. Protocol Asset Protection: Core protocol assets (FlowToken, etc.) are not
    exposed to risks from user-deployed EVM contracts.

 Flow EVM Bridge design - Security Consideration

 The bridge CANNOT protect against:

 - Malicious ERC20/ERC721 contracts that return fabricated data from view functions
   or fail to perform real state changes. Such contracts can cause accounting desync
   for their own token type, but cannot affect other assets.

 - Token developer malfeasance ("rug pulls"). A developer who controls a token
   contract can harm holders of that specific token through various means, with or
   without the bridge.

 
 The bridge's role is to faithfully execute cross-VM transfers for well-behaved
 contracts, not to enforce correct behavior of arbitrary EVM code.

 User Responsibility

 Users interacting with bridged assets should:
 - Verify the legitimacy of ERC20/ERC721 contracts before bridging.
 - Understand that the bridge cannot guarantee the behavior of arbitrary EVM contracts.
***************************************************************************************/

access(all)
contract FlowEVMBridgeUtils {

    /// Address of the bridge factory Solidity contract
    access(self)
    var bridgeFactoryEVMAddress: EVM.EVMAddress
    /// Delimeter used to derive contract names
    access(self)
    let delimiter: String
    /// Mapping containing contract name prefixes
    access(self)
    let contractNamePrefixes: {Type: {String: String}}

    /****************
        Constructs
    *****************/

    /// Struct used to preserve and pass around multiple values relating to Cadence asset onboarding
    ///
    access(all) struct CadenceOnboardingValues {
        access(all) let contractAddress: Address
        access(all) let name: String
        access(all) let symbol: String
        access(all) let identifier: String
        access(all) let contractURI: String

        init(
            contractAddress: Address,
            name: String,
            symbol: String,
            identifier: String,
            contractURI: String
        ) {
            self.contractAddress = contractAddress
            self.name = name
            self.symbol = symbol
            self.identifier = identifier
            self.contractURI = contractURI
        }
    }

    /// Struct used to preserve and pass around multiple values preventing the need to make multiple EVM calls
    /// during EVM asset onboarding
    ///
    access(all) struct EVMOnboardingValues {
        access(all) let evmContractAddress: EVM.EVMAddress
        access(all) let name: String
        access(all) let symbol: String
        access(all) let decimals: UInt8?
        access(all) let contractURI: String?
        access(all) let cadenceContractName: String
        access(all) let isERC721: Bool

        init(
            evmContractAddress: EVM.EVMAddress,
            name: String,
            symbol: String,
            decimals: UInt8?,
            contractURI: String?,
            cadenceContractName: String,
            isERC721: Bool
        ) {
            self.evmContractAddress = evmContractAddress
            self.name = name
            self.symbol = symbol
            self.decimals = decimals
            self.contractURI = contractURI
            self.cadenceContractName = cadenceContractName
            self.isERC721 = isERC721
        }
    }

    /**************************
        Public Bridge Utils
     **************************/

    /// Retrieves the bridge factory contract address
    ///
    /// @returns The EVMAddress of the bridge factory contract in EVM
    ///
    access(all)
    view fun getBridgeFactoryEVMAddress(): EVM.EVMAddress {
        return self.bridgeFactoryEVMAddress
    }

    /// Calculates the fee bridge fee based on the given storage usage + the current base fee.
    ///
    /// @param used: The amount of storage used by the asset
    ///
    /// @return The calculated fee amount
    ///
    access(all)
    view fun calculateBridgeFee(bytes used: UInt64): UFix64 {
        let megabytesUsed = FlowStorageFees.convertUInt64StorageBytesToUFix64Megabytes(used)
        let storageFee = FlowStorageFees.storageCapacityToFlow(megabytesUsed)
        return storageFee + FlowEVMBridgeConfig.baseFee
    }

    /// Returns whether the given type is allowed to be bridged as defined by the IBridgePermissions contract interface.
    /// If the type's defining contract does not implement IBridgePermissions, the method returns true as the bridge
    /// operates permissionlessly by default. Otherwise, the result of {IBridgePermissions}.allowsBridging() is returned
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return true if the type is allowed to be bridged, false otherwise
    ///
    access(all)
    view fun typeAllowsBridging(_ type: Type): Bool {
        let contractAddress = self.getContractAddress(fromType: type)
            ?? panic("Could not construct contract address from type identifier: \(type.identifier)")
        let contractName = self.getContractName(fromType: type)
            ?? panic("Could not construct contract name from type identifier: \(type.identifier)")
        if let bridgePermissions = getAccount(contractAddress).contracts.borrow<&{IBridgePermissions}>(name: contractName) {
            return bridgePermissions.allowsBridging()
        }
        return true
    }

    /// Returns whether the given address has opted out of enabling bridging for its defined assets
    ///
    /// @param address: The EVM contract address to check
    ///
    /// @return false if the address has opted out of enabling bridging, true otherwise
    ///
    access(all)
    fun evmAddressAllowsBridging(_ address: EVM.EVMAddress): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "allowsBridging()",
            targetEVMAddress: address,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )
        // Contract doesn't support the method - proceed permissionlessly
        if callResult.status != EVM.Status.successful {
            return true
        }
        // Contract is IBridgePermissions - return the result
        return (callResult.results.length == 1 && callResult.results[0] as! Bool) == true ? true : false
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge contract defines it or not
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the asset is Cadence-native, false if it is EVM-native
    ///
    access(all)
    view fun isCadenceNative(type: Type): Bool {
        let definingAddress = self.getContractAddress(fromType: type)
            ?? panic("Could not construct address from type identifier: \(type.identifier)")
        return definingAddress != self.account.address
    }

    /// Identifies if an asset is a type that is defined by a bridge-owned Cadence contract. For NFTs, this would
    /// indicate that the NFT is a bridged representation of a corresponding ERC721. For a Vault, this would
    /// indicate that the Vault is a bridged representation of a corresponding ERC20.
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the asset is bridge-defined, false if another Cadence contract defines the type. Reverts if the
    ///     type is a primitive type that is not defined by a Cadence contract.
    ///
    access(all)
    view fun isBridgeDefined(type: Type): Bool {
        let definingAddress = self.getContractAddress(fromType: type)
            ?? panic("Could not construct address from type identifier: \(type.identifier)")
        return definingAddress == self.account.address
    }

    /// Identifies if an asset is Cadence- or EVM-native, defined by whether a bridge-owned contract defines it or not.
    /// Reverts on EVM call failure.
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the asset is EVM-native, false if it is Cadence-native
    ///
    access(all)
    fun isEVMNative(evmContractAddress: EVM.EVMAddress): Bool {
        return self.isEVMContractBridgeOwned(evmContractAddress: evmContractAddress) == false
    }

    /// Determines if the given EVM contract address was deployed by the bridge by querying the factory contract
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the contract was deployed by the bridge, false otherwise
    ///
    access(all)
    fun isEVMContractBridgeOwned(evmContractAddress: EVM.EVMAddress): Bool {
        // Ask the bridge factory if the given contract address was deployed by the bridge
        let callResult = self.dryCallWithSigAndArgs(
            signature: "isBridgeDeployed(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! Bool
    }

    /// Identifies if an asset is ERC721. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the asset is an ERC721, false otherwise
    ///
    access(all)
    fun isERC721(evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "isERC721(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! Bool
    }

    /// Identifies if an asset is ERC20 as far as is possible without true EVM type introspection. Reverts on EVM call
    /// failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return true if the asset is an ERC20, false otherwise
    ///
    access(all)
    fun isERC20(evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "isERC20(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to bridge factory failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! Bool
    }

    /// Returns whether the contract address is either an ERC721 or ERC20 exclusively. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to check
    ///
    /// @return True if the contract is either an ERC721 or ERC20, false otherwise
    ///
    access(all)
    fun isValidEVMAsset(evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "isValidAsset(address)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [evmContractAddress],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )
        assert(callResult.results.length == 1, message: "Invalid response length")
        return callResult.results[0] as! Bool
    }

    /// Returns whether the given type is either an NFT or FT exclusively
    ///
    /// @param type: The Type of the asset to check
    ///
    /// @return True if the type is either an NFT or FT, false otherwise
    ///
    access(all)
    view fun isValidCadenceAsset(type: Type): Bool {
        let isCadenceNFT = type.isSubtype(of: Type<@{NonFungibleToken.NFT}>())
        let isCadenceFungibleToken = type.isSubtype(of: Type<@{FungibleToken.Vault}>())
        return isCadenceNFT != isCadenceFungibleToken
    }

    /// Retrieves the bridge contract's COA EVMAddress
    ///
    /// @returns The EVMAddress of the bridge contract's COA orchestrating actions in FlowEVM
    ///
    access(all)
    view fun getBridgeCOAEVMAddress(): EVM.EVMAddress {
        return self.borrowCOA().address()
    }

    /// Retrieves the relevant information for onboarding a Cadence asset to the bridge. This method is used to
    /// retrieve the name, symbol, contract address, and contract URI for a given Cadence asset type. These values
    /// are used to then deploy a corresponding EVM contract. If EVMBridgedMetadata is supported by the asset's
    /// defining contract, the values are retrieved from that view. Otherwise, the values are derived from other
    /// common metadata views.
    ///
    /// @param forAssetType: The Type of the asset to retrieve onboarding values for
    ///
    /// @return The CadenceOnboardingValues struct containing the asset's name, symbol, identifier, contract address,
    ///     and contract URI
    ///
    access(all)
    fun getCadenceOnboardingValues(forAssetType: Type): CadenceOnboardingValues {
        pre {
            self.isValidCadenceAsset(type: forAssetType): "This type is not a supported Flow asset type."
        }
        // If not an NFT, assumed to be fungible token.
        let isNFT = forAssetType.isSubtype(of: Type<@{NonFungibleToken.NFT}>())

        // Retrieve the Cadence type's defining contract name, address, & its identifier
        var name = self.getContractName(fromType: forAssetType)
            ?? panic("Could not contract name from type: \(forAssetType.identifier)")
        let identifier = forAssetType.identifier
        let cadenceAddress = self.getContractAddress(fromType: forAssetType)
            ?? panic("Could not derive contract address for token type: \(identifier)")
        // Initialize asset symbol which will be assigned later
        // based on presence of asset-defined metadata
        var symbol: String? = nil
        // Borrow the ViewResolver to attempt to resolve the EVMBridgedMetadata view
        let viewResolver = getAccount(cadenceAddress).contracts.borrow<&{ViewResolver}>(name: name)!
        var contractURI = ""

        // Try to resolve the EVMBridgedMetadata
        let bridgedMetadata = viewResolver.resolveContractView(
                resourceType: forAssetType,
                viewType: Type<MetadataViews.EVMBridgedMetadata>()
            ) as! MetadataViews.EVMBridgedMetadata?
        // Default to project-defined URI if available
        if bridgedMetadata != nil {
            name = bridgedMetadata!.name
            symbol = bridgedMetadata!.symbol
            contractURI = bridgedMetadata!.uri.uri()
        } else {
            if isNFT {
                // Otherwise, serialize collection-level NFTCollectionDisplay
                if let collectionDisplay = viewResolver.resolveContractView(
                    resourceType: forAssetType,
                    viewType: Type<MetadataViews.NFTCollectionDisplay>()
                ) as! MetadataViews.NFTCollectionDisplay? {
                    name = collectionDisplay.name
                    let serializedDisplay = SerializeMetadata.serializeFromDisplays(nftDisplay: nil, collectionDisplay: collectionDisplay)!
                    contractURI = "data:application/json;utf8,{\(serializedDisplay)}"
                }
                if symbol == nil {
                    symbol = SerializeMetadata.deriveSymbol(fromString: name)
                }
            } else {
                let ftDisplay = viewResolver.resolveContractView(
                    resourceType: forAssetType,
                    viewType: Type<FungibleTokenMetadataViews.FTDisplay>()
                ) as! FungibleTokenMetadataViews.FTDisplay?
                if ftDisplay != nil {
                    name = ftDisplay!.name
                    symbol = ftDisplay!.symbol
                }
                if contractURI.length == 0 && ftDisplay != nil {
                    let serializedDisplay = SerializeMetadata.serializeFTDisplay(ftDisplay!)
                    contractURI = "data:application/json;utf8,{\(serializedDisplay)}"
                }
                // Derive a symbol from the name if no metadata view provided one
                if symbol == nil {
                    symbol = SerializeMetadata.deriveSymbol(fromString: name)
                }
            }
        }

        return CadenceOnboardingValues(
            contractAddress: cadenceAddress,
            name: name,
            symbol: symbol!,
            identifier: identifier,
            contractURI: contractURI
        )
    }

    /// Retrieves identifying information about an EVM contract related to bridge onboarding.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve onboarding values for
    ///
    /// @return The EVMOnboardingValues struct containing the asset's name, symbol, decimals, contractURI, and
    ///    Cadence contract name as well as whether the asset is an ERC721
    ///
    access(all)
    fun getEVMOnboardingValues(evmContractAddress: EVM.EVMAddress): EVMOnboardingValues {
        // Retrieve the EVM contract's name, symbol, and contractURI
        let name: String = self.getName(evmContractAddress: evmContractAddress)
        let symbol: String = self.getSymbol(evmContractAddress: evmContractAddress)
        let contractURI = self.getContractURI(evmContractAddress: evmContractAddress)
        // Default to 18 decimals for ERC20s
        var decimals: UInt8 = FlowEVMBridgeConfig.defaultDecimals

        // Derive Cadence contract name
        let isERC721: Bool = self.isERC721(evmContractAddress: evmContractAddress)
        var cadenceContractName: String = ""
        if isERC721 {
            // Assert the contract is not mixed asset
            let isERC20 = self.isERC20(evmContractAddress: evmContractAddress)
            assert(!isERC20, message: "Contract is mixed asset and is not currently supported by the bridge")
            // Derive the contract name from the ERC721 contract
            cadenceContractName = self.deriveBridgedNFTContractName(from: evmContractAddress)
        } else {
            // Otherwise, treat as ERC20
            let isERC20 = self.isERC20(evmContractAddress: evmContractAddress)
            assert(
                isERC20,
                message: "Contract \(evmContractAddress.toString())defines an asset that is not currently supported by the bridge"
            )
            cadenceContractName = self.deriveBridgedTokenContractName(from: evmContractAddress)
            decimals = self.getTokenDecimals(evmContractAddress: evmContractAddress)
        }

        return EVMOnboardingValues(
            evmContractAddress: evmContractAddress,
            name: name,
            symbol: symbol,
            decimals: decimals,
            contractURI: contractURI,
            cadenceContractName: cadenceContractName,
            isERC721: isERC721
        )
    }

    /// Retrieves the EVMPointer view from a given type's defining contract if the view is supported.
    /// NOTE: This does not guarantee the association is valid, only that the defining Cadence contract declares
    /// the association.
    ///
    /// @param from: The type for which to retrieve the EVMPointer view
    ///
    /// @return The resolved EVMPointer view for the given type or nil if the view is unsupported
    ///
    access(all)
    fun getEVMPointerView(forType: Type): CrossVMMetadataViews.EVMPointer? {
        let contractAddress = forType.address!
        let contractName = forType.contractName!
        if let viewResolver = getAccount(contractAddress).contracts.borrow<&{ViewResolver}>(name: contractName) {
            return viewResolver.resolveContractView(
                resourceType: forType,
                viewType: Type<CrossVMMetadataViews.EVMPointer>()
            ) as? CrossVMMetadataViews.EVMPointer? ?? nil
        }
        return nil
    }

    /************************
        EVM Call Wrappers
     ************************/

    /// Retrieves the NFT/FT name from the given EVM contract address - applies for both ERC20 & ERC721.
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the name from
    ///
    /// @return the name of the asset
    ///
    access(all)
    fun getName(evmContractAddress: EVM.EVMAddress): String {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "name()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset name failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! String
    }

    /// Retrieves the NFT/FT symbol from the given EVM contract address - applies for both ERC20 & ERC721
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the symbol from
    ///
    /// @return the symbol of the asset
    ///
    access(all)
    fun getSymbol(evmContractAddress: EVM.EVMAddress): String {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "symbol()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )
        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset symbol failed")
        assert(callResult.results.length == 1, message: "Invalid response length")
        return callResult.results[0] as! String
    }

    /// Retrieves the tokenURI for the given NFT ID from the given EVM contract address. Reverts on EVM call failure.
    /// Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the tokenURI from
    /// @param id: The ID of the NFT for which to retrieve the tokenURI value
    ///
    /// @return the tokenURI of the ERC721
    ///
    access(all)
    fun getTokenURI(evmContractAddress: EVM.EVMAddress, id: UInt256): String {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "tokenURI(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [id],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call to EVM for tokenURI failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! String
    }

    /// Retrieves the contract URI from the given EVM contract address. Returns nil on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the contractURI from
    ///
    /// @return the contract's contractURI
    ///
    access(all)
    fun getContractURI(evmContractAddress: EVM.EVMAddress): String? {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "contractURI()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )
        if callResult.status != EVM.Status.successful {
            return nil
        }
        return callResult.results.length == 1 ? callResult.results[0] as! String : nil
    }

    /// Retrieves the number of decimals for a given ERC20 contract address. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The ERC20 contract address to retrieve the token decimals from
    ///
    /// @return the token decimals of the ERC20
    ///
    access(all)
    fun getTokenDecimals(evmContractAddress: EVM.EVMAddress): UInt8 {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "decimals()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<UInt8>()]
        )

        assert(callResult.status == EVM.Status.successful, message: "Call for EVM asset decimals failed")
        assert(callResult.results.length == 1, message: "Invalid response length")

        return callResult.results[0] as! UInt8
    }

    /// Determines if the provided owner address is either the owner or approved for the NFT in the ERC721 contract
    /// Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is either the owner or approved for the NFT, false otherwise
    ///
    access(all)
    fun isOwnerOrApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.isOwner(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress) ||
            self.isApproved(ofNFT: ofNFT, owner: owner, evmContractAddress: evmContractAddress)
    }

    /// Returns whether the given owner is the owner of the given NFT. Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is in fact the owner of the NFT, false otherwise
    ///
    access(all)
    fun isOwner(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.ownerOf(id: ofNFT, evmContractAddress: evmContractAddress)?.equals(owner) ?? false
    }

    /// Returns the owner of a given ERC721 token
    ///
    /// @param id: The ID of the NFT to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return The current owner's EVM address or nil if the `ownerOf` call is unsuccessful
    /// 
    access(all)
    fun ownerOf(id: UInt256, evmContractAddress: EVM.EVMAddress): EVM.EVMAddress? {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "ownerOf(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [id],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        if callResult.status == EVM.Status.failed {
            return nil
        }
        return callResult.results.length == 1 ? callResult.results[0] as! EVM.EVMAddress : nil
    }

    /// Returns whether the given owner is approved for the given NFT. Reverts on EVM call failure.
    ///
    /// @param ofNFT: The ID of the NFT to query
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC721 contract address to query
    ///
    /// @return true if the owner is in fact approved for the NFT, false otherwise
    ///
    access(all)
    fun isApproved(ofNFT: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "getApproved(uint256)",
            targetEVMAddress: evmContractAddress,
            args: [ofNFT],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC721.getApproved(uint256) failed")
        if callResult.results.length == 1 {
            let actualApproved = callResult.results[0] as! EVM.EVMAddress
            return actualApproved.equals(owner)
        }
        return false
    }

    /// Returns whether the given ERC721 exists, assuming the ERC721 contract implements the `exists` method. While this
    /// method is not part of the ERC721 standard, it is implemented in the bridge-deployed ERC721 implementation.
    /// Reverts on EVM call failure.
    ///
    /// @param erc721Address: The EVM contract address of the ERC721 token
    /// @param id: The ID of the ERC721 token to check
    ///
    /// @return true if the ERC721 token exists, false otherwise
    ///
    access(all)
    fun erc721Exists(erc721Address: EVM.EVMAddress, id: UInt256): Bool {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "exists(uint256)",
            targetEVMAddress: erc721Address,
            args: [id],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )
        assert(callResult.results.length == 1, message: "Invalid response length")
        return callResult.results[0] as! Bool
    }

    /// Returns the ERC20 balance of the owner at the given ERC20 contract address. Reverts on EVM call failure.
    ///
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC20 contract address to query
    ///
    /// @return The UInt256 balance of the owner at the ERC20 contract address. Callers may wish to convert the return
    ///     value to a UFix64 via convertERC20AmountToCadenceAmount, though note there may be a loss of precision.
    ///
    access(all)
    fun balanceOf(owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): UInt256 {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "balanceOf(address)",
            targetEVMAddress: evmContractAddress,
            args: [owner],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<UInt256>()]
        )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC20.balanceOf(address) failed")
        assert(callResult.results.length == 1, message: "Invalid response length")
        return callResult.results[0] as! UInt256
    }

    /// Determines if the owner has sufficient funds to bridge the given amount at the ERC20 contract address
    /// Reverts on EVM call failure.
    ///
    /// @param amount: The amount to check if the owner has enough balance to cover
    /// @param owner: The owner address to query
    /// @param evmContractAddress: The ERC20 contract address to query
    ///
    /// @return true if the owner's balance >= amount, false otherwise
    ///
    access(all)
    fun hasSufficientBalance(amount: UInt256, owner: EVM.EVMAddress, evmContractAddress: EVM.EVMAddress): Bool {
        return self.balanceOf(owner: owner, evmContractAddress: evmContractAddress) >= amount
    }

    /// Retrieves the total supply of the ERC20 contract at the given EVM contract address. Reverts on EVM call failure.
    ///
    /// @param evmContractAddress: The EVM contract address to retrieve the total supply from
    ///
    /// @return the total supply of the ERC20
    ///
    access(all)
    fun totalSupply(evmContractAddress: EVM.EVMAddress): UInt256 {
        let callResult = self.dryCallWithSigAndArgs(
            signature: "totalSupply()",
            targetEVMAddress: evmContractAddress,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<UInt256>()]
        )
        assert(callResult.status == EVM.Status.successful, message: "Call to ERC20.totalSupply() failed")
        assert(callResult.results.length == 1, message: "Invalid response length")
        return callResult.results[0] as! UInt256
    }

    /// Converts the given amount of ERC20 tokens to the equivalent amount in FLOW tokens based on the ERC20s decimals
    /// value. Note that may be some loss of decimal precision as UFix64 supports precision for 8 decimal places.
    /// Reverts on EVM call failure.
    ///
    /// @param amount: The amount of ERC20 tokens to convert
    /// @param erc20Address: The EVM contract address of the ERC20 token
    ///
    /// @return the equivalent amount in FLOW tokens as a UFix64
    ///
    access(all)
    fun convertERC20AmountToCadenceAmount(_ amount: UInt256, erc20Address: EVM.EVMAddress): UFix64 {
        return self.uint256ToUFix64(
            value: amount,
            decimals: self.getTokenDecimals(evmContractAddress: erc20Address)
        )
    }

    /// Converts the given amount of Cadence fungible tokens to the equivalent amount in ERC20 tokens based on the
    /// ERC20s decimals. Note that there may be some loss of decimal precision as UFix64 supports precision for 8
    /// decimal places. Reverts on EVM call failure.
    ///
    /// @param amount: The amount of Cadence fungible tokens to convert
    /// @param erc20Address: The EVM contract address of the ERC20 token
    ///
    /// @return the equivalent amount in ERC20 tokens as a UInt256
    ///
    access(all)
    fun convertCadenceAmountToERC20Amount(_ amount: UFix64, erc20Address: EVM.EVMAddress): UInt256 {
        return self.ufix64ToUInt256(value: amount, decimals: self.getTokenDecimals(evmContractAddress: erc20Address))
    }

    /// Converts the given ERC20 amount to the corresponding ERC20 amount after rounding down to the maximum precision
    /// representable by UFix64 (8 decimal places). This ensures that the amount escrowed on the EVM side matches
    /// exactly the amount that will be minted or unlocked on the Cadence side, preventing sub-UFix64-precision
    /// "dust" from being permanently locked in escrow without a corresponding Cadence representation.
    ///
    /// @param amount: The UInt256 ERC20 amount to cast to Cadence precision
    /// @param erc20Address: The EVM contract address of the ERC20 token
    ///
    /// @return The ERC20 UInt256 amount corresponding to the truncated Cadence UFix64 amount
    ///
    access(all)
    fun castERC20AmountToCadencePrecision(_ amount: UInt256, erc20Address: EVM.EVMAddress): UInt256 {
        let decimals = self.getTokenDecimals(evmContractAddress: erc20Address)
        let ufixAmount = self.uint256ToUFix64(value: amount, decimals: decimals)
        return self.ufix64ToUInt256(value: ufixAmount, decimals: decimals)
    }

    /// Gets the declared Cadence contract address declared by an EVM contract in conformance to the ICrossVM.sol
    /// contract interface. Reverts if the EVM call is unsuccessful.
    /// NOTE: Just because an EVM contract declares an association does not mean it it is valid!
    ///
    /// @param evmContract: The ICrossVM.sol conforming EVM contract from which to retrieve the declared Cadence
    ///     contract address
    ///
    /// @return The resulting Cadence Address as declared associated by the provided EVM contract or nil if the call fails
    ///
    access(all)
    fun getDeclaredCadenceAddressFromCrossVM(evmContract: EVM.EVMAddress): Address? {
        let cadenceAddrRes = self.dryCallWithSigAndArgs(
            signature: "getCadenceAddress()",
            targetEVMAddress: evmContract,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )
        if cadenceAddrRes.status != EVM.Status.successful {
            return nil
        }
        assert(cadenceAddrRes.results.length == 1, message: "Invalid response length")
        var cadenceAddrStr = cadenceAddrRes.results[0] as! String
        if cadenceAddrStr[1] != "x" {
            cadenceAddrStr = "0x\(cadenceAddrStr)"
        }
        return Address.fromString(cadenceAddrStr) ?? nil
    }

    /// Gets the declared Cadence Type declared by an EVM contract in conformance to the ICrossVM.sol contract
    /// interface. Reverts if the EVM call is unsuccessful.
    /// NOTE: Just because an EVM contract declares an association does not mean it it is valid!
    ///
    /// @param evmContract: The ICrossVM.sol conforming EVM contract from which to retrieve the declared Cadence
    ///     Type
    ///
    /// @return The resulting Cadence Type as declared associated by the provided EVM contract or nil if the call fails
    ///
    ///
    access(all)
    fun getDeclaredCadenceTypeFromCrossVM(evmContract: EVM.EVMAddress): Type? {
        let cadenceIdentifierRes = self.dryCallWithSigAndArgs(
            signature: "getCadenceIdentifier()",
            targetEVMAddress: evmContract,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<String>()]
        )
        if cadenceIdentifierRes.status != EVM.Status.successful {
            return nil
        }
        assert(cadenceIdentifierRes.results.length == 1, message: "Invalid response length")
        let cadenceIdentifier = cadenceIdentifierRes.results[0] as! String
        return CompositeType(cadenceIdentifier) ?? nil
    }

    /// Returns whether the provided EVM contract conforms to ICrossVMBridgeERC721Fulfillment.sol contract interface.
    /// Doing so is one of two interfaces that must be implemented for Cadence-native cross-VM NFTs to be successfully
    /// registered
    ///
    /// @param evmContract: The EVM contract to check for ICrossVMBridgeERC721 conformance
    ///
    /// @return True if conformance is found, false otherwise
    ///
    access(all)
    fun supportsICrossVMBridgeERC721Fulfillment(evmContract: EVM.EVMAddress): Bool {
        let interfaceID = EVM.EVMBytes4(value: "2e608d70".decodeHex().toConstantSized<[UInt8; 4]>()!)
        let supportsRes = self.dryCallWithSigAndArgs(
            signature: "supportsInterface(bytes4)",
            targetEVMAddress: evmContract,
            args: [interfaceID],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )
        if supportsRes.status != EVM.Status.successful {
            return false
        }
        if supportsRes.results.length != 1 {
            return false
        }
        return supportsRes.results[0] as! Bool
    }

    /// Returns whether the provided EVM contract conforms to ICrossVMBridgeCallable.sol contract interface.
    /// Doing so is one of two interfaces that must be implemented for Cadence-native cross-VM NFTs to be successfully
    /// registered
    ///
    /// @param evmContract: The EVM contract to check for ICrossVMBridgeCallable conformance
    ///
    /// @return True if conformance is found, false otherwise
    ///
    access(all)
    fun supportsICrossVMBridgeCallable(evmContract: EVM.EVMAddress): Bool {
        let interfaceID = EVM.EVMBytes4(value: "b7f9a9ec".decodeHex().toConstantSized<[UInt8; 4]>()!)
        let supportsRes = self.dryCallWithSigAndArgs(
            signature: "supportsInterface(bytes4)",
            targetEVMAddress: evmContract,
            args: [interfaceID],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<Bool>()]
        )
        if supportsRes.status != EVM.Status.successful {
            return false
        }
        if supportsRes.results.length != 1 {
            return false
        }
        return supportsRes.results[0] as! Bool
    }

    /// Returns whether the provided EVM contract conforms to both ICrossVMBridgeERC721Fulfillment and
    /// ICrossVMBridgeCallable Solidity contract interfaces
    ///
    /// @param evmContract: The EVM contract to check for conformance
    ///
    /// @return True if conformance is found, false otherwise
    ///
    access(all)
    fun supportsCadenceNativeNFTEVMInterfaces(evmContract: EVM.EVMAddress): Bool {
        return self.supportsICrossVMBridgeCallable(evmContract: evmContract)
            && self.supportsICrossVMBridgeERC721Fulfillment(evmContract: evmContract)
    }

    /// Returns the VM Bridge address designated by the ICrossVMBridgeCallable conforming EVM contract. Reverts on call
    /// failure.
    ///
    /// @param evmContract: The ICrossVMBridgeCallable EVM contract from which to retrieve the value
    ///
    /// @return The EVM address designated as the VM bridge address in the provided contract
    ///
    access(all)
    fun getVMBridgeAddressFromICrossVMBridgeCallable(evmContract: EVM.EVMAddress): EVM.EVMAddress? {
        let cadenceIdentifierRes = self.dryCallWithSigAndArgs(
            signature: "vmBridgeAddress()",
            targetEVMAddress: evmContract,
            args: [],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        if cadenceIdentifierRes.status != EVM.Status.successful {
            return nil
        }
        return cadenceIdentifierRes.results.length == 1 ? cadenceIdentifierRes.results[0] as! EVM.EVMAddress : nil
    }

    /************************
        Derivation Utils
     ************************/

    /// Derives the StoragePath where the escrow locker is stored for a given Type of asset & returns. The given type
    /// must be of an asset supported by the bridge.
    ///
    /// @param fromType: The type of the asset the escrow locker is being derived for
    ///
    /// @return The StoragePath associated with the type's escrow Locker, or nil if the type is not supported
    ///
    access(all)
    view fun deriveEscrowStoragePath(fromType: Type): StoragePath? {
        if !self.isValidCadenceAsset(type: fromType) {
            return nil
        }
        var prefix = ""
        if fromType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) {
            prefix = "flowEVMBridgeNFTEscrow"
        } else if fromType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            prefix = "flowEVMBridgeTokenEscrow"
        }
        assert(prefix.length > 1, message: "Invalid prefix")
        if let splitIdentifier = self.splitObjectIdentifier(identifier: fromType.identifier) {
            let sourceContractAddress = Address.fromString("0x\(splitIdentifier[1])")!
            let sourceContractName = splitIdentifier[2]
            let resourceName = splitIdentifier[3]
            return StoragePath(
                identifier: "\(prefix)\(self.delimiter)\(sourceContractAddress.toString())\(self.delimiter)\(sourceContractName)\(self.delimiter)\(resourceName)"
            ) ?? nil
        }
        return nil
    }

    /// Derives the Cadence contract name for a given EVM NFT of the form
    /// EVMVMBridgedNFT_<0xCONTRACT_ADDRESS>
    ///
    /// @param from evmContract: The EVM contract address to derive the Cadence NFT contract name for
    ///
    /// @return The derived Cadence FT contract name
    ///
    access(all)
    view fun deriveBridgedNFTContractName(from evmContract: EVM.EVMAddress): String {
        return "\(self.contractNamePrefixes[Type<@{NonFungibleToken.NFT}>()]!["bridged"]!)\(self.delimiter)\(evmContract.toString())"
    }

    /// Derives the Cadence contract name for a given EVM fungible token of the form
    /// EVMVMBridgedToken_<0xCONTRACT_ADDRESS>
    ///
    /// @param from evmContract: The EVM contract address to derive the Cadence FT contract name for
    ///
    /// @return The derived Cadence FT contract name
    ///
    access(all)
    view fun deriveBridgedTokenContractName(from evmContract: EVM.EVMAddress): String {
        return "\(self.contractNamePrefixes[Type<@{FungibleToken.Vault}>()]!["bridged"]!)\(self.delimiter)\(evmContract.toString())"
    }

    /****************
        Math Utils
     ****************/

    /// Raises the base to the power of the exponent
    ///
    access(all)
    view fun pow(base: UInt256, exponent: UInt8): UInt256 {
        if exponent == 0 {
            return 1
        }

        var r = base
        var exp: UInt8 = 1
        while exp < exponent {
            r = r * base
            exp = exp + 1
        }

        return r
    }

    /// Raises the fixed point base to the power of the exponent
    ///
    access(all)
    view fun ufixPow(base: UFix64, exponent: UInt8): UFix64 {
        if exponent == 0 {
            return 1.0
        }

        var r = base
        var exp: UInt8 = 1
        while exp < exponent {
            r = r * base
            exp = exp + 1
        }

        return r
    }

    /// Converts a UFix64 to a UInt256
    ///
    /// Note on overflow safety: `integer * integerMultiplier` where `integerMultiplier = 10^decimals` could
    /// theoretically overflow UInt256 for very large `decimals` values (e.g. decimals > ~58 with a non-zero
    /// integer part). In practice this is not a concern: ERC20 tokens with more than 18 decimals are outside
    /// the ERC20 standard convention, and UFix64.max (~1.84e19) * 10^18 ≈ 1.84e37, well within UInt256 range.
    /// The bridge sources `decimals` from on-chain ERC20 `decimals()` calls; a malicious token reporting
    /// extreme decimals would only affect its own bridged representation, not other assets.
    //
    access(all)
    view fun ufix64ToUInt256(value: UFix64, decimals: UInt8): UInt256 {
        // Default to 10e8 scale, catching instances where decimals are less than default and scale appropriately
        let ufixScaleExp: UInt8 = decimals < 8 ? decimals : 8
        var ufixScale = self.ufixPow(base: 10.0, exponent: ufixScaleExp)

        // Separate the fractional and integer parts of the UFix64
        let integer = UInt256(value)
        var fractional = (value % 1.0) * ufixScale

        // Calculate the multiplier for integer and fractional parts
        var integerMultiplier: UInt256 = self.pow(base:10, exponent: decimals)
        let fractionalMultiplierExp: UInt8 = decimals < 8 ? 0 : decimals - 8
        var fractionalMultiplier: UInt256 = self.pow(base:10, exponent: fractionalMultiplierExp)

        // Scale and sum the parts
        return integer * integerMultiplier + UInt256(fractional) * fractionalMultiplier
    }

    /// Converts a UInt256 to a UFix64
    ///
    access(all)
    view fun uint256ToUFix64(value: UInt256, decimals: UInt8): UFix64 {
        // Calculate scale factors for the integer and fractional parts
        let absoluteScaleFactor = self.pow(base: 10, exponent: decimals)

        // Separate the integer and fractional parts of the value
        let scaledValue = value / absoluteScaleFactor
        var fractional = value % absoluteScaleFactor
        // Scale the fractional part
        let scaledFractional = self.uint256FractionalToScaledUFix64Decimals(value: fractional, decimals: decimals)

        // Ensure the parts do not exceed the max UFix64 value before conversion
        assert(
            scaledValue <= UInt256(UFix64.max),
            message: "Scaled integer value \(value.toString()) exceeds max UFix64 value"
        )
        /// Check for the max value that can be converted to a UFix64 without overflowing
        assert(
            scaledValue == UInt256(UFix64.max) ? scaledFractional < 0.09551616 : true,
            message: "Scaled integer value \(value.toString()) exceeds max UFix64 value"
        )

        return UFix64(scaledValue) + scaledFractional
    }

    /// Converts a UInt256 fractional value with the given decimal places to a scaled UFix64. Note that UFix64 has
    /// decimal precision of 8 places so converted values may lose precision and be rounded down.
    ///
    access(all)
    view fun uint256FractionalToScaledUFix64Decimals(value: UInt256, decimals: UInt8): UFix64 {
        pre {
            self.getNumberOfDigits(value) <= decimals: "Fractional digits exceed the defined decimal places"
        }
        post {
            result < 1.0: "Resulting scaled fractional exceeds 1.0"
        }

        var fractional = value
        // Truncate fractional to the first 8 decimal places which is the max precision for UFix64
        if decimals >= 8 {
            fractional = fractional / self.pow(base: 10, exponent: decimals - 8)
        }
        // Return early if the truncated fractional part is now 0
        if fractional == 0 {
            return 0.0
        }

        // Scale the fractional part
        let fractionalMultiplier = self.ufixPow(base: 0.1, exponent: decimals < 8 ? decimals : 8)
        return UFix64(fractional) * fractionalMultiplier
    }

    /// Returns the value as a UInt64 if it fits, otherwise panics
    ///
    access(all)
    view fun uint256ToUInt64(value: UInt256): UInt64 {
        return value <= UInt256(UInt64.max) ? UInt64(value) : panic("Value too large to fit into UInt64")
    }

    /// Returns the number of digits in the given UInt256
    ///
    access(all)
    view fun getNumberOfDigits(_ value: UInt256): UInt8 {
        var tmp = value
        var digits: UInt8 = 0
        while tmp > 0 {
            tmp = tmp / 10
            digits = digits + 1
        }
        return digits
    }

    /***************************
        Type Identifier Utils
     ***************************/

    /// Returns the contract address from the given Type
    ///
    /// @param fromType: The Type to extract the contract address from
    ///
    /// @return The defining contract's Address, or nil if the identifier does not have an associated Address
    ///
    access(all)
    view fun getContractAddress(fromType: Type): Address? {
        return fromType.address
    }

    /// Returns the defining contract name from the given Type
    ///
    /// @param fromType: The Type to extract the contract name from
    ///
    /// @return The defining contract's name, or nil if the identifier does not have an associated contract name
    ///
    access(all)
    view fun getContractName(fromType: Type): String? {
        return fromType.contractName
    }

    /// Returns the object's name from the given Type's identifier where the identifier is in the format
    /// of: A.<CONTRACT_ADDRESS_SANS_0x>.<CONTRACT_NAME>.<OBJECT_NAME>
    ///
    /// @param fromType: The Type to extract the object name from
    ///
    /// @return The object's name, or nil if the identifier does identify an object
    ///
    access(all)
    view fun getObjectName(fromType: Type): String? {
        if let identifierSplit = self.splitObjectIdentifier(identifier: fromType.identifier) {
            return identifierSplit[3]
        }
        return nil
    }

    /// Splits the given identifier into its constituent parts defined by a delimiter of '".'"
    ///
    /// @param identifier: The identifier to split
    ///
    /// @return An array of the identifier's constituent parts, or nil if the identifier does not have 4 parts
    ///
    access(all)
    view fun splitObjectIdentifier(identifier: String): [String]? {
        let identifierSplit = identifier.split(separator: ".")
        return identifierSplit.length != 4 ? nil : identifierSplit
    }

    /// Builds a composite type from the given identifier parts
    ///
    /// @param address: The defining contract address
    /// @param contractName: The defining contract name
    /// @param resourceName: The resource name
    ///
    access(all)
    view fun buildCompositeType(address: Address, contractName: String, resourceName: String): Type? {
        let addressStr = address.toString()
        let subtract0x = addressStr.slice(from: 2, upTo: addressStr.length)
        let identifier = "A.\(subtract0x).\(contractName).\(resourceName)"
        return CompositeType(identifier)
    }

    /**************************
        FungibleToken Utils
     **************************/

    /// Returns the `createEmptyVault()` function from a Vault Type's defining contract or nil if either the Type is not
    access(all) fun getCreateEmptyVaultFunction(forType: Type): (fun (Type): @{FungibleToken.Vault})? {
        // We can only reasonably assume that the requested function is accessible from a FungibleToken contract
        if !forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            return nil
        }
        // Vault Types should guarantee that the following forced optionals are safe
        let contractAddress = self.getContractAddress(fromType: forType)!
        let contractName = self.getContractName(fromType: forType)!
        let tokenContract: &{FungibleToken} = getAccount(contractAddress).contracts.borrow<&{FungibleToken}>(
                name: contractName
            )!
        return tokenContract.createEmptyVault
    }

    /******************************
        Bridge-Access Only Utils
     ******************************/

    /// Deposits fees to the bridge account's FlowToken Vault - helps fund asset storage
    ///
    access(account)
    fun depositFee(_ feeProvider: auth(FungibleToken.Withdraw) &{FungibleToken.Provider}, feeAmount: UFix64) {
        let vault = self.account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken.Vault reference")

        let feeVault <-feeProvider.withdraw(amount: feeAmount) as! @FlowToken.Vault
        assert(feeVault.balance == feeAmount, message: "Fee provider did not return the requested fee")

        vault.deposit(from: <-feeVault)
    }

    /// Enables other bridge contracts to orchestrate bridge operations from contract-owned COA
    ///
    access(account)
    view fun borrowCOA(): auth(EVM.Call, EVM.Withdraw) &EVM.CadenceOwnedAccount {
        return self.account.storage.borrow<auth(EVM.Call, EVM.Withdraw) &EVM.CadenceOwnedAccount>(
            from: FlowEVMBridgeConfig.coaStoragePath
        ) ?? panic("Could not borrow COA reference")
    }

    /// Shared helper simplifying calls using the bridge account's COA
    ///
    access(account)
    fun callWithSigAndArgs(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64,
        resultTypes: [Type]?
    ): EVM.ResultDecoded {
        var valueBalance: UInt = 0
        if value > 0.0 {
            let balance = EVM.Balance(attoflow: 0)
            balance.setFLOW(flow: value)
            valueBalance = balance.inAttoFLOW()
        }

        return self.borrowCOA().callWithSigAndArgs(
            to: targetEVMAddress,
            signature: signature,
            args: args,
            gasLimit: gasLimit,
            value: valueBalance,
            resultTypes: resultTypes
        )
    }

    /// Shared helper simplifying dryCalls using the bridge account's COA. Note that `COA.dryCall` does not execute the
    /// call within EVM, serving solely as a mechanism for retrieving data from Flow-EVM environment.
    ///
    access(account)
    fun dryCallWithSigAndArgs(
        signature: String,
        targetEVMAddress: EVM.EVMAddress,
        args: [AnyStruct],
        gasLimit: UInt64,
        value: UFix64,
        resultTypes: [Type]?
    ): EVM.ResultDecoded {
        var valueBalance: UInt = 0
        if value > 0.0 {
            let balance = EVM.Balance(attoflow: 0)
            balance.setFLOW(flow: value)
            valueBalance = balance.inAttoFLOW()
        }

        return self.borrowCOA().dryCallWithSigAndArgs(
            to: targetEVMAddress,
            signature: signature,
            args: args,
            gasLimit: gasLimit,
            value: valueBalance,
            resultTypes: resultTypes
        )
    }

    /// Executes a safeTransferFrom call on the given ERC721 contract address, transferring the NFT from bridge escrow
    /// in EVM to the named recipient and asserting pre- and post-state changes.
    ///
    access(account)
    fun mustSafeTransferERC721(erc721Address: EVM.EVMAddress, to: EVM.EVMAddress, id: UInt256) {
        let bridgeCOAAddress = self.getBridgeCOAEVMAddress()

        let bridgePreStatus = self.isOwner(ofNFT: id, owner: bridgeCOAAddress, evmContractAddress: erc721Address)
        let toPreStatus = self.isOwner(ofNFT: id, owner: to, evmContractAddress: erc721Address)
        assert(bridgePreStatus, message: "Bridge COA does not own ERC721 requesting to be transferred")
        assert(!toPreStatus, message: "Recipient already owns ERC721 attempting to be transferred")

        let transferResult = self.callWithSigAndArgs(
            signature: "safeTransferFrom(address,address,uint256)",
            targetEVMAddress: erc721Address,
            args: [bridgeCOAAddress, to, id],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(
            transferResult.status == EVM.Status.successful,
            message: "safeTransferFrom call to ERC721 transferring NFT from escrow to bridge recipient failed"
        )

        let bridgePostStatus = self.isOwner(ofNFT: id, owner: bridgeCOAAddress, evmContractAddress: erc721Address)
        let toPostStatus = self.isOwner(ofNFT: id, owner: to, evmContractAddress: erc721Address)
        assert(!bridgePostStatus, message: "ERC721 is still in escrow after transfer")
        assert(toPostStatus, message: "ERC721 was not successfully transferred to recipient from escrow")
    }

    /// Executes a safeMint call on the given ERC721 contract address, minting an ERC721 to the named recipient and
    /// asserting pre- and post-state changes. Assumes the bridge COA has the authority to mint the NFT.
    ///
    access(account)
    fun mustSafeMintERC721(erc721Address: EVM.EVMAddress, to: EVM.EVMAddress, id: UInt256, uri: String) {
        let bridgeCOAAddress = self.getBridgeCOAEVMAddress()

        let mintResult = self.callWithSigAndArgs(
            signature: "safeMint(address,uint256,string)",
            targetEVMAddress: erc721Address,
            args: [to, id, uri],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(mintResult.status == EVM.Status.successful, message: "Mint to bridge recipient failed")

        let toPostStatus = self.isOwner(ofNFT: id, owner: to, evmContractAddress: erc721Address)
        assert(toPostStatus, message: "Recipient does not own the NFT after minting")
    }

    /// Executes a safeMint call on the given ERC721 contract address, minting an ERC721 to the named recipient and
    /// asserting pre- and post-state changes. Assumes the bridge COA has the authority to mint the NFT.
    ///
    access(account)
    fun mustFulfillNFTToEVM(erc721Address: EVM.EVMAddress, to: EVM.EVMAddress, id: UInt256, maybeBytes: EVM.EVMBytes?) {
        let fulfillResult = self.callWithSigAndArgs(
            signature: "fulfillToEVM(address,uint256,bytes)",
            targetEVMAddress: erc721Address,
            args: [to, id, maybeBytes ?? EVM.EVMBytes(value: [])],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(
            fulfillResult.status == EVM.Status.successful,
            message: "Fulfill ERC721 \(erc721Address.toString()) with id \(id) to \(to.toString()) failed with error code \(fulfillResult.errorCode): \(fulfillResult.errorMessage)"
        )

        let toPostStatus = self.isOwner(ofNFT: id, owner: to, evmContractAddress: erc721Address)
        assert(toPostStatus, message: "Recipient does not own the NFT after minting")
    }

    /// Executes updateTokenURI call on the given ERC721 contract address, updating the tokenURI of the NFT. This is
    /// not a standard ERC721 function, but is implemented in the bridge-deployed ERC721 implementation to enable
    /// synchronization of token metadata with Cadence NFT state on bridging.
    ///
    access(account)
    fun mustUpdateTokenURI(erc721Address: EVM.EVMAddress, id: UInt256, uri: String) {
        let bridgeCOAAddress = self.getBridgeCOAEVMAddress()

        let updateResult = self.callWithSigAndArgs(
            signature: "updateTokenURI(uint256,string)",
            targetEVMAddress: erc721Address,
            args: [id, uri],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(updateResult.status == EVM.Status.successful, message: "URI update failed")
    }

    /// Executes the provided method, assumed to be a protected transfer call, and confirms that the transfer was
    /// successful by validating the named owner is authorized to act on the NFT before the transfer, the transfer
    /// was successful, and the bridge COA owns the NFT after the protected transfer call.
    ///
    access(account)
    fun mustEscrowERC721(
        owner: EVM.EVMAddress,
        id: UInt256,
        erc721Address: EVM.EVMAddress,
        protectedTransferCall: fun (EVM.EVMAddress): EVM.ResultDecoded
    ) {
        // Ensure the named owner is authorized to act on the NFT
        let isAuthorized = self.isOwnerOrApproved(ofNFT: id, owner: owner, evmContractAddress: erc721Address)
        assert(isAuthorized, message: "Named owner is not the owner of the ERC721")

        // Call the protected transfer function which should execute a transfer call from the owner to escrow
        let transferResult = protectedTransferCall(erc721Address)
        assert(transferResult.status == EVM.Status.successful, message: "Transfer ERC721 to escrow via callback failed")

        // Validate the NFT is now owned by the bridge COA, escrow the NFT
        let isEscrowed = self.isOwner(ofNFT: id, owner: self.getBridgeCOAEVMAddress(), evmContractAddress: erc721Address)
        assert(isEscrowed, message: "ERC721 was not successfully escrowed")
    }

    /// Unwraps an ERC721 token, calling `ERC721Wrapper.withdrawTo(address,uint256[])` on the provided wrapper address
    /// and ensuring that the underlying ERC721 is owned by the bridge COA before returning.
    /// NOTE: This method relies on implementation of OpenZeppelin's `ERC721Wrapper` contract interface, reverting if
    /// the unwrap operation is unsuccessful.
    ///
    access(account)
    fun mustUnwrapERC721(
        id: UInt256,
        erc721WrapperAddress: EVM.EVMAddress,
        underlyingEVMAddress: EVM.EVMAddress
    ) {
        assert(
            self.isOwner(ofNFT: id, owner: erc721WrapperAddress, evmContractAddress: underlyingEVMAddress),
            message: "Attempting to unwrap \(underlyingEVMAddress.toString()) ID \(id), but token is not wrapped by \(erc721WrapperAddress.toString())"
        )
        let bridgeCOA = self.getBridgeCOAEVMAddress()

        let unwrapResult = self.callWithSigAndArgs(
            signature: "withdrawTo(address,uint256[])",
            targetEVMAddress: erc721WrapperAddress,
            args: [bridgeCOA, [id]],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(
            unwrapResult.status == EVM.Status.successful,
            message: "Call to \(erc721WrapperAddress.toString()) ERC721Wrapper.withdrawTo(address,uint256[]) failed"
        )

        assert(
            self.isOwner(ofNFT: id, owner: bridgeCOA, evmContractAddress: underlyingEVMAddress),
            message: "Unsuccessful escrow of wrapped ERC721 \(erc721WrapperAddress.toString()) wrapping underlying \(underlyingEVMAddress.toString()) ID \(id)"
        )
    }

    /// Mints ERC20 tokens to the recipient and confirms that the recipient's balance was updated
    ///
    access(account)
    fun mustMintERC20(to: EVM.EVMAddress, amount: UInt256, erc20Address: EVM.EVMAddress) {
        let toPreBalance = self.balanceOf(owner: to, evmContractAddress: erc20Address)
        // Mint tokens to the recipient
        let mintResult = self.callWithSigAndArgs(
            signature: "mint(address,uint256)",
            targetEVMAddress: erc20Address,
            args: [to, amount],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(mintResult.status == EVM.Status.successful, message: "Mint to bridge ERC20 contract failed")
        // Ensure bridge to recipient was succcessful
        let toPostBalance = self.balanceOf(owner: to, evmContractAddress: erc20Address)
        assert(
            toPostBalance == toPreBalance + amount,
            message: "Recipient didn't receive minted ERC20 tokens during bridging"
        )
    }

    /// Transfers ERC20 tokens to the recipient and confirms that the recipient's balance was incremented and the escrow
    /// balance was decremented by the requested amount.
    ///
    access(account)
    fun mustTransferERC20(to: EVM.EVMAddress, amount: UInt256, erc20Address: EVM.EVMAddress) {
        let bridgeCOAAddress = self.getBridgeCOAEVMAddress()

        let toPreBalance = self.balanceOf(owner: to, evmContractAddress: erc20Address)
        let escrowPreBalance = self.balanceOf(
            owner: bridgeCOAAddress,
            evmContractAddress: erc20Address
        )

        // Transfer tokens to the recipient
        let transferResult = self.callWithSigAndArgs(
            signature: "transfer(address,uint256)",
            targetEVMAddress: erc20Address,
            args: [to, amount],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(transferResult.status == EVM.Status.successful, message: "transfer call to ERC20 contract failed")

        // Ensure bridge to recipient was succcessful
        let toPostBalance = self.balanceOf(owner: to, evmContractAddress: erc20Address)
        let escrowPostBalance = self.balanceOf(
            owner: bridgeCOAAddress,
            evmContractAddress: erc20Address
        )
        assert(
            toPostBalance == toPreBalance + amount,
            message: "Recipient's ERC20 balance did not increment by the requested amount after transfer from escrow"
        )
        assert(
            escrowPostBalance == escrowPreBalance - amount,
            message: "Escrow ERC20 balance did not decrement by the requested amount after transfer from escrow"
        )
    }

    /// Executes the provided method, assumed to be a protected transfer call, and confirms that the transfer was
    /// successful by validating that the named owner's balance was decremented by the requested amount and the bridge
    /// escrow balance was incremented by the same amount.
    ///
    access(account)
    fun mustEscrowERC20(
        owner: EVM.EVMAddress,
        amount: UInt256,
        erc20Address: EVM.EVMAddress,
        protectedTransferCall: fun (): EVM.ResultDecoded
    ) {
        // Ensure the caller is has sufficient balance to bridge the requested amount
        let hasSufficientBalance = self.hasSufficientBalance(
            amount: amount,
            owner: owner,
            evmContractAddress: erc20Address
        )
        assert(hasSufficientBalance, message: "Caller does not have sufficient balance to bridge requested tokens")

        // Get the owner and escrow balances before transfer
        let ownerPreBalance = self.balanceOf(owner: owner, evmContractAddress: erc20Address)
        let bridgePreBalance = self.balanceOf(
                owner: self.getBridgeCOAEVMAddress(),
                evmContractAddress: erc20Address
            )

        // Call the protected transfer function which should execute a transfer call from the owner to escrow
        let transferResult = protectedTransferCall()
        assert(transferResult.status == EVM.Status.successful, message: "Transfer via callback failed")

        // Get the resulting balances after transfer
        let ownerPostBalance = self.balanceOf(owner: owner, evmContractAddress: erc20Address)
        let bridgePostBalance = self.balanceOf(
                owner: self.getBridgeCOAEVMAddress(),
                evmContractAddress: erc20Address
            )

        // Confirm the expected amount moved from owner to bridge escrow. These post-state assertions are the
        // primary security guarantee for ERC20 escrow — they catch any accounting discrepancy regardless of
        // cause (reentrant callbacks, fee-on-transfer tokens, etc.). The pre-balance snapshot above is not a
        // TOCTOU risk because all EVM calls within a single Cadence transaction execute within the same EVM
        // block, so no interleaving can occur between the snapshot and the transfer.
        assert(ownerPostBalance == ownerPreBalance - amount, message: "Transfer to owner failed")
        assert(bridgePostBalance == bridgePreBalance + amount, message: "Transfer to bridge escrow failed")
    }

    /// Executes a `burn(uint256)` call targeting the provided ERC721 contract address. Reverts if the call is
    /// unsuccessful
    ///
    access(account)
    fun mustBurnERC721(erc721Address: EVM.EVMAddress, id: UInt256) {
        let burnResult = FlowEVMBridgeUtils.callWithSigAndArgs(
            signature: "burn(uint256)",
            targetEVMAddress: erc721Address,
            args: [id],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        )
        assert(burnResult.status == EVM.Status.successful,
            message: "0x\(erc721Address.toString()).burn(\(id)) failed with error code \(burnResult.errorCode) and message: \(burnResult.errorMessage)")
    }

    /// Calls to the bridge factory to deploy an ERC721/ERC20 contract and returns the deployed contract address
    ///
    access(account)
    fun mustDeployEVMContract(
        name: String,
        symbol: String,
        cadenceAddress: Address,
        flowIdentifier: String,
        contractURI: String,
        isERC721: Bool
    ): EVM.EVMAddress {
        let deployerTag = isERC721 ? "ERC721" : "ERC20"
        let deployResult = self.callWithSigAndArgs(
            signature: "deploy(string,string,string,string,string,string)",
            targetEVMAddress: self.bridgeFactoryEVMAddress,
            args: [deployerTag, name, symbol, cadenceAddress.toString(), flowIdentifier, contractURI],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: [Type<EVM.EVMAddress>()]
        )
        assert(deployResult.status == EVM.Status.successful, message: "EVM Token contract deployment failed")
        assert(deployResult.results.length == 1, message: "Invalid response length")
        return deployResult.results[0] as! EVM.EVMAddress
    }

    /// Calls `setSymbol(string)` on the EVM contract as exposed on FlowEVMBridgedERC721 contracts, enabling Cadence
    /// NFTs to update their EVM symbol via EVMBridgedMetadata.symbol. The call's status is returned so conditional 
    /// execution can be handled on the caller's end.
    ///
    access(account)
    fun tryUpdateSymbol(_ evmContractAddress: EVM.EVMAddress, symbol: String): Bool {
        return self.callWithSigAndArgs(
            signature: "setSymbol(string)",
            targetEVMAddress: evmContractAddress,
            args: [symbol],
            gasLimit: FlowEVMBridgeConfig.gasLimit,
            value: 0.0,
            resultTypes: nil
        ).status == EVM.Status.successful
    }

    init(bridgeFactoryAddressHex: String) {
        self.delimiter = "_"
        self.contractNamePrefixes = {
            Type<@{NonFungibleToken.NFT}>(): {
                "bridged": "EVMVMBridgedNFT"
            },
            Type<@{FungibleToken.Vault}>(): {
                "bridged": "EVMVMBridgedToken"
            }
        }
        self.bridgeFactoryEVMAddress = EVM.addressFromString(bridgeFactoryAddressHex.toLower())
    }
}
