package test

import (
	"encoding/hex"
	"testing"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// TODO: Move this to separate Cadence file
const deployKeyManagerScript = `
transaction(code: String, path: Path) {
  prepare(tokenHolder: AuthAccount, admin: AuthAccount, serviceAccount: AuthAccount) {
    tokenHolder.contracts.add(name: "TokenHolderKeyManager", code: code.decodeHex(), admin, path) 
  }
}
`

func TestKeyManager(t *testing.T) {
	b, err := emulator.NewBlockchain()
	require.NoError(t, err)

	keyManagerAddress, err := b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "KeyManager",
			Source: string(contracts.KeyManager()),
		},
	})
	require.NoError(t, err)

	env := templates.Environment{KeyManagerAddress: keyManagerAddress.Hex()}

	accountKeys := test.AccountKeyGenerator()

	adminKey, adminSigner := accountKeys.NewWithSigner()
	tempKey, tempSigner := accountKeys.NewWithSigner()
	backupKey, backupSigner := accountKeys.NewWithSigner()

	adminAddress, err := b.CreateAccount([]*flow.AccountKey{adminKey}, nil)
	require.NoError(t, err)

	tokenHolderAddress, err := b.CreateAccount([]*flow.AccountKey{tempKey}, nil)
	require.NoError(t, err)

	deployTokenHolderKeyManager(t, b, env, tokenHolderAddress, adminAddress, tempSigner, adminSigner)

	removeTempKey(t, b, tokenHolderAddress, tempSigner)

	// addBackupKey should fail with incorrect token holder address
	err = addBackupKey(t, b, env, adminAddress, tokenHolderAddress, adminAddress, adminSigner, backupKey)
	require.Error(t, err)

	// addBackupKey should succeed with correct token holder address
	err = addBackupKey(t, b, env, tokenHolderAddress, tokenHolderAddress, adminAddress, adminSigner, backupKey)
	require.NoError(t, err)

	// should fail to sign with temp key
	err = checkKeyCanSign(t, b, tokenHolderAddress, 0, tempSigner)
	assert.Error(t, err)

	// should successfully sign with backup key
	err = checkKeyCanSign(t, b, tokenHolderAddress, 1, backupSigner)
	assert.NoError(t, err)
}

func deployTokenHolderKeyManager(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	tokenHolderAddress flow.Address,
	adminAddress flow.Address,
	tempSigner crypto.Signer,
	adminSigner crypto.Signer,
) {
	tx := flow.NewTransaction().
		SetScript([]byte(deployKeyManagerScript)).
		SetGasLimit(100).
		SetPayer(b.ServiceKey().Address).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		AddAuthorizer(tokenHolderAddress).
		AddAuthorizer(adminAddress).
		AddAuthorizer(b.ServiceKey().Address)

	code := cadence.NewString(
		hex.EncodeToString(contracts.TokenHolderKeyManager(env.KeyManagerAddress)),
	)

	err := tx.AddArgument(code)
	require.NoError(t, err)

	err = tx.AddArgument(pathForTokenHolder(tokenHolderAddress))
	require.NoError(t, err)

	err = tx.SignPayload(tokenHolderAddress, 0, tempSigner)
	require.NoError(t, err)

	err = tx.SignPayload(adminAddress, 0, adminSigner)
	require.NoError(t, err)

	err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, err)

	err = b.AddTransaction(*tx)
	require.NoError(t, err)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	require.NoError(t, result.Error)

	_, err = b.CommitBlock()
	require.NoError(t, err)
}

func removeTempKey(
	t *testing.T,
	b *emulator.Blockchain,
	tokenHolderAddress flow.Address,
	tempSigner crypto.Signer,
) {
	tx := sdktemplates.RemoveAccountKey(tokenHolderAddress, 0)
	tx.
		SetGasLimit(100).
		SetPayer(b.ServiceKey().Address).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber)

	err := tx.SignPayload(tokenHolderAddress, 0, tempSigner)
	require.NoError(t, err)

	err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, err)

	err = b.AddTransaction(*tx)
	require.NoError(t, err)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	require.NoError(t, result.Error)

	_, err = b.CommitBlock()
	require.NoError(t, err)
}

func addBackupKey(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	tokenHolderAddress flow.Address,
	pathAddress flow.Address,
	adminAddress flow.Address,
	adminSigner crypto.Signer,
	backupKey *flow.AccountKey,
) error {
	tx := flow.NewTransaction().
		SetScript(templates.GenerateAddKeyScript(env)).
		SetGasLimit(100).
		SetPayer(b.ServiceKey().Address).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		AddAuthorizer(adminAddress)

	err := tx.AddArgument(cadence.Address(tokenHolderAddress))
	require.NoError(t, err)

	err = tx.AddArgument(cadence.NewString(hex.EncodeToString(backupKey.Encode())))
	require.NoError(t, err)

	err = tx.AddArgument(pathForTokenHolder(pathAddress))
	require.NoError(t, err)

	err = tx.SignPayload(adminAddress, 0, adminSigner)
	require.NoError(t, err)

	err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, err)

	err = b.AddTransaction(*tx)
	require.NoError(t, err)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return result.Error
}

const checkScript = `transaction { prepare(tokenHolder: AuthAccount) { log(tokenHolder.address) } }`

func checkKeyCanSign(
	t *testing.T,
	b *emulator.Blockchain,
	tokenHolderAddress flow.Address,
	keyIndex int,
	backupSigner crypto.Signer,
) error {
	tx := flow.NewTransaction().
		SetScript([]byte(checkScript)).
		SetGasLimit(100).
		SetPayer(b.ServiceKey().Address).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		AddAuthorizer(tokenHolderAddress)

	err := tx.SignPayload(tokenHolderAddress, keyIndex, backupSigner)
	require.NoError(t, err)

	err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, err)

	err = b.AddTransaction(*tx)
	require.NoError(t, err)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return result.Error
}

func pathForTokenHolder(tokenHolderAddress flow.Address) cadence.Path {
	return cadence.Path{
		Domain:     "storage",
		Identifier: tokenHolderAddress.Hex(),
	}
}
