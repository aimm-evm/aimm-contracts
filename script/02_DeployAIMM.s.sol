// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "src/contracts/ManagedToken.sol";
import "test/harnesses/ManagedTokenHarness.sol";
import "src/contracts/ManagedTokenTaxProvider.sol";
import "src/contracts/ManagedTokenTreasuryFactory.sol";
import "src/contracts/ManagedTokenTreasury.sol";
import "src/contracts/ManagedTokenFactory.sol";

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";
import "uniswap/core/interfaces/IUniswapV2Pair.sol";

contract DeployAAIMScript is Script {
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Factory uniswapFactory;
    address treasuryFeeAccount;
    address executorAccount;
    address tokenFactoryAddress;
    string mnemonic;

    function setUp() public {
        string memory configDir = string.concat("config\\", vm.toString(getChainID()));
        string memory addressesJson = vm.readFile(string.concat(configDir, "\\Addresses.json"));
        uniswapRouter = IUniswapV2Router02(stdJson.readAddress(addressesJson, "UniswapRouter"));
        uniswapFactory = IUniswapV2Factory(stdJson.readAddress(addressesJson, "UniswapFactory"));
        tokenFactoryAddress = stdJson.readAddress(addressesJson, "TokenFactory");

        mnemonic = vm.readFile(string.concat(configDir, "\\Seed.txt"));

        string memory executorMnemonic = vm.readFile(string.concat(configDir, "\\ExecutorSeed.txt"));
        uint256 executorMnemonicPrivateKey = vm.deriveKey(executorMnemonic, 1);
        executorAccount = vm.addr(executorMnemonicPrivateKey);
    }

    function run() public {
        console.log("Executor: %s", executorAccount);
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 2);
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        IManagedTokenFactory.CreateSuiteParams memory params;
        params.owner = deployer;
        params.token.name = "AI Market Maker";
        params.token.symbol = "AIMM";
        params.token.totalSupply = 500_000_000 * 10 ** 18;

        params.treasury.uniswapRouter = uniswapRouter;
        params.treasury.executor = executorAccount;
        params.treasury.minimumTokensToSwap = 10000;
        params.treasury.protocolRevenueAddress = deployer;
        params.treasury.protocolRevenueBips = 5000;

        params.tax.buyTax = 500;
        params.tax.sellTax = 500;

        ManagedToken token;
        IManagedTokenTreasury treasury;
        IManagedTokenTaxProvider taxProvider;
        ManagedTokenFactory tokenFactory = ManagedTokenFactory(tokenFactoryAddress);
        (token, treasury, taxProvider) = tokenFactory.createManagedTokenSuite(params);

        // Transfer 20% to the Treasury.
        uint256 toTreasury = (params.token.totalSupply / 100) * 20;
        token.transfer(address(treasury), toTreasury);

        //taxProvider.setMaxTxAmount(2500000 * 10 ** 18);

        // Put the rest in LP
        //uint256 tpLP = params.token.totalSupply - toTreasury;
        //uint256 initialLiqEth = 100 ether;
        //token.approve(address(uniswapRouter), tpLP);
        //uniswapRouter.addLiquidityETH{value: initialLiqEth}(
        //    address(token), tpLP, tpLP, initialLiqEth, address(this), block.timestamp + 1000
        //);

        vm.stopBroadcast();
    }

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
