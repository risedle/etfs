all:
	dapp build

clean:
	dapp clean

test:
	dapp test --rpc -v

test-only:
	dapp test --rpc -v -m $(filter)

prove:
	dapp test -v -m prove

# Report gas usage
gas:
	./scripts/risedle-vault-gas-with-build-optimization.sh
	./scripts/risedle-vault-gas-without-build-optimization.sh

gas-report:
	dapp test --rpc -v -m GasReport