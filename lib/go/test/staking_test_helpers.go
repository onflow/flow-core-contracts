package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	emulatorFTAddress        = "ee82856bf20e2aa6"
	emulatorFlowTokenAddress = "0ae53cb6e3f42a79"
)

func deployStakingContract(t *testing.T, b *emulator.Blockchain, IDTableAccountKey *flow.AccountKey, env templates.Environment) flow.Address {

	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateTransferMinterAndDeployScript(env),
		b.ServiceKey().Address)

	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))
	tx.AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowIDTableStaking")))
	tx.AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == flow.EventAccountCreated {
				idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	return idTableAddress
}

func generateNodeIDs(numNodes int) ([]string, []cadence.Value, []cadence.Value) {
	ids := make([]string, numNodes)
	qcIDs := make([]cadence.Value, numNodes/5+1)
	dkgIDs := make([]cadence.Value, numNodes/5+1)

	for i := 0; i < numNodes; i++ {
		ids[i] = fmt.Sprintf("%064d", i)

		if i == 0 {
			qcIDs[i/5] = cadence.NewString(ids[i])
		} else if i == 1 {
			dkgIDs[i/5] = cadence.NewString(ids[i])
		}
	}

	return ids, qcIDs, dkgIDs
}

func registerNode(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeID, networkingAddress, networkingKey, stakingKey string,
	amount, tokensCommitted interpreter.UFix64Value,
	role uint8,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateRegisterNodeScript(env),
		authorizer)

	_ = tx.AddArgument(cadence.NewString(nodeID))
	_ = tx.AddArgument(cadence.NewUInt8(role))
	_ = tx.AddArgument(cadence.NewString(networkingAddress))
	_ = tx.AddArgument(cadence.NewString(networkingKey))
	_ = tx.AddArgument(cadence.NewString(stakingKey))
	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	_ = tx.AddArgument(tokenAmount)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
	}

	return
}

/// Registers the specified number of nodes for staking with the specified IDs
/// Does an even distrubution of node roles
func registerNodesForStaking(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizers []flow.Address,
	signers []crypto.Signer,
	ids []string) {

	if len(authorizers) != len(signers) ||
		len(authorizers) != len(ids) {
		t.Fail()
	}

	var amountToCommit interpreter.UFix64Value = 135000000000000
	var committed interpreter.UFix64Value = 0

	i := 0
	for _, authorizer := range authorizers {

		registerNode(t, b, env,
			authorizer,
			signers[i],
			ids[i],
			fmt.Sprintf("%0128d", i),
			fmt.Sprintf("%0128d", i),
			fmt.Sprintf("%0192d", i),
			amountToCommit,
			committed,
			uint8((i%5)+1),
			false)

		i++
	}
}

func commitNewTokens(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeNewTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
	} else {
		newTokensCommitted = tokensCommitted
	}

	return
}

func commitUnstaked(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensUnstaked interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
	newTokensUnstaked interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeUnstakedTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
		newTokensUnstaked = tokensUnstaked.Minus(amount).(interpreter.UFix64Value)
	} else {
		newTokensCommitted = tokensCommitted
		newTokensUnstaked = tokensUnstaked
	}

	return
}

func commitRewarded(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensRewarded interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted, newTokensRewarded interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeRewardedTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensRewarded = tokensRewarded.Minus(amount).(interpreter.UFix64Value)
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
	} else {
		newTokensRewarded = tokensRewarded
		newTokensCommitted = tokensCommitted
	}

	return
}

func requestUnstaking(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensUnstaked, request interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted, newTokensUnstaked, newRequest interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateUnstakeTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		if tokensCommitted > amount {
			newTokensCommitted = tokensCommitted.Minus(amount).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(amount).(interpreter.UFix64Value)
			newRequest = request
		} else {
			newRequest = request.Plus(amount.Minus(tokensCommitted)).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(tokensCommitted).(interpreter.UFix64Value)
			newTokensCommitted = 0
		}
	} else {
		newRequest = request
		newTokensUnstaked = tokensUnstaked
		newTokensCommitted = tokensCommitted
	}

	return
}

func payRewards(
	isDelegator bool,
	totalPayout, totalStaked, cut, staked interpreter.UFix64Value,
) (
	rewards, delegateeRewards interpreter.UFix64Value,
) {
	calculatedRewards := totalPayout.Div(totalStaked).Mul(staked).(interpreter.UFix64Value)

	if isDelegator {
		delegateeRewards = calculatedRewards.Mul(cut).(interpreter.UFix64Value)
		rewards = calculatedRewards.Minus(delegateeRewards).(interpreter.UFix64Value)

	} else {
		delegateeRewards = 0
		rewards = calculatedRewards
	}

	return
}

func moveTokens(committed, staked, requested, unstaking, unstaked, totalStaked interpreter.UFix64Value,
) (
	newCommitted, newStaked, newRequested, newUnstaking, newUnstaked, newTotalStaked interpreter.UFix64Value,
) {
	newTotalStaked = totalStaked.Plus(committed).Minus(requested).(interpreter.UFix64Value)

	newCommitted = 0

	newStaked = staked.Plus(committed).(interpreter.UFix64Value)

	newUnstaked = unstaked.Plus(unstaking).(interpreter.UFix64Value)

	newUnstaking = requested

	newStaked = newStaked.Minus(requested).(interpreter.UFix64Value)

	newRequested = 0

	return
}
