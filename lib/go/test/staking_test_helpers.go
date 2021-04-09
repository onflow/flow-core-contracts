package test

import (
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

func deployStakingContract(t *testing.T,
	b *emulator.Blockchain,
	IDTableAccountKey *flow.AccountKey,
	env templates.Environment) flow.Address {

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

/// Used to verify staking info in tests
type StakingInfo struct {
	nodeID                   string
	delegatorID              uint32
	tokensCommitted          string
	tokensStaked             string
	tokensRequestedToUnstake string
	tokensUnstaking          string
	tokensUnstaked           string
	tokensRewarded           string
}

func verifyStakingInfo(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedStakingInfo StakingInfo,
) {

	if expectedStakingInfo.delegatorID == 0 {

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensCommitted), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensStaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRequestedToUnstake), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaking), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRewarded), result)
	} else {

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensCommitted), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensStaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRequestedToUnstake), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaking), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRewarded), result)
	}

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

func registerDelegator(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeID string,
	shouldFail bool,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateRegisterDelegatorScript(env),
		authorizer)

	_ = tx.AddArgument(cadence.NewString(nodeID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)
}

func endStakingMoveTokens(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeIDs []cadence.Value,
) {
	// End staking auction and epoch
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), authorizer)

	err := tx.AddArgument(cadence.NewArray(nodeIDs))
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		false,
	)
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
