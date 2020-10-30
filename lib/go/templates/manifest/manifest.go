package main

import (
	"crypto/sha256"
	"encoding/hex"

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
	Type  string `json:"type"`
	Name  string `json:"name"`
	Label string `json:"label"`
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

	m.addTemplate(generateTemplate(
		"TH.01", "Withdraw Unlocked FLOW",
		env,
		templates.GenerateWithdrawTokensScript,
		[]argument{{
			Type:  "UFix64",
			Name:  "amount",
			Label: "Amount",
		}},
	))

	m.addTemplate(generateTemplate(
		"TH.02", "Deposit Unlocked FLOW",
		env,
		templates.GenerateDepositTokensScript,
		[]argument{{
			Type:  "UFix64",
			Name:  "amount",
			Label: "Amount",
		}},
	))

	m.addTemplate(generateTemplate(
		"TH.06", "Register Node",
		env,
		templates.GenerateRegisterLockedNodeScript,
		[]argument{
			{
				Type:  "String",
				Name:  "id",
				Label: "Node ID",
			},
			{
				Type:  "UInt8",
				Name:  "role",
				Label: "Node Role",
			},
			{
				Type:  "String",
				Name:  "networkingAddress",
				Label: "Networking Address",
			},
			{
				Type:  "String",
				Name:  "networkingKey",
				Label: "Networking Key",
			},
			{
				Type:  "String",
				Name:  "stakingKey",
				Label: "Staking Key",
			},
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.08", "Stake New Locked FLOW",
		env,
		templates.GenerateStakeNewLockedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.09", "Re-stake Unstaked FLOW",
		env,
		templates.GenerateStakeLockedUnstakedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
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
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
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
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
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
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.14", "Withdraw Rewarded FLOW",
		env,
		templates.GenerateWithdrawLockedRewardedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.16", "Register Operator Node",
		env,
		templates.GenerateRegisterStakingProxyNodeScript,
		[]argument{
			{
				Type:  "Address",
				Name:  "address",
				Label: "Operator Address",
			},
			{
				Type:  "String",
				Name:  "id",
				Label: "Node ID",
			},
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.17", "Register Delegator",
		env,
		templates.GenerateRegisterDelegatorScript,
		[]argument{
			{
				Type:  "String",
				Name:  "id",
				Label: "Node ID",
			},
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.19", "Delegate New Locked FLOW",
		env,
		templates.GenerateDelegateNewLockedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.20", "Re-delegate Unstaked FLOW",
		env,
		templates.GenerateDelegateLockedUnstakedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.21", "Re-delegate Rewarded FLOW",
		env,
		templates.GenerateDelegateLockedRewardedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.22", "Unstake Delegated FLOW",
		env,
		templates.GenerateUnDelegateLockedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.23", "Withdraw Unstaked FLOW",
		env,
		templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	m.addTemplate(generateTemplate(
		"TH.24", "Withdraw Rewarded FLOW",
		env,
		templates.GenerateWithdrawDelegatorLockedRewardedTokensScript,
		[]argument{
			{
				Type:  "UFix64",
				Name:  "amount",
				Label: "Amount",
			},
		},
	))

	return m
}
