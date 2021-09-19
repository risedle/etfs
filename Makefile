# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all    :; dapp build
clean  :; dapp clean
test   :; dapp test --rpc -v
