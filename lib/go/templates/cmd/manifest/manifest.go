package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"

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
	Type        string `json:"type"`
	Name        string `json:"name"`
	Label       string `json:"label"`
	SampleValue string `json:"sampleValue"`
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

	sampleAmount := "92233720368.54775808"
	sampleNodeID := "88549335e1db7b5b46c2ad58ddb70b7a45e770cc5fe779650ba26f10e6bae5e6"

	m.addTemplate(generateTemplate(
		"TH.01", "Withdraw Unlocked FLOW",
		env,
		templates.GenerateWithdrawTokensScript,
		[]argument{{
			Type:        "UFix64",
			Name:        "amount",
			Label:       "Amount",
			SampleValue: "92233720368.54775808",
		}},
	))

	m.addTemplate(generateTemplate(
		"TH.02", "Deposit Unlocked FLOW",
		env,
		templates.GenerateDepositTokensScript,
		[]argument{{
			Type:        "UFix64",
			Name:        "amount",
			Label:       "Amount",
			SampleValue: sampleAmount,
		}},
	))

	m.addTemplate(generateTemplate(
		"TH.06", "Register Node",
		env,
		templates.GenerateRegisterLockedNodeScript,
		[]argument{
			{
				Type:        "String",
				Name:        "id",
				Label:       "Node ID",
				SampleValue: sampleNodeID,
			},
			{
				Type:        "UInt8",
				Name:        "role",
				Label:       "Node Role",
				SampleValue: "1",
			},
			{
				Type:        "String",
				Name:        "networkingAddress",
				Label:       "Networking Address",
				SampleValue: "flow-node.test:3569",
			},
			{
				Type:        "String",
				Name:        "networkingKey",
				Label:       "Networking Key",
				SampleValue: "1348307bc77c688e80049de9d081aa09755da33e6997605fa059db2144fc85e560cbe6f7da8d74b453f5916618cb8fd392c2db856f3e78221dc68db1b1d914e4",
			},
			{
				Type:        "String",
				Name:        "stakingKey",
				Label:       "Staking Key",
				SampleValue: "9e9ae0d645fd5fd9050792e0b0daa82cc1686d9133afa0f81a784b375c42ae48567d1545e7a9e1965f2c1a32f73cf8575ebb7a967f6e4d104d2df78eb8be409135d12da0499b8a00771f642c1b9c49397f22b440439f036c3bdee82f5309dab3",
			},
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.08", "Stake New Locked FLOW",
		env,
		templates.GenerateStakeNewLockedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.09", "Re-stake Unstaked FLOW",
		env,
		templates.GenerateStakeLockedUnstakedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.10",
		"Re-stake Rewarded FLOW",
		env,
		templates.GenerateStakeLockedRewardedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.11",
		"Request Unstake of FLOW",
		env,
		templates.GenerateUnstakeLockedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.12", "Unstake All FLOW",
		env,
		templates.GenerateUnstakeAllLockedTokensScript,
		[]argument{},
	))

	m.addTemplate(generateTemplate(
		"TH.13", "Withdraw Unstaked FLOW",
		env,
		templates.GenerateWithdrawLockedUnstakedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.14", "Withdraw Rewarded FLOW",
		env,
		templates.GenerateWithdrawLockedRewardedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.16", "Register Operator Node",
		env,
		templates.GenerateRegisterStakingProxyNodeScript,
		[]argument{
			{
				Type:        "Address",
				Name:        "address",
				Label:       "Operator Address",
				SampleValue: sampleAddress(env.Network),
			},
			{
				Type:        "String",
				Name:        "id",
				Label:       "Node ID",
				SampleValue: sampleNodeID,
			},
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.17", "Register Delegator",
		env,
		templates.GenerateCreateLockedDelegatorScript,
		[]argument{
			{
				Type:        "String",
				Name:        "id",
				Label:       "Node ID",
				SampleValue: sampleNodeID,
			},
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.19", "Delegate New Locked FLOW",
		env,
		templates.GenerateDelegateNewLockedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.20", "Re-delegate Unstaked FLOW",
		env,
		templates.GenerateDelegateLockedUnstakedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.21", "Re-delegate Rewarded FLOW",
		env,
		templates.GenerateDelegateLockedRewardedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.22", "Unstake Delegated FLOW",
		env,
		templates.GenerateUnDelegateLockedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.23", "Withdraw Unstaked FLOW",
		env,
		templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.24", "Withdraw Rewarded FLOW",
		env,
		templates.GenerateWithdrawDelegatorLockedRewardedTokensScript,
		[]argument{
			{
				Type:        "UFix64",
				Name:        "amount",
				Label:       "Amount",
				SampleValue: sampleAmount,
			},
		},
	))

	return m
}

func sampleAddress(network string) string {
	var address flow.Address

	switch network {
	case testnet:
		address = flow.NewAddressGenerator(flow.Testnet).NextAddress()
	case mainnet:
		address = flow.NewAddressGenerator(flow.Mainnet).NextAddress()
	}

	return fmt.Sprintf("0x%s", address.Hex())
}
