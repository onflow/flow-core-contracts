import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

import EVM from 0xe467b9dd11fa00df

/// FlowEVMBridgeHandlerInterfaces
///
/// This contract defines the interfaces for the FlowEVM Bridge Handlers. These Handlers are intended to encapsulate
/// the logic for bridging edge case assets between Cadence and EVM and require configuration by the bridge account to
/// enable. Contracts implementing these resources should be deployed to the bridge account so that privileged methods,
/// particularly those related to fulfilling bridge requests remain in the closed loop of bridge contract logic and
/// defined assets in the custody of the bridge account.
///
access(all) contract FlowEVMBridgeHandlerInterfaces {

    /******************
        Entitlements
    *******************/

    /// Entitlement related to administrative setters
    access(all) entitlement Admin
    /// Entitlement related to minting handled assets
    access(all) entitlement Mint

    /*************
        Events
    **************/
    
    /// Event emitted when a handler is enabled between a Cadence type and an EVM address
    access(all) event HandlerEnabled(
        handlerType: String,
        handlerUUID: UInt64,
        targetType: String,
        targetEVMAddress: String
    )
    /// Event emitted when a handler is disabled, pausing bridging between VMs
    access(all) event HandlerDisabled(
        handlerType: String,
        handlerUUID: UInt64,
        targetType: String?,
        targetEVMAddress: String?
    )
    /// Emitted when a minter resource is set in a handler
    access(all) event MinterSet(handlerType: String,
        handlerUUID: UInt64,
        targetType: String?,
        targetEVMAddress: String?,
        minterType: String,
        minterUUID: UInt64
    )

    /****************
        Constructs
    *****************/
    
    /// Non-privileged interface for querying handler information
    ///
    access(all) resource interface HandlerInfo {
        /// Returns whether the Handler is enabled
        access(all) view fun isEnabled(): Bool
        /// Returns the Cadence type handled by the Handler, nil if not set
        access(all) view fun getTargetType(): Type?
        /// Returns the EVM address handled by the Handler, nil if not set
        access(all) view fun getTargetEVMAddress(): EVM.EVMAddress?
        /// Returns the Type of the expected minter if the handler utilizes one
        access(all) view fun getExpectedMinterType(): Type?
    }

    /// Administrative interface for Handler configuration
    ///
    access(all) resource interface HandlerAdmin : HandlerInfo {
        /// Sets the target Cadence Type handled by this resource. Once the targe type is set - whether by this method
        /// or on initialization - this setter will fail.
        access(Admin) fun setTargetType(_ type: Type) {
            pre {
                self.getTargetType() == nil: "Target Type has already been set"
            }
            post {
                self.getTargetType()! == type: "Problem setting target type"
            }
        }
        /// Sets the target EVM address handled by this resource
        access(Admin) fun setTargetEVMAddress(_ address: EVM.EVMAddress) {
            pre {
                self.getTargetEVMAddress() == nil: "Target EVM address has already been set"
            }
            post {
                self.getTargetEVMAddress()!.equals(address!): "Problem setting target EVM address"
            }
        }
        access(Admin) fun setMinter(_ minter: @{FlowEVMBridgeHandlerInterfaces.TokenMinter}) {
            pre {
                self.getExpectedMinterType() == minter.getType(): "Minter is not of the expected type"
                minter.getMintedType() == self.getTargetType(): "Minter does not mint the target type"
                emit MinterSet(
                    handlerType: self.getType().identifier,
                    handlerUUID: self.uuid,
                    targetType: self.getTargetType()?.identifier,
                    targetEVMAddress: self.getTargetEVMAddress()?.toString(),
                    minterType: minter.getType().identifier,
                    minterUUID: minter.uuid
                )
            }
        }
        /// Enables the Handler to fulfill bridge requests for the configured targets. If implementers utilize a minter,
        /// they should additionally ensure the minter is set before enabling.
        access(Admin) fun enableBridging() {
            pre {
                self.getTargetType() != nil && self.getTargetEVMAddress() != nil:
                "Cannot enable before setting bridge target Type and EVM Address"
                !self.isEnabled(): "Handler has already been enabled"
            }
            post {
                self.isEnabled(): "Problem enabling Handler"
                emit HandlerEnabled(
                    handlerType: self.getType().identifier,
                    handlerUUID: self.uuid,
                    targetType: self.getTargetType()!.identifier,
                    targetEVMAddress: self.getTargetEVMAddress()!.toString()
                )
            }
        }

        /// Disables the Handler from fulfilling bridge requests.
        access(Admin) fun disableBridging() {
            pre {
                self.isEnabled():
                "Cannot disable: ".concat(self.getType().identifier).concat(" is already disabled")
            }
            post {
                !self.isEnabled():
                "Problem disabling ".concat(self.getType().identifier)
                emit HandlerDisabled(
                    handlerType: self.getType().identifier,
                    handlerUUID: self.uuid,
                    targetType: self.getTargetType()?.identifier,
                    targetEVMAddress: self.getTargetEVMAddress()?.toString()
                )
            }
        }
    }

    /// Minter interface for configurations requiring the minting of Cadence fungible tokens
    ///
    access(all) resource interface TokenMinter {
        /// Returns the Cadence type minted by this resource
        access(all) view fun getMintedType(): Type
        /// Mints the specified amount of tokens
        access(Mint) fun mint(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                amount > 0.0: "Attempting to mint 0.0 - Amount minted must be greater than 0"
            }
            post {
                result.getType() == self.getMintedType():
                "TokenMinter ".concat(self.getType().identifier).concat(" with uuid ").concat(self.uuid.toString())
                    .concat(" expected to mint ").concat(self.getMintedType().identifier)
                    .concat(" but returned ").concat(result.getType().identifier)
                result.balance == amount:
                "Minted amount ".concat(result.balance.toString())
                    .concat(" does not match requested amount ").concat(amount.toString())
            }
        }
    }

    /// Handler interface for bridging FungibleToken assets. Implementations should be stored within the bridge account
    /// and called be the bridge contract for bridging operations on the Handler's target Type and EVM contract.
    ///
    access(all) resource interface TokenHandler : HandlerAdmin {
        /// Fulfills a request to bridge tokens from the Cadence side to the EVM side
        access(account) fun fulfillTokensToEVM(
            tokens: @{FungibleToken.Vault},
            to: EVM.EVMAddress
        ) {
            pre {
                self.isEnabled():
                "TokenHandler ".concat(self.getType().identifier).concat(" with uuid ")
                    .concat(self.uuid.toString()).concat(" is not yet enabled")
                tokens.getType() == self.getTargetType():
                "TokenHandler ".concat(self.getType().identifier).concat(" with uuid ").concat(self.uuid.toString())
                    .concat(" expects ").concat(self.getTargetType()?.identifier ?? "nil")
                    .concat(" but received ").concat(tokens.getType().identifier)
                tokens.balance > 0.0:
                "Attempting to bridge 0.0 tokens - zero amounts are unsupported"
            }
        }
        /// Fulfills a request to bridge tokens from the EVM side to the Cadence side
        access(account) fun fulfillTokensFromEVM(
            owner: EVM.EVMAddress,
            type: Type,
            amount: UInt256,
            protectedTransferCall: fun (): EVM.Result
        ): @{FungibleToken.Vault} {
            pre {
                self.isEnabled():
                "TokenHandler ".concat(self.getType().identifier).concat(" with uuid ")
                    .concat(self.uuid.toString()).concat(" is not yet enabled")
                amount > UInt256(0): "Attempting to bridge 0 tokens from EVM - zero amounts are unsupported"
            }
            post {
                result.getType() == self.getTargetType():
                "TokenHandler ".concat(self.getType().identifier).concat(" with uuid ").concat(self.uuid.toString())
                    .concat(" expected to return ").concat(self.getTargetType()?.identifier ?? "nil")
                    .concat(" but returned ").concat(result.getType().identifier)
            }
        }
    }
}
