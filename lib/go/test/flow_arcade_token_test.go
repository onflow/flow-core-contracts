package test

import (
	"testing"

	emulator "github.com/dapperlabs/flow-emulator"
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

// Simple error-handling wrapper for Flow account creation.
func createAccount(t *testing.T, b *emulator.Blockchain, accountKeys *test.AccountKeys) (sdk.Address, crypto.Signer, *sdk.AccountKey) {
	accountKey, signer := accountKeys.NewWithSigner()
	address, err := b.CreateAccount([]*sdk.AccountKey{accountKey}, nil)
	require.NoError(t, err)
	return address, signer, accountKey
}

// Create a new Flow account that has the FAT vault installed.
func createFatReceiverAccount(t *testing.T, b *emulator.Blockchain, accountKeys *test.AccountKeys, fatAddress sdk.Address) (sdk.Address, crypto.Signer, *sdk.AccountKey) {
	address, signer, accountKey := createAccount(t, b, accountKeys)
	txSetupOne := flow.NewTransaction().
		SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(address)

	signAndSubmit(
		t, b, txSetupOne,
		[]flow.Address{b.ServiceKey().Address, address},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		false,
	)

	return address, signer, accountKey
}

// Get the address of the most recently deployed contract on the emulator blockchain.
func getDeployedContractAddress(t *testing.T, b *emulator.Blockchain) sdk.Address {
	// Get the deployed contract's address.
	var address sdk.Address

	//foundAddress:
	for i := uint64(0); i < 1000; i++ {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				address = sdk.Address(event.Value.Fields[0].(cadence.Address))
				// We want the last created address, and we created one before,
				// so we don't want to break when we find the first address as that
				// will be the wrong one.
				//break foundAddress
			}
		}
	}

	assert.NotEqual(t, address, sdk.EmptyAddress)

	return address
}

