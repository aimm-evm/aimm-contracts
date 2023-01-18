// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "src/contracts/ManagedTokenTreasuryFactory.sol";
import "test/harnesses/ManagedTokenTreasuryHarness.sol";

contract ManagedTokenTreasuryFactoryHarness is ManagedTokenTreasuryFactory {
    constructor(address feeAddress) ManagedTokenTreasuryFactory(feeAddress) {}
}
