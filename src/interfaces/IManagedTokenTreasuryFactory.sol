// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";

import "src/interfaces/IManagedTokenTreasury.sol";

interface IManagedTokenTreasuryFactory {
    function feeAddress() external view returns (address);

    function createTreasury(ERC20Burnable token, IUniswapV2Router02 uniswapV2Router, address executor)
        external
        payable
        returns (IManagedTokenTreasury treasury_);
}
