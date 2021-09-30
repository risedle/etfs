# include .env file and export its env vars
# (-include to ignore error if it does not exist)


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

