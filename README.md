# Risedle ETFs

![This is us anon!](./meme.png)

This repository contains smart contract for decentralized leveraged ETFs.

- Website: [risedle.com](https://risedle.com)
- Docs: [docs.risedle.com](https://docs.risedle.com)
- Twitter: [@risedle](https://twitter.com/risedle)
- Whitepaper: [ETHRISE Whitepaper](https://observablehq.com/@pyk/ethrise)

## Install

Requires [dapp.tools](https://github.com/dapphub/dapptools#installation).

1. Clone Risedle
   ```
   git clone git@github.com:risedle/etfs.git
   cd etfs/
   ```
2. Download all the dependencies
   ```
   dapp update
   ```
3. Configure and run the test

## Configure

Copy `.dapprc.example` to `.dapprc` and edit the `ETH_RPC_URL`.

## Run the test

Run the following command to run the test against Ethereum mainnet:

      CHAIN=ethereum make test

Use this command to run the test against Arbitrum One mainnet:

      CHAIN=arbitrum make test

### VSCode

Install the following VSCode extension:

1. [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
   for code formatter.
2. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.
