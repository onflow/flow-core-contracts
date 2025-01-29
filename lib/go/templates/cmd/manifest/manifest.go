package main

import (
	"crypto/sha256"
	"encoding/hex"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

type manifest struct {
	Network   string     `json:"network"`
	Templates []template `json:"templates"`
}

func (m *manifest) addTemplate(t template) {
	m.Templates = append(m.Templates, t)
}

type template struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	Source    string     `json:"source"`
	Arguments []argument `json:"arguments"`
	Network   string     `json:"network"`
	Hash      string     `json:"hash"`
}

type argument struct {
	Type         string         `json:"type"`
	Name         string         `json:"name"`
	Label        string         `json:"label"`
	SampleValues []cadenceValue `json:"sampleValues"`
}

type cadenceValue struct {
	cadence.Value
}

func (v cadenceValue) MarshalJSON() ([]byte, error) {
	return jsoncdc.Encode(v.Value)
}

func (v cadenceValue) UnmarshalJSON(bytes []byte) (err error) {
	v.Value, err = jsoncdc.Decode(nil, bytes)
	if err != nil {
		return err
	}

	return nil
}

func optionalCadenceValue(value cadence.Value) cadenceValue {
	return cadenceValue{cadence.NewOptional(value)}
}

type templateGenerator func(env templates.Environment) []byte

func generateTemplate(
	id, name string,
	env templates.Environment,
	generator templateGenerator,
	arguments []argument,
) template {
	source := generator(env)

	h := sha256.New()
	h.Write(source)
	hash := h.Sum(nil)

	return template{
		ID:        id,
		Name:      name,
		Source:    string(source),
		Arguments: arguments,
		Network:   env.Network,
		Hash:      hex.EncodeToString(hash),
	}
}