func TestFlowArcadeToken(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create admin and minter addresses and signers
	adminAddress, adminSigner, adminAccountKey := createAccount(t, b, accountKeys)
	nonAdminAddress, nonAdminSigner, _ := createAccount(t, b, accountKeys)
	minterAddress, minterSigner, _ := createAccount(t, b, accountKeys)

	// Deploy the Flow Arcade Token contract.

	// The admin account's keys, for adding to the contract.
	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(adminAccountKey.Encode())
	cadencePublicKeys := cadence.NewArray(publicKeys)

	fatCode := contracts.FlowArcadeToken(emulatorFTAddress)
	cadenceCode := bytesToCadenceArray(fatCode)

	// This implicitly tests that the contract code compiles and deploys.
	txDeploy := flow.NewTransaction().
		SetScript(templates.GenerateDeployFlowArcadeTokenScript()).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
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

	// Get the deployed contract's address.
	var fatAddress sdk.Address = getDeployedContractAddress(t, b)

	t.Run("Should be able to check total FAT supply", func(t *testing.T) {
		supplyAfterVend := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
		assert.Equal(t, supplyAfterVend.(cadence.UFix64), CadenceUFix64("0.0"))
	})

	t.Run("Should be able to set up account to receive FAT tokens", func(t *testing.T) {
		createFatReceiverAccount(t, b, accountKeys, fatAddress)
	})

	t.Run("Should be able to check individual account FAT vault balance", func(t *testing.T) {
		address, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)
		balanceOne, balanceOneError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(address))},
		)
		require.NoError(t, balanceOneError)
		assert.Equal(t, balanceOne.Value.(cadence.UFix64), CadenceUFix64("0.0"))
	})

	t.Run("Should not be able to set up account to receive FAT tokens twice", func(t *testing.T) {
		address, signer, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		txSetupOne := flow.NewTransaction().
			SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(address)

		signAndSubmit(
			t, b, txSetupOne,
			[]flow.Address{b.ServiceKey().Address, address},
			[]crypto.Signer{b.ServiceKey().Signer(), signer},
			true,
		)
	})

	// Create addresses to test token transfer.
	// This implicitly checks the account creation code.
	oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)
	twoAddress, twoSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)
	noFatVaultAddress, _, _ := createAccount(t, b, accountKeys)

	t.Run("Admin should be able to give minter capability to minter account", func(t *testing.T) {
		txAddMinter := flow.NewTransaction().
			SetScript(templates.GenerateAddMinterScript(fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress).
			AddAuthorizer(minterAddress)

		signAndSubmit(
			t, b, txAddMinter,
			[]flow.Address{b.ServiceKey().Address, adminAddress, minterAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner, minterSigner},
			false,
		)
	})

	t.Run("Admin should not be able to give minter capability to minter account twice", func(t *testing.T) {
		txAddMinter := flow.NewTransaction().
			SetScript(templates.GenerateAddMinterScript(fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress).
			AddAuthorizer(minterAddress)

		signAndSubmit(
			t, b, txAddMinter,
			[]flow.Address{b.ServiceKey().Address, adminAddress, minterAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner, minterSigner},
			true,
		)
	})

	t.Run("Non-admin should not be able to give minter capability to minter account", func(t *testing.T) {
		txAddMinter := flow.NewTransaction().
			SetScript(templates.GenerateAddMinterScript(fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(nonAdminAddress).
			AddAuthorizer(minterAddress)

		signAndSubmit(
			t, b, txAddMinter,
			[]flow.Address{b.ServiceKey().Address, nonAdminAddress, minterAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), nonAdminSigner, minterSigner},
			true,
		)
	})

	t.Run("Minter should be able to mint tokens to account with FAT vault", func(t *testing.T) {
		txVend := flow.NewTransaction().
			SetScript(templates.GenerateMintTokensScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
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

		// Make sure the mintee received the correct number of tokens.
		balanceOneAfterVend, balanceOneAfterVendError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(oneAddress))},
		)
		require.NoError(t, balanceOneAfterVendError)
		assert.Equal(t, balanceOneAfterVend.Value.(cadence.UFix64), CadenceUFix64("99.99"))

		// Make sure the total number of tokens in existence is correct.
		supplyAfterVend := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
		assert.Equal(t, supplyAfterVend.(cadence.UFix64), CadenceUFix64("99.99"))
	})

	t.Run("Minter should not be able to mint tokens to account without FAT vault", func(t *testing.T) {
		txVend := flow.NewTransaction().
			SetScript(templates.GenerateMintTokensScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)
		txVend.AddArgument(cadence.NewAddress(noFatVaultAddress))
		txVend.AddArgument(CadenceUFix64("99.99"))

		signAndSubmit(
			t, b, txVend,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			true,
		)
	})

	t.Run("Non-minter should not be able to mint tokens to account with FAT vault", func(t *testing.T) {
		txVend := flow.NewTransaction().
			SetScript(templates.GenerateMintTokensScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(nonAdminAddress)
		txVend.AddArgument(cadence.NewAddress(oneAddress))
		txVend.AddArgument(CadenceUFix64("99.99"))

		signAndSubmit(
			t, b, txVend,
			[]flow.Address{b.ServiceKey().Address, nonAdminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), nonAdminSigner},
			true,
		)
	})

	t.Run("Account with minted tokens should be able to transfer tokens to another account with FAT vault", func(t *testing.T) {
		// Set up the second account to receive tokens.
		txSetupTwo := flow.NewTransaction().
			SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(twoAddress)

		signAndSubmit(
			t, b, txSetupTwo,
			[]flow.Address{b.ServiceKey().Address, twoAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), twoSigner},
			false,
		)

		// Token vendee sends tokens to transfer reciever account.
		txTransfer := flow.NewTransaction().
			SetScript(templates.GenerateTransferTokensScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
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

		// Make sure each account has the correct number of tokens.
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

		// Make sure the total number of tokens in existence is still correct.
		supply := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
		assert.Equal(t, supply.(cadence.UFix64), CadenceUFix64("99.99"))
	})

	t.Run("Account with minted tokens should not be able to transfer tokens to another account without FAT vault", func(t *testing.T) {
		txTransfer := flow.NewTransaction().
			SetScript(templates.GenerateTransferTokensScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(oneAddress)
		txTransfer.AddArgument(CadenceUFix64("9.09"))
		txTransfer.AddArgument(cadence.NewAddress(noFatVaultAddress))

		signAndSubmit(
			t, b, txTransfer,
			[]flow.Address{b.ServiceKey().Address, oneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), oneSigner},
			true,
		)
	})
}
