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

const (
	uniqueMinterPathFragment = "aaff0033bb"
	minterResourcePath       = "/storage/minter" + uniqueMinterPathFragment
	minterCapabilityPath     = "/private/minter" + uniqueMinterPathFragment
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

	txSetup := flow.NewTransaction().
		SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(address)

	signAndSubmit(
		t, b, txSetup,
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

// Vend tokens to an account - this can and should fail in various ways
// if the minter or recipient accounts are incorrectly configured.
func vendTokens(
	t *testing.T,
	b *emulator.Blockchain,
	fatAddress sdk.Address,
	minterAddress sdk.Address,
	minterSigner crypto.Signer,
	recipientAddress sdk.Address,
	amount string,
	shouldRevert bool,
) {
	// Get pre state
	totalPreBalance := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
	recipientPreBalance, recipientPreBalanceError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(recipientAddress))},
	)
	require.NoError(t, recipientPreBalanceError)

	cadenceAmount := CadenceUFix64(amount)

	// Admin vends tokens to receiver account
	txVend := flow.NewTransaction().
		SetScript(templates.GenerateMintTokensScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(minterAddress)
	txVend.AddArgument(cadence.NewAddress(recipientAddress))
	txVend.AddArgument(cadenceAmount)

	signAndSubmit(
		t, b, txVend,
		[]flow.Address{b.ServiceKey().Address, minterAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), minterSigner},
		shouldRevert,
	)

	// Only check state if transaction should have gone through
	if !shouldRevert {
		// Get post state
		totalPostBalance := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
		recipientPostBalance, recipientPostBalanceError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(recipientAddress))},
		)
		require.NoError(t, recipientPostBalanceError)

		uint64Amount := cadenceAmount.ToGoValue().(uint64)

		// Make sure state has been correctly updated
		require.Equal(
			t,
			totalPreBalance.(cadence.UFix64).ToGoValue().(uint64),
			totalPostBalance.(cadence.UFix64).ToGoValue().(uint64)-uint64Amount,
		)
		require.EqualValues(
			t,
			recipientPostBalance.Value.(cadence.UFix64).ToGoValue().(uint64),
			recipientPreBalance.Value.(cadence.UFix64).ToGoValue().(uint64)+uint64Amount,
		)
	}
}

// Transfer tokens to an account - this can and should fail in various ways
// if the sender or receiver are incorrectly configured.
func transferTokens(
	t *testing.T,
	b *emulator.Blockchain,
	fatAddress sdk.Address,
	adminAddress sdk.Address,
	adminSigner crypto.Signer,
	senderAddress sdk.Address,
	senderSigner crypto.Signer,
	receiverAddress sdk.Address,
	amount string,
	shouldRevert bool,
) {
	// Get pre state
	totalPreBalance := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
	senderPreBalance, senderPreBalanceError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(senderAddress))},
	)
	require.NoError(t, senderPreBalanceError)
	receiverPreBalance, receiverPreBalanceError := b.ExecuteScript(
		templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
		[][]byte{jsoncdc.MustEncode(cadence.Address(receiverAddress))},
	)
	require.NoError(t, receiverPreBalanceError)

	cadenceAmount := CadenceUFix64(amount)

	// Perform the transfer
	txTransfer := flow.NewTransaction().
		SetScript(templates.GenerateTransferTokensScript(emulatorFTAddress, fatAddress.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(senderAddress)
	txTransfer.AddArgument(cadenceAmount)
	txTransfer.AddArgument(cadence.NewAddress(receiverAddress))

	signAndSubmit(
		t, b, txTransfer,
		[]flow.Address{b.ServiceKey().Address, senderAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), senderSigner},
		shouldRevert,
	)

	// Only check state if transfer should have gone through
	if !shouldRevert {
		// Get post state
		totalPostBalance := executeScriptAndCheck(t, b, templates.GenerateGetSupplyScript(fatAddress.String()))
		senderPostBalance, senderPostBalanceError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(senderAddress))},
		)
		require.NoError(t, senderPostBalanceError)
		receiverPostBalance, receiverPostBalanceError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(receiverAddress))},
		)
		require.NoError(t, receiverPostBalanceError)

		// Make sure state has been correctly updated
		require.Equal(t, totalPreBalance, totalPostBalance)

		uint64Amount := cadenceAmount.ToGoValue().(uint64)

		require.EqualValues(
			t,
			senderPostBalance.Value.(cadence.UFix64).ToGoValue().(uint64),
			senderPreBalance.Value.(cadence.UFix64).ToGoValue().(uint64)-uint64Amount,
		)
		require.EqualValues(
			t,
			receiverPostBalance.Value.(cadence.UFix64).ToGoValue().(uint64),
			receiverPreBalance.Value.(cadence.UFix64).ToGoValue().(uint64)+uint64Amount,
		)
	}
}

