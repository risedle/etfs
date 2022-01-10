# Risedle ETFs

![This is us anon!](./meme.png)

This repository contains smart contract for decentralized leveraged ETFs.

The frontend is available [here](https://github.com/risedle/frontend).

- Website: [demo.risedle.com](https://demo.risedle.com)
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

here is the example output:

      Running 4 tests for src/test/Hevm.t.sol:HevmTest
      [PASS] test_setUNIBalance() (gas: 18463)
      [PASS] test_setUSDTBalance() (gas: 15882)
      [PASS] test_setWETHBalance() (gas: 15744)
      [PASS] test_setUSDCBalance() (gas: 15722)

      Running 8 tests for src/test/RiseTokenVaultAccessControl.t.sol:RiseTokenVaultAccessControlTest
      [PASS] test_OwnerCanCreateNewETHRISEToken() (gas: 5324876)
      [PASS] test_OwnerCanCreateNewERC20RISEToken() (gas: 5330534)
      [PASS] testFail_NonOwnerCannotCreateNewETHRISEToken() (gas: 5061524)
      [PASS] testFail_NonRiseTokenVaultCannotBurnRiseToken() (gas: 5056513)
      [PASS] testFail_NonRiseTokenVaultCannotMintRISEToken() (gas: 5056413)
      [PASS] test_OwnerCanSetMaxTotalCollateral() (gas: 5344065)
      [PASS] testFail_NonOwnerCannotSetMaxTotalCollateral() (gas: 5321711)
      [PASS] testFail_NonOwnerCannotCreateNewERC20RISEToken() (gas: 5066602)

      Running 25 tests for src/test/RiseTokenVaultExternal.t.sol:RiseTokenVaultExternalTest
      [PASS] test_SubsequentMintETHRISE() (gas: 8812064)
      [PASS] testFail_ETHRISELeverageUpFailedWhenHighSlippage() (gas: 6715965)
      [PASS] testFail_UserCannotMintETHRISEWhenHighSlippage() (gas: 6715920)
      [PASS] test_MintAndRedeemWithPriceGoDown() (gas: 6942309)
      [PASS] test_ERC20RISELeverageDown() (gas: 6981796)
      [PASS] test_ERC20RISELeverageUp() (gas: 6998199)
      [PASS] testFail_UserCannotMintERC20RISEWithETH() (gas: 6563375)
      [PASS] testFail_MaxTotalCollateralCap() (gas: 7045629)
      [PASS] test_ETHRISELeverageDown() (gas: 6947282)
      [PASS] test_SubsequentMintERC20RISE() (gas: 8925655)
      [PASS] testFail_ERC20RISELeverageUpFailedWhenHighSlippage() (gas: 6740309)
      [PASS] testFail_ETHRISERebalanceInRangeShouldBeReverted() (gas: 6868527)
      [PASS] test_FeeCollections() (gas: 6940710)
      [PASS] test_MintAndRedeemWithNoPriceChange() (gas: 6941692)
      [PASS] testFail_ERC20RISELeverageDownFailedWhenHighSlippage() (gas: 6721831)
      [PASS] testFail_UserCannotMintERC20RISEWhenHighSlippage() (gas: 6740265)
      [PASS] test_MintRISETokenBelowNAVPrice() (gas: 13702739)
      [PASS] test_MintRISETokenEqualNAVPrice() (gas: 13702796)
      [PASS] testFail_UserCannotMintETHRISEWithZeroETH() (gas: 6551701)
      [PASS] testFail_UserCannotMintERC20RISEWhenNotEnoughSupply() (gas: 6671869)
      [PASS] test_ETHRISELeverageUp() (gas: 6964953)
      [PASS] testFail_ETHRISELeverageDownFailedWhenHighSlippage() (gas: 6697506)
      [PASS] testFail_UserCannotMintETHRISEWhenNotEnoughSupply() (gas: 6648717)
      [PASS] test_MintAndRedeemWithPriceGoUp() (gas: 6942362)
      [PASS] testFail_ERC20RISERebalanceInRangeShouldBeReverted() (gas: 6868526)

      Running 6 tests for src/test/RiseTokenVaultInternal.t.sol:RiseTokenVaultInternalTest
      [PASS] testFail_CalculateCollateralPerRiseTokenFeeTooLarge() (gas: 756)
      [PASS] test_CalculateNAV() (gas: 1237)
      [PASS] test_CalculateDebtPerRiseToken() (gas: 101364)
      [PASS] test_GetMintAmount() (gas: 2802)
      [PASS] test_CalculateCollateralPerRiseToken() (gas: 1867)
      [PASS] test_GetCollateralAndFeeAmount() (gas: 1086)

      Running 6 tests for src/test/RisedleVaultAccessControl.t.sol:RisedleVaultAccessControlTest
      [PASS] testFail_NonOwnerCannotSetVaultParameters() (gas: 1818538)
      [PASS] testFail_NonOwnerCannotSetMaxTotalDeposit() (gas: 1818485)
      [PASS] testFail_NonOwnerCannotSetFeeRecipient() (gas: 1819931)
      [PASS] test_OwnerCanSetVaultParameters() (gas: 1818980)
      [PASS] test_OwnerCanSetMaxTotalDeposit() (gas: 1834896)
      [PASS] test_OwnerCanSetFeeRecipient() (gas: 1818135)

      Running 4 tests for src/test/RisedleVaultExternal.t.sol:RisedleVaultExternalTest
      [PASS] test_AnyoneCanRemoveSupplyFromTheVault() (gas: 2449176)
      [PASS] test_VaultTokenPublicProperties() (gas: 1827553)
      [PASS] test_AnyoneCanAddSupplyToTheVault() (gas: 2376578)
      [PASS] testFail_CannotAddSupplyWhenCapIsReached() (gas: 2413334)

      Running 12 tests for src/test/RisedleVaultInternal.t.sol:RisedleVaultInternalTest
      [PASS] test_CalculateBorrowRatePerSecondInEther() (gas: 7235)
      [PASS] test_GetDebtProportionRateInEther() (gas: 45420)
      [PASS] test_GetTotalAvailableCash() (gas: 45783)
      [PASS] test_RisedleVaultProperties() (gas: 25368)
      [PASS] test_SetVaultStates() (gas: 65353)
      [PASS] test_GetUtilizationRateInEther() (gas: 75626)
      [PASS] test_GetSupplyRatePerSecondInEther() (gas: 60168)
      [PASS] test_GetBorrowRatePerSecondInEther() (gas: 45506)
      [PASS] test_CalculateUtilizationRateInEther() (gas: 1954)
      [PASS] test_GetExchangeRateInEther() (gas: 157472)
      [PASS] test_AccrueInterest() (gas: 90615)
      [PASS] test_GetInterestAmount() (gas: 1740)

      Running 2 tests for src/test/WETH9.t.sol:WETH9Test
      [PASS] test_MintAddDeploy() (gas: 571724)
      [PASS] test_DepositAndWithdraw() (gas: 750644)

      Running 2 tests for src/test/oracles/ChainlinkOracle.t.sol:ChainlinkOracleTest
      [PASS] test_ChainlinkBTCUSDT() (gas: 326301)
      [PASS] test_ChainlinkETHUSDC() (gas: 326323)

      Running 1 tests for src/test/swaps/UnsiwapV3Swap.t.sol:UniswapV3SwapTest
      [PASS] test_SwapUSDCToWETH() (gas: 1001649)

      Running 4 tests for src/test/tokens/RisedleERC20AccessControl.t.sol:RisedleERC20AccessControl
      [PASS] testFail_NonOwnerCannotBurnToken() (gas: 855289)
      [PASS] test_OwnerCanMintToken() (gas: 851163)
      [PASS] test_OwnerCanBurnToken() (gas: 854697)
      [PASS] testFail_NonOwnerCannotMintToken() (gas: 803838)

## Gas Report

Run the following command to get deployment gas report:

      export ETH_RPC_URL=<rpc url here>
      make gas

Here is the example output:

      ./scripts/empty-gas-with-build-optimization.sh
      Empty contract with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 67066
      ./scripts/risedle-gas-with-build-optimization.sh
      Risedle with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 3617147
      ./scripts/risedle-gas-without-build-optimization.sh
      Risedle with DAPP_BUILD_OPTIMIZE=0
      Deployment gas usage: 5138125

### VSCode

Install the following VSCode extension:

1. [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
   for code formatter.
2. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.