func generateManifest(env templates.Environment) *manifest {
	m := &manifest{
		Network: env.Network,
	}

	sampleAmountRaw, err := cadence.NewUFix64("92233720368.54775808")
	if err != nil {
		panic(err)
	}

	sampleKeyWeightRaw, err := cadence.NewUFix64("1000.0")
	if err != nil {
		panic(err)
	}
	sampleKeyWeight := cadenceValue{sampleKeyWeightRaw}

	sampleSigAlgoEnumRawValue := cadenceValue{cadence.NewUInt8(1)}
	sampleHashAlgoEnumRawValue := cadenceValue{cadence.NewUInt8(1)}

	sampleKeyIndex := cadenceValue{cadence.NewInt(1)}

	sampleAmount := cadenceValue{sampleAmountRaw}
	sampleFTContractName := cadenceValue{cadence.String("FiatToken")}

	sampleID := cadenceValue{cadence.NewUInt64(10)}
	sampleNFTContractName := cadenceValue{cadence.String("TopShot")}

	sampleStoragePathID := cadenceValue{cadence.String("flowTokenVault")}
	samplePublicPathID := cadenceValue{cadence.String("flowTokenReceiver")}

	sampleNodeID := cadenceValue{
		cadence.String("88549335e1db7b5b46c2ad58ddb70b7a45e770cc5fe779650ba26f10e6bae5e6"),
	}

	sampleNodeRole := cadenceValue{
		cadence.NewUInt8(1),
	}

	sampleNetworkingAddress := cadenceValue{
		cadence.String("flow-node.test:3569"),
	}

	sampleNetworkingKey := cadenceValue{
		cadence.String("1348307bc77c688e80049de9d081aa09755da33e6997605fa059db2144fc85e560cbe6f7da8d74b453f5916618cb8fd392c2db856f3e78221dc68db1b1d914e4"),
	}

	sampleStakingKey := cadenceValue{
		cadence.String("8dec36ed8a91e3e5d737b06434d94a8a561c7889495d6c7081cd5e123a42124415b9391c9b9aa165c2f71994bf9607cb0ea262ad162fec74146d1ebc482a33b9dad203d16a83bbfda89b3f6e1cd1d8fb2e704a162d259a0ac9f26bc8635d74f6"),
	}

	sampleStakingKeyPoP := cadenceValue{
		cadence.String("828a68a2be392804044d85888100462702a422901da3269fb6512defabad07250aad24f232671e4ac8ae531f54e062fc"),
	}

	sampleNullOptional := cadenceValue{
		cadence.NewOptional(nil),
	}

	sampleDelegatorIDOptional := cadenceValue{cadence.NewOptional(
		cadence.NewUInt32(42),
	)}

	sampleDelegatorID := cadenceValue{cadence.NewUInt32(42)}

	sampleRawKey := cadence.String("f845b8406e4f43f79d3c1d8cacb3d5f3e7aeedb29feaeb4559fdb71a97e2fd0438565310e87670035d83bc10fe67fe314dba5363c81654595d64884b1ecad1512a64e65e020164")
	sampleKey := cadenceValue{sampleRawKey}

	m.addTemplate(generateTemplate(
		"FA.01", "Create Account",
		env,
		templates.GenerateCreateAccountScript,
		[]argument{
			{
				Type:         "String",
				Name:         "key",
				Label:        "Public Key",
				SampleValues: []cadenceValue{sampleKey},
			},
			{
				Type:         "UInt8",
				Name:         "signatureAlgorithm",
				Label:        "Raw Value for Signature Algorithm Enum",
				SampleValues: []cadenceValue{sampleSigAlgoEnumRawValue},
			},
			{
				Type:         "UInt8",
				Name:         "hashAlgorithm",
				Label:        "Raw Value for Hash Algorithm Enum",
				SampleValues: []cadenceValue{sampleHashAlgoEnumRawValue},
			},
			{
				Type:         "UFix64",
				Name:         "weight",
				Label:        "Key Weight",
				SampleValues: []cadenceValue{sampleKeyWeight},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"FA.02", "Add Key",
		env,
		templates.GenerateAddKeyScript,
		[]argument{
			{
				Type:         "String",
				Name:         "key",
				Label:        "Public Key",
				SampleValues: []cadenceValue{sampleKey},
			},
			{
				Type:         "UInt8",
				Name:         "signatureAlgorithm",
				Label:        "Raw Value for Signature Algorithm Enum",
				SampleValues: []cadenceValue{sampleSigAlgoEnumRawValue},
			},
			{
				Type:         "UInt8",
				Name:         "hashAlgorithm",
				Label:        "Raw Value for Hash Algorithm Enum",
				SampleValues: []cadenceValue{sampleHashAlgoEnumRawValue},
			},
			{
				Type:         "UFix64",
				Name:         "weight",
				Label:        "Key Weight",
				SampleValues: []cadenceValue{sampleKeyWeight},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"FA.03", "Remove Key",
		env,
		templates.GenerateRevokeKeyScript,
		[]argument{{
			Type:         "Int",
			Name:         "keyIndex",
			Label:        "Key Index",
			SampleValues: []cadenceValue{sampleKeyIndex},
		}},
	))

	m.addTemplate(generateTemplate(
		"FT.01", "Setup Fungible Token Vault",
		env,
		templates.GenerateSetupFTAccountFromAddressScript,
		[]argument{
			{
				Type:         "Address",
				Name:         "contractAddress",
				Label:        "FT Contract Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "String",
				Name:         "contractName",
				Label:        "FT Contract Name",
				SampleValues: []cadenceValue{sampleFTContractName},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"FT.02", "Transfer Fungible Token with Paths",
		env,
		templates.GenerateTransferGenericVaultWithPathsScript,
		[]argument{
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
			{
				Type:         "Address",
				Name:         "to",
				Label:        "Recipient",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "String",
				Name:         "senderPathIdentifier",
				Label:        "Sender's Collection Path Identifier",
				SampleValues: []cadenceValue{sampleStoragePathID},
			},
			{
				Type:         "String",
				Name:         "receiverPathIdentifier",
				Label:        "Recipient's Receiver Path Identifier",
				SampleValues: []cadenceValue{samplePublicPathID},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"FT.03", "Transfer Fungible Token with Address",
		env,
		templates.GenerateTransferGenericVaultWithAddressScript,
		[]argument{
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
			{
				Type:         "Address",
				Name:         "to",
				Label:        "Recipient",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "Address",
				Name:         "contractAddress",
				Label:        "FT Contract Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "String",
				Name:         "contractName",
				Label:        "FT Contract Name",
				SampleValues: []cadenceValue{sampleFTContractName},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"NFT.01", "Setup NFT Collection",
		env,
		templates.GenerateSetupNFTAccountFromAddressScript,
		[]argument{
			{
				Type:         "Address",
				Name:         "contractAddress",
				Label:        "NFT Contract Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "String",
				Name:         "contractName",
				Label:        "NFT Contract Name",
				SampleValues: []cadenceValue{sampleNFTContractName},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"NFT.02", "Transfer NFT with Paths",
		env,
		templates.GenerateTransferGenericNFTWithPathsScript,
		[]argument{
			{
				Type:         "Address",
				Name:         "to",
				Label:        "Recipient",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "UInt64",
				Name:         "id",
				Label:        "NFT ID to Transfer",
				SampleValues: []cadenceValue{sampleID},
			},
			{
				Type:         "String",
				Name:         "senderPathIdentifier",
				Label:        "Sender's Collection Path Identifier",
				SampleValues: []cadenceValue{sampleStoragePathID},
			},
			{
				Type:         "String",
				Name:         "receiverPathIdentifier",
				Label:        "Recipient's Receiver Path Identifier",
				SampleValues: []cadenceValue{samplePublicPathID},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"NFT.03", "Transfer NFT with Address",
		env,
		templates.GenerateTransferGenericNFTWithAddressScript,
		[]argument{
			{
				Type:         "Address",
				Name:         "to",
				Label:        "Recipient",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "UInt64",
				Name:         "id",
				Label:        "NFT ID to Transfer",
				SampleValues: []cadenceValue{sampleID},
			},
			{
				Type:         "Address",
				Name:         "contractAddress",
				Label:        "NFT Contract Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
			{
				Type:         "String",
				Name:         "contractName",
				Label:        "NFT Contract Name",
				SampleValues: []cadenceValue{sampleNFTContractName},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.01", "Withdraw Unlocked FLOW",
		env,
		templates.GenerateWithdrawTokensScript,
		[]argument{{
			Type:         "UFix64",
			Name:         "amount",
			Label:        "Amount",
			SampleValues: []cadenceValue{sampleAmount},
		}},
	))

	m.addTemplate(generateTemplate(
		"TH.02", "Deposit Unlocked FLOW",
		env,
		templates.GenerateDepositTokensScript,
		[]argument{{
			Type:         "UFix64",
			Name:         "amount",
			Label:        "Amount",
			SampleValues: []cadenceValue{sampleAmount},
		}},
	))

	m.addTemplate(generateTemplate(
		"SCO.01", "Setup Staking Collection",
		env,
		templates.GenerateCollectionSetup,
		[]argument{},
	))

	m.addTemplate(generateTemplate(
		"SCO.02", "Register Delegator",
		env,
		templates.GenerateCollectionRegisterDelegator,
		[]argument{
			{
				Type:         "String",
				Name:         "id",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.03", "Register Node",
		env,
		templates.GenerateCollectionRegisterNodeOld,
		[]argument{
			{
				Type:         "String",
				Name:         "id",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "UInt8",
				Name:         "role",
				Label:        "Node Role",
				SampleValues: []cadenceValue{sampleNodeRole},
			},
			{
				Type:         "String",
				Name:         "networkingAddress",
				Label:        "Networking Address",
				SampleValues: []cadenceValue{sampleNetworkingAddress},
			},
			{
				Type:         "String",
				Name:         "networkingKey",
				Label:        "Networking Key",
				SampleValues: []cadenceValue{sampleNetworkingKey},
			},
			{
				Type:         "String",
				Name:         "stakingKey",
				Label:        "Staking Key",
				SampleValues: []cadenceValue{sampleStakingKey},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
			{
				Type:         "String",
				Name:         "machineAccountKey",
				Label:        "Machine Account Public Key",
				SampleValues: []cadenceValue{sampleKey},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeySignatureAlgorithm",
				Label:        "Raw Value for Machine Account Signature Algorithm Enum",
				SampleValues: []cadenceValue{sampleSigAlgoEnumRawValue},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeyHashAlgorithm",
				Label:        "Raw Value for Machine Account Hash Algorithm Enum",
				SampleValues: []cadenceValue{sampleHashAlgoEnumRawValue},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.04", "Create Machine Account",
		env,
		templates.GenerateCollectionCreateMachineAccountForNodeScript,
		[]argument{
			{
				Type:         "String",
				Name:         "id",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "String",
				Name:         "machineAccountKey",
				Label:        "Machine Account Public Key",
				SampleValues: []cadenceValue{sampleKey},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeySignatureAlgorithm",
				Label:        "Raw Value for Machine Account Signature Algorithm Enum",
				SampleValues: []cadenceValue{sampleSigAlgoEnumRawValue},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeyHashAlgorithm",
				Label:        "Raw Value for Machine Account Hash Algorithm Enum",
				SampleValues: []cadenceValue{sampleHashAlgoEnumRawValue},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.05", "Request Unstaking",
		env,
		templates.GenerateCollectionRequestUnstaking,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					sampleDelegatorIDOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.06", "Stake New Tokens",
		env,
		templates.GenerateCollectionStakeNewTokens,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					sampleDelegatorIDOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.07", "Stake Rewarded Tokens",
		env,
		templates.GenerateCollectionStakeRewardedTokens,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					sampleDelegatorIDOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.08", "Stake Unstaked Tokens",
		env,
		templates.GenerateCollectionStakeUnstakedTokens,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					sampleDelegatorIDOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.09", "Unstake All",
		env,
		templates.GenerateCollectionUnstakeAll,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.10", "Withdraw Rewarded Tokens",
		env,
		templates.GenerateCollectionWithdrawRewardedTokens,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleDelegatorIDOptional,
					sampleNullOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.11", "Withdraw Unstaked Tokens",
		env,
		templates.GenerateCollectionWithdrawUnstakedTokens,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					sampleDelegatorIDOptional,
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.12", "Close Stake",
		env,
		templates.GenerateCollectionCloseStake,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleDelegatorIDOptional,
					sampleNullOptional,
				},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.13", "Transfer Node",
		env,
		templates.GenerateCollectionTransferNode,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "Address",
				Name:         "address",
				Label:        "Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.14", "Transfer Delegator",
		env,
		templates.GenerateCollectionTransferDelegator,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "UInt32",
				Name:         "delegatorID",
				Label:        "Delegator ID",
				SampleValues: []cadenceValue{sampleDelegatorID},
			},
			{
				Type:         "Address",
				Name:         "address",
				Label:        "Address",
				SampleValues: []cadenceValue{sampleAddress(env.Network)},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.15", "Withdraw From Machine Account",
		env,
		templates.GenerateCollectionWithdrawFromMachineAccountScript,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.16", "Update Networking Address",
		env,
		templates.GenerateCollectionUpdateNetworkingAddressScript,
		[]argument{
			{
				Type:         "String",
				Name:         "nodeID",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "String",
				Name:         "address",
				Label:        "Address",
				SampleValues: []cadenceValue{sampleNetworkingAddress},
			},
		},
	))

	m.addTemplate(generateTemplate(
		"SCO.17", "Register Node",
		env,
		templates.GenerateCollectionRegisterNode,
		[]argument{
			{
				Type:         "String",
				Name:         "id",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:         "UInt8",
				Name:         "role",
				Label:        "Node Role",
				SampleValues: []cadenceValue{sampleNodeRole},
			},
			{
				Type:         "String",
				Name:         "networkingAddress",
				Label:        "Networking Address",
				SampleValues: []cadenceValue{sampleNetworkingAddress},
			},
			{
				Type:         "String",
				Name:         "networkingKey",
				Label:        "Networking Key",
				SampleValues: []cadenceValue{sampleNetworkingKey},
			},
			{
				Type:         "String",
				Name:         "stakingKey",
				Label:        "Staking Key",
				SampleValues: []cadenceValue{sampleStakingKey},
			},
			{
				Type:         "String",
				Name:         "stakingKeyPoP",
				Label:        "Staking Key PoP",
				SampleValues: []cadenceValue{sampleStakingKeyPoP},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
			{
				Type:         "String",
				Name:         "machineAccountKey",
				Label:        "Machine Account Public Key",
				SampleValues: []cadenceValue{sampleKey},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeySignatureAlgorithm",
				Label:        "Raw Value for Machine Account Signature Algorithm Enum",
				SampleValues: []cadenceValue{sampleSigAlgoEnumRawValue},
			},
			{
				Type:         "UInt8",
				Name:         "machineAccountKeyHashAlgorithm",
				Label:        "Raw Value for Machine Account Hash Algorithm Enum",
				SampleValues: []cadenceValue{sampleHashAlgoEnumRawValue},
			},
		},
	))

	return m
}

func sampleAddress(network string) cadenceValue {
	var address flow.Address

	switch network {
	case testnet:
		address = flow.NewAddressGenerator(flow.Testnet).NextAddress()
	case mainnet:
		address = flow.NewAddressGenerator(flow.Mainnet).NextAddress()
	}

	return cadenceValue{cadence.Address(address)}
}
