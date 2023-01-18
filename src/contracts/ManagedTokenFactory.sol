// SPDX-License-Identifier: MIT

/*
  A Managed Token, part of the AI Managed Token Suite - AIMM.

  AIMM is a DeFi market maker with community engagement tooling built in, anyone can create a ManagedToken using our factories
  permissionlessly onchain, and benefit from our on and offchain tooling to provide intelligent tax settings, buyback and liquidity
  functions. By deriving your project's ERC20 token from a ManagedToken, users can be sure by checking the verified Solidity code of:
   - Tax is hard coded as max 5/5.
   - Visibility of Maximum Tx Amount is surfaced
   - Check whether Maximum Tx Amount is frozen.
   - Check whether Tax is frozen.

  Using our ManagedTokenTreasury, users can be sure that the portion of Tax's raised to be part of the protocol cannot be rugged by
  project owners, as there are no functions to withdraw either ETH or ERC20 from the Treasury. Protocols have to enter, before Tax is taken
  on a sale, the portion they are taking for their project. This is hard coded to be capped at 50%.

  AIMM takes a revenue share of 1% of the Tax collected by the treasury, for future development of the protocol and maintence costs.

  Website: https://aimm.tech/
  Twitter: https://twitter.com/AIMMtech
  Telegram: https://t.me/AIMMtech
  GitHub: https://github.com/aimm-evm/
*/

pragma solidity >=0.8.16;

import "openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin/proxy/Clones.sol";
import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";

import "src/contracts/ManagedToken.sol";
import "src/contracts/ManagedTokenTaxProvider.sol";

import "src/interfaces/IManagedTokenTreasury.sol";
import "src/interfaces/IManagedTokenTreasuryFactory.sol";
import "src/interfaces/IManagedTokenFactory.sol";

contract ManagedTokenFactory is IManagedTokenFactory {
    event ManagedTokenSuiteCreated(
        address indexed token, address indexed taxProvider, address indexed treasury, address executor
    );

    IManagedTokenTreasuryFactory public treasuryFactory;

    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    constructor(IManagedTokenTreasuryFactory treasuryFactory_) {
        treasuryFactory = treasuryFactory_;
    }

    function createManagedTokenSuite(CreateSuiteParams calldata params)
        public
        payable
        returns (ManagedToken managedToken, IManagedTokenTreasury treasury, IManagedTokenTaxProvider taxProvider)
    {
        managedToken = _newManagedToken(params.token, params.owner);
        treasury = _newTreasury(managedToken, params);
        address pair = IUniswapV2Factory(params.treasury.uniswapRouter.factory()).createPair(
            address(managedToken), params.treasury.uniswapRouter.WETH()
        );
        taxProvider = _newTaxProvider(params, treasury, pair);

        managedToken.setTreasury(treasury);
        managedToken.setTaxProvider(taxProvider);

        emit ManagedTokenSuiteCreated(
            address(managedToken), address(taxProvider), address(treasury), params.treasury.executor
            );
    }

    function _newManagedToken(TokenParams memory tokenParams, address owner)
        internal
        virtual
        returns (ManagedToken managedToken)
    {
        return new ManagedToken(tokenParams.name, tokenParams.symbol, tokenParams.totalSupply, owner);
    }

    function _newTreasury(ManagedToken managedToken, CreateSuiteParams memory params)
        internal
        virtual
        returns (IManagedTokenTreasury treasury)
    {
        treasury = treasuryFactory.createTreasury{value: msg.value}(
            managedToken, params.treasury.uniswapRouter, params.treasury.executor
        );
        treasury.grantRole(treasury.PROTOCOL_OWNER_ROLE(), address(this));
        treasury.grantRole(treasury.AI_EXECUTOR_ROLE(), address(this));
        treasury.setMinTokensToSwap(params.treasury.minimumTokensToSwap);
        if (params.treasury.protocolRevenueAddress != address(0)) {
            treasury.setProtocolRevenueAddress(params.treasury.protocolRevenueAddress);
            treasury.setProtocolRevenueBips(params.treasury.protocolRevenueBips);
        }
        treasury.grantRole(DEFAULT_ADMIN_ROLE, params.owner);
        treasury.grantRole(treasury.PROTOCOL_OWNER_ROLE(), params.owner);

        treasury.revokeRole(treasury.PROTOCOL_OWNER_ROLE(), address(this));
        treasury.revokeRole(treasury.AI_EXECUTOR_ROLE(), address(this));
        treasury.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    function _newTaxProvider(CreateSuiteParams memory params, IManagedTokenTreasury treasury, address pair)
        internal
        virtual
        returns (IManagedTokenTaxProvider taxProvider)
    {
        taxProvider = new ManagedTokenTaxProvider();
        taxProvider.grantRole(taxProvider.MANAGE_TAX_ROLE(), address(this));
        taxProvider.grantRole(taxProvider.MANAGE_EXEMPTIONS_ROLE(), address(this));
        taxProvider.setTax(params.tax.buyTax, params.tax.sellTax);
        taxProvider.addExemptions(address(treasury));
        taxProvider.addExemptions(params.owner);
        taxProvider.addDex(pair);

        taxProvider.grantRole(DEFAULT_ADMIN_ROLE, params.owner);
        taxProvider.grantRole(taxProvider.MANAGE_TAX_ROLE(), params.owner);
        taxProvider.grantRole(taxProvider.MANAGE_EXEMPTIONS_ROLE(), params.owner);
        taxProvider.grantRole(taxProvider.MANAGE_TAX_ROLE(), params.treasury.executor);

        taxProvider.revokeRole(taxProvider.MANAGE_TAX_ROLE(), address(this));
        taxProvider.revokeRole(taxProvider.MANAGE_EXEMPTIONS_ROLE(), address(this));
        taxProvider.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }
}
