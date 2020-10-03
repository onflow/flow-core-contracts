package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	//"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	//"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestFlowArcadeToken(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create account for the admin role
	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, err := b.CreateAccount([]*sdk.AccountKey{adminAccountKey}, nil)
	require.NoError(t, err)

	// FIXME: These should be different
	// The admin account's keys, for adding to the contract
	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(adminAccountKey.Encode())
	cadencePublicKeys := cadence.NewArray(publicKeys)

	fatCode := contracts.FlowArcadeToken(emulatorFTAddress)
	cadenceCode := bytesToCadenceArray(fatCode)

	// Deploy the Flow Arcade Token contract
	txDeploy := flow.NewTransaction().
		SetScript(templates.GenerateDeployFlowArcadeTokenScript()).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddAuthorizer(adminAddress)
	txDeploy.AddArgument(cadencePublicKeys)
	txDeploy.AddArgument(cadenceCode)

	signAndSubmit(
		t, b, txDeploy,
		[]flow.Address{b.ServiceKey().Address, adminAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
		false,
	)

	// Get the deployed contract's address
	var fatAddress sdk.Address

	//foundAddress:
	for i := uint64(0); i < 1000; i++ {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				fatAddress = sdk.Address(event.Value.Fields[0].(cadence.Address))
				// We want the last created address, and we created one before,
				// so we don't want to break when we find the first address as that
				// will be the wrong one.
				//break foundAddress
			}
		}
	}

	assert.NotEqual(t, fatAddress, sdk.EmptyAddress)

	// Create account for the minter role
	minterAccountKey, minterSigner := accountKeys.NewWithSigner()
	minterAddress, minterCreateAccountErr := b.CreateAccount([]*sdk.AccountKey{minterAccountKey}, nil)
	require.NoError(t, minterCreateAccountErr)

	// Admin gives minter capability to minter account
	txAddMinter := flow.NewTransaction().
		SetScript(templates.GenerateAddMinterScript(fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(adminAddress).
		AddAuthorizer(minterAddress)

	signAndSubmit(
		t, b, txAddMinter,
		[]flow.Address{b.ServiceKey().Address, adminAddress, minterAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), adminSigner, minterSigner},
		false,
	)

	// Create account for the first mintee
	oneKey, oneSigner := accountKeys.NewWithSigner()
	oneAddress, oneCreateAccountErr := b.CreateAccount([]*sdk.AccountKey{oneKey}, nil)
	require.NoError(t, oneCreateAccountErr)

	// Set up account to receive minted tokens

	txSetupOne := flow.NewTransaction().
		SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(oneAddress)

	signAndSubmit(
		t, b, txSetupOne,
		[]flow.Address{b.ServiceKey().Address, oneAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), oneSigner},
		false,
	)

	// Minter mints tokens to first mintee
	txVend := flow.NewTransaction().
		SetScript(templates.GenerateMintTokensScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(adminAddress)
	txVend.AddArgument(cadence.NewAddress(oneAddress))
	txVend.AddArgument(CadenceUFix64("99.99"))

	signAndSubmit(
		t, b, txVend,
		[]flow.Address{b.ServiceKey().Address, adminAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
		false,
	)

	// Make sure the mintee received the correct number of tokens
	balanceOneAfterVend, balanceOneAfterVendError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(oneAddress))},
	)
	require.NoError(t, balanceOneAfterVendError)
	assert.Equal(t, balanceOneAfterVend.Value.(cadence.UFix64), CadenceUFix64("99.99"))

	// Make sure the total number of tokens in existence is correct
	supplyAfterVend := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
	assert.Equal(t, supplyAfterVend.(cadence.UFix64), CadenceUFix64("99.99"))

	// Account for the token transfer receiver
	twoKey, twoSigner := accountKeys.NewWithSigner()
	twoAddress, twoCreateAccountErr := b.CreateAccount([]*sdk.AccountKey{twoKey}, nil)
	require.NoError(t, twoCreateAccountErr)

	// Set up the second account to receive tokens

	txSetupTwo := flow.NewTransaction().
		SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(twoAddress)

	signAndSubmit(
		t, b, txSetupTwo,
		[]flow.Address{b.ServiceKey().Address, twoAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), twoSigner},
		false,
	)

	// Token vendee sends tokens to transfer reciever account

	txTransfer := flow.NewTransaction().
		SetScript(templates.GenerateTransferTokensScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(oneAddress)
	txTransfer.AddArgument(CadenceUFix64("9.09"))
	txTransfer.AddArgument(cadence.NewAddress(twoAddress))

	signAndSubmit(
		t, b, txTransfer,
		[]flow.Address{b.ServiceKey().Address, oneAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), oneSigner},
		false,
	)

	// Make sure each account has the correct number of tokens
	balanceOneAfterTransfer, balanceOneAfterTransferError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(oneAddress))},
	)

	require.NoError(t, balanceOneAfterTransferError)
	assert.Equal(t, balanceOneAfterTransfer.Value.(cadence.UFix64), CadenceUFix64("90.9"))
	balanceTwoAfterTransfer, balanceTwoAfterTransferError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(twoAddress))},
	)
	require.NoError(t, balanceTwoAfterTransferError)
	assert.Equal(t, balanceTwoAfterTransfer.Value.(cadence.UFix64), CadenceUFix64("9.09"))

	// Make sure the total number of tokens in existence is still correct
	supply := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
	assert.Equal(t, supply.(cadence.UFix64), CadenceUFix64("99.99"))
}