func TestFlowArcadeToken(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create admin and minter addresses and signers
	adminAddress, adminSigner, adminAccountKey := createAccount(t, b, accountKeys)
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

	t.Run("Minter should be able to set up minter account to receive minter capability", func(t *testing.T) {
		txSetupMinter := flow.NewTransaction().
			SetScript(templates.GenerateSetupMinterAccountScript(fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(minterAddress)

		signAndSubmit(
			t, b, txSetupMinter,
			[]flow.Address{b.ServiceKey().Address, minterAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), minterSigner},
			false,
		)
	})

	t.Run("Admin should be able to deposit minter capability to a configured account", func(t *testing.T) {
		txAddMinter := flow.NewTransaction().
			// This is slightly hacky but we can't pass paths in as arguments yet.
			SetScript(templates.GenerateDepositMinterCapabilityScript(
				fatAddress.String(),
				minterResourcePath,
				minterCapabilityPath,
			)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		txAddMinter.AddArgument(cadence.NewAddress(minterAddress))
		// We can't do this yet
		//txAddMinter.AddArgument(minterResourcePath)
		//txAddMinter.AddArgument(minterCapabilityPath)

		signAndSubmit(
			t, b, txAddMinter,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)
	})

	t.Run("Non-admin should not be able to give minter capability to an account", func(t *testing.T) {
		nonAdminAddress, nonAdminSigner, _ := createAccount(t, b, accountKeys)

		txAddMinter := flow.NewTransaction().
			// This is slightly hacky but we can't pass paths in as arguments yet.
			SetScript(templates.GenerateDepositMinterCapabilityScript(
				fatAddress.String(),
				minterResourcePath,
				minterCapabilityPath,
			)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(nonAdminAddress)

		txAddMinter.AddArgument(cadence.NewAddress(minterAddress))
		// We can't do this yet
		//txAddMinter.AddArgument(minterResourcePath)
		//txAddMinter.AddArgument(minterCapabilityPath)

		signAndSubmit(
			t, b, txAddMinter,
			[]flow.Address{b.ServiceKey().Address, nonAdminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), nonAdminSigner},
			true,
		)
	})

	t.Run("Minter should not be able to copy minter capability from minter proxy", func(t *testing.T) {
		txCopyMinter := flow.NewTransaction().
			SetScript([]byte(templates.ReplaceFATAddress(`
import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction() {

	let minterProxy: &FlowArcadeToken.MinterProxy

    prepare(minterAccount: AuthAccount) {
		self.minterProxy = minterAccount.borrow<&FlowArcadeToken.MinterProxy>(from: FlowArcadeToken.MinterProxyStoragePath)!
	}

	execute {
		let cap = self.minterProxy.minterCapability!
	}

}`, fatAddress.String()))).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(minterAddress)

		result := signAndSubmit(
			t, b, txCopyMinter,
			[]flow.Address{b.ServiceKey().Address, minterAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), minterSigner},
			true,
		)

		assert.Equal(
			t,
			"Execution failed:\nChecking failed:\n    cannot access `minterCapability`: field has private access\n",
			result.Error.Error(),
		)
	})

	t.Run("Minter should be able to mint tokens to account with FAT vault", func(t *testing.T) {
		oneAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "99.99", false)
	})

	t.Run("Minter should be able to mint tokens to account with FAT vault multiple times", func(t *testing.T) {
		address, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		for i := 0; i < 10; i++ {
			vendTokens(t, b, fatAddress, minterAddress, minterSigner, address, "1.0", false)
		}
	})

	t.Run("Minter should not be able to mint tokens to account without FAT vault", func(t *testing.T) {
		noFatVaultAddress, _, _ := createAccount(t, b, accountKeys)

		vendTokens(t, b, fatAddress, minterAddress, minterSigner, noFatVaultAddress, "99.99", true)
	})

	t.Run("Non-minter should not be able to mint tokens to account with FAT vault", func(t *testing.T) {
		nonMinterAddress, nonMinterSigner, _ := createAccount(t, b, accountKeys)
		noFatVaultAddress, _, _ := createAccount(t, b, accountKeys)

		vendTokens(t, b, fatAddress, nonMinterAddress, nonMinterSigner, noFatVaultAddress, "99.99", true)
	})

	t.Run("Account without tokens should not be able to transfer any", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		twoAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			twoAddress,
			"9.09",
			true,
		)
	})

	t.Run("Account with insufficient tokens should not be able to transfer a larger amount", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		// Admin vends tokens to first account
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "1.0", false)

		twoAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			twoAddress,
			"100.0",
			true,
		)
	})

	t.Run("Account with minted tokens should be able to transfer tokens to another account with FAT vault", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		// Admin vends tokens to first account
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "99.99", false)

		twoAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			twoAddress,
			"9.09",
			false,
		)
	})

	t.Run("Account should be able to transfer its entire balance", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		// Admin vends tokens to first account
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "100.0", false)

		twoAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			twoAddress,
			"100.0",
			false,
		)
	})

	t.Run("Account should be able to transfer its entire balance then receive more tokens", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		// Admin vends tokens to first account
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "100.0", false)

		twoAddress, _, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			twoAddress,
			"100.0",
			false,
		)

		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "1000.0", false)
	})

	t.Run("Accounts with tokens should be able to transfer them multiple times", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		// Admin vends tokens to first account
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "99.99", false)

		twoAddress, twoSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)

		for i := 0; i < 10; i++ {
			transferTokens(
				t,
				b,
				fatAddress,
				adminAddress,
				adminSigner,
				oneAddress,
				oneSigner,
				twoAddress,
				"10.1",
				false,
			)

			transferTokens(
				t,
				b,
				fatAddress,
				adminAddress,
				adminSigner,
				twoAddress,
				twoSigner,
				oneAddress,
				"1.1",
				false,
			)
		}
	})

	t.Run("Account with minted tokens should not be able to transfer tokens to another account without FAT vault", func(t *testing.T) {
		oneAddress, oneSigner, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, oneAddress, "99.99", false)

		noFatVaultAddress, _, _ := createAccount(t, b, accountKeys)

		transferTokens(
			t,
			b,
			fatAddress,
			adminAddress,
			adminSigner,
			oneAddress,
			oneSigner,
			noFatVaultAddress,
			"9.09",
			true,
		)
	})

	t.Run("Should not replace vault if user tries to set up account twice", func(t *testing.T) {
		address, signer, _ := createFatReceiverAccount(t, b, accountKeys, fatAddress)
		vendTokens(t, b, fatAddress, minterAddress, minterSigner, address, "10.11", false)

		// Try to set up account again. This should not error,
		// but it should also not replace the originally created vault.

		txSetupAgain := flow.NewTransaction().
			SetScript(templates.GenerateSetupAccountScript(emulatorFTAddress, fatAddress.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(address)

		signAndSubmit(
			t, b, txSetupAgain,
			[]flow.Address{b.ServiceKey().Address, address},
			[]crypto.Signer{b.ServiceKey().Signer(), signer},
			false,
		)

		// The existing vault should not have been replaced.
		// To establish this, we check that it still has its value.
		balance, balanceError := b.ExecuteScript(
			templates.GenerateGetBalanceScript(emulatorFTAddress, fatAddress.String()),
			[][]byte{jsoncdc.MustEncode(cadence.Address(address))},
		)
		require.NoError(t, balanceError)
		assert.Equal(t, balance.Value.(cadence.UFix64), CadenceUFix64("10.11"))
	})
}
