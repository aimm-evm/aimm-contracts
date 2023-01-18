// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import "src/contracts/ManagedToken.sol";
import "test/harnesses/ManagedTokenHarness.sol";
import "src/contracts/ManagedTokenTaxProvider.sol";
import "src/contracts/ManagedTokenTreasuryFactory.sol";
import "src/contracts/ManagedTokenTreasury.sol";
import "src/contracts/ManagedTokenFactory.sol";

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";
import "uniswap/core/interfaces/IUniswapV2Pair.sol";

contract DeployFactoriesScript is Script {
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Factory uniswapFactory;
    address treasuryFeeAccount;
    string mnemonic;

    function setUp() public {
        string memory configDir = string.concat("config\\", vm.toString(getChainID()));
        string memory addressesJson = vm.readFile(string.concat(configDir, "\\Addresses.json"));
        uniswapRouter = IUniswapV2Router02(stdJson.readAddress(addressesJson, "UniswapRouter"));
        uniswapFactory = IUniswapV2Factory(stdJson.readAddress(addressesJson, "UniswapFactory"));
        mnemonic = vm.readFile(string.concat(configDir, "\\Seed.txt"));

        uint256 treasuryFeeAccountPrivateKey = vm.deriveKey(mnemonic, 1);
        treasuryFeeAccount = vm.addr(treasuryFeeAccountPrivateKey);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);

        vm.startBroadcast(deployerPrivateKey);

        ManagedTokenTreasury treasuryImpl = new ManagedTokenTreasury();
        treasuryImpl.init(
            IManagedTokenTreasuryFactory(address(0)), ERC20Burnable(address(0)), IUniswapV2Router02(address(0))
        );

        ManagedTokenTreasuryFactory treasuryFactory = new ManagedTokenTreasuryFactory(treasuryFeeAccount);
        treasuryFactory.setTreasuryImplementation(treasuryImpl);
        new ManagedTokenFactory(treasuryFactory);

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
