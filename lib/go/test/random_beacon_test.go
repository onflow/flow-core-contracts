package test

import (
	"context"
	"testing"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-go-sdk"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
)

func TestRandomBeaconHistory(t *testing.T) {
	_, adapter := newBlockchain()

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the DKG account and deploy
	randomBeaconAccountKey, _ := accountKeys.NewWithSigner()
	randomBeaconCode := contracts.RandomBeaconHistory()

	_, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{randomBeaconAccountKey}, []sdktemplates.Contract{
		{
			Name:   "RandomBeaconHistory",
			Source: string(randomBeaconCode),
		},
	})
	assert.NoError(t, err)
}
