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
	v.Value, err = jsoncdc.Decode(bytes)
	if err != nil {
		return err
	}

	return nil
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

	sampleAmount := cadenceValue{sampleAmountRaw}

	sampleNodeID := cadenceValue{
		cadence.NewString("88549335e1db7b5b46c2ad58ddb70b7a45e770cc5fe779650ba26f10e6bae5e6"),
	}

	sampleNullOptional := cadenceValue{cadence.NewOptional(nil)}

	sampleDelegatorID := cadenceValue{cadence.NewOptional(
		cadence.NewUInt32(42),
	)}

	samplePublicKeys := cadenceValue{cadence.NewOptional(
		cadence.NewArray([]cadence.Value{
			cadence.NewString("f845b8406e4f43f79d3c1d8cacb3d5f3e7aeedb29feaeb4559fdb71a97e2fd0438565310e87670035d83bc10fe67fe314dba5363c81654595d64884b1ecad1512a64e65e020164"),
		}),
	)}

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
		templates.GenerateCollectionRegisterNode,
		[]argument{
			{
				Type:         "String",
				Name:         "id",
				Label:        "Node ID",
				SampleValues: []cadenceValue{sampleNodeID},
			},
			{
				Type:  "UInt8",
				Name:  "role",
				Label: "Node Role",
				SampleValues: []cadenceValue{
					{cadence.NewUInt8(1)},
				},
			},
			{
				Type:  "String",
				Name:  "networkingAddress",
				Label: "Networking Address",
				SampleValues: []cadenceValue{
					{cadence.NewString("flow-node.test:3569")},
				},
			},
			{
				Type:  "String",
				Name:  "networkingKey",
				Label: "Networking Key",
				SampleValues: []cadenceValue{
					{
						cadence.NewString(
							"1348307bc77c688e80049de9d081aa09755da33e6997605fa059db2144fc85e560cbe6f7da8d74b453f5916618cb8fd392c2db856f3e78221dc68db1b1d914e4",
						),
					},
				},
			},
			{
				Type:  "String",
				Name:  "stakingKey",
				Label: "Staking Key",
				SampleValues: []cadenceValue{
					{
						cadence.NewString(
							"9e9ae0d645fd5fd9050792e0b0daa82cc1686d9133afa0f81a784b375c42ae48567d1545e7a9e1965f2c1a32f73cf8575ebb7a967f6e4d104d2df78eb8be409135d12da0499b8a00771f642c1b9c49397f22b440439f036c3bdee82f5309dab3",
						),
					},
				},
			},
			{
				Type:         "UFix64",
				Name:         "amount",
				Label:        "Amount",
				SampleValues: []cadenceValue{sampleAmount},
			},
			{
				Type:  "[String]?",
				Name:  "publicKeys",
				Label: "Public Keys",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					samplePublicKeys,
				},
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
				Type:  "[String]?",
				Name:  "publicKseys",
				Label: "Public Keys",
				SampleValues: []cadenceValue{
					sampleNullOptional,
					samplePublicKeys,
				},
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
					sampleDelegatorID,
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
				Type:  "UInt32?",
				Name:  "delegatorID",
				Label: "Delegator ID",
				SampleValues: []cadenceValue{
					sampleDelegatorID,
					sampleNullOptional,
				},
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
