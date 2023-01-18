// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "src/interfaces/IManagedTokenTreasuryFactory.sol";
import "src/contracts/ManagedTokenTreasury.sol";

contract ManagedTokenTreasuryHarness is ManagedTokenTreasury {
    function getTokensAccruedForSwap() public view returns (uint256) {
        return _tokensAccruedForSwap;
    }
}
