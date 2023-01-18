// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";

import "src/contracts/ManagedToken.sol";

interface IManagedTokenFactory {
    struct CreateSuiteParams {
        TokenParams token;
        TreasuryParams treasury;
        TaxParams tax;
        address owner;
    }

    struct TokenParams {
        string name;
        string symbol;
        uint256 totalSupply;
    }

    struct TreasuryParams {
        IUniswapV2Router02 uniswapRouter;
        address executor;
        uint256 minimumTokensToSwap;
        address protocolRevenueAddress;
        uint16 protocolRevenueBips;
    }

    struct TaxParams {
        uint16 buyTax;
        uint16 sellTax;
    }

    function createManagedTokenSuite(CreateSuiteParams calldata params)
        external
        payable
        returns (ManagedToken managedToken, IManagedTokenTreasury treasury, IManagedTokenTaxProvider taxProvider);
}
