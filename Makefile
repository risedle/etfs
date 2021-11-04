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
	./scripts/empty-gas-with-build-optimization.sh
	./scripts/risedle-gas-with-build-optimization.sh
	./scripts/risedle-gas-without-build-optimization.sh

gas-report:
	dapp test --rpc -v -m GasReport
