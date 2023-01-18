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
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/utils/Multicall.sol";

import "src/interfaces/IManagedTokenTaxProvider.sol";

contract ManagedTokenTaxProvider is AccessControl, Multicall, IManagedTokenTaxProvider {
    uint16 public constant TAX_BIPS_MAX = 500;
    uint16 public constant BIPS_DEMONINATOR = 10_000;

    bool public TAX_FROZEN = false;
    bool public MAX_TX_AMOUNT_FROZEN = false;

    bytes32 public constant MANAGE_EXEMPTIONS_ROLE = keccak256("EXEMPTION_MANAGER");
    bytes32 public constant MANAGE_TAX_ROLE = keccak256("TAX_MANAGER");

    mapping(address => bool) private _addressTaxExempt;

    uint16 public taxBuyBips = 0;
    uint16 public taxSellBips = 0;
    mapping(address => bool) private _addressIsDex;
    uint256 public maxTxAmount;
    uint256 public version = 1;

    modifier notTaxFrozen() {
        require(!TAX_FROZEN, "ManagedTokenTaxProvider: Tax has been frozen.");
        _;
    }

    modifier notMaxTxFrozen() {
        require(!MAX_TX_AMOUNT_FROZEN, "ManagedTokenTaxProvider: Max Tx Amount has been frozen.");
        _;
    }

    constructor() {
        _addressTaxExempt[address(this)] = true;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getTax(address from, address to, uint256 amount) public view returns (uint256) {
        require(maxTxAmount == 0 || amount <= maxTxAmount, "ManagedTokenTaxProvider: Max transfer amount exceeded.");

        if (_addressIsDex[to]) {
            if (!_addressTaxExempt[from]) {
                return amount * taxSellBips / BIPS_DEMONINATOR;
            }
        } else if (_addressIsDex[from]) {
            if (!_addressTaxExempt[from]) {
                return amount * taxBuyBips / BIPS_DEMONINATOR;
            }
        }

        return 0;
    }

    function setMaxTxAmount(uint256 amount) public onlyRole(MANAGE_TAX_ROLE) notMaxTxFrozen {
        maxTxAmount = amount;
    }

    function addExemptions(address account) public onlyRole(MANAGE_EXEMPTIONS_ROLE) {
        _addressTaxExempt[account] = true;
    }

    function removeExemptions(address account) public onlyRole(MANAGE_EXEMPTIONS_ROLE) {
        _addressTaxExempt[account] = false;
    }

    function addDex(address account) public onlyRole(MANAGE_EXEMPTIONS_ROLE) {
        _addressIsDex[account] = true;
    }

    function removeDex(address account) public onlyRole(MANAGE_EXEMPTIONS_ROLE) {
        _addressIsDex[account] = false;
    }

    function setTax(uint16 buyBips, uint16 sellBips) public onlyRole(MANAGE_TAX_ROLE) notTaxFrozen {
        require(buyBips <= TAX_BIPS_MAX, "Requested new Buy Tax Bips exceeds maximum");
        require(sellBips <= TAX_BIPS_MAX, "Requested new Sell Tax Bips exceeds maximum");
        taxBuyBips = buyBips;
        taxSellBips = sellBips;
    }

    function freezeTax() public onlyRole(MANAGE_TAX_ROLE) {
        TAX_FROZEN = true;
    }

    function freezeMaxTxAmount() public onlyRole(MANAGE_TAX_ROLE) {
        MAX_TX_AMOUNT_FROZEN = true;
    }
}
