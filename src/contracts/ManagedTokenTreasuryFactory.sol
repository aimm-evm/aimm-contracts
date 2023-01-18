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
import "openzeppelin/access/Ownable2Step.sol";
import "openzeppelin/proxy/Clones.sol";
import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";

import "src/contracts/ManagedToken.sol";
import "src/contracts/ManagedTokenTreasury.sol";
import "src/contracts/ManagedTokenTaxProvider.sol";
import "src/interfaces/IManagedTokenTreasuryFactory.sol";

contract ManagedTokenTreasuryFactory is Ownable2Step, IManagedTokenTreasuryFactory {
    event TreasuryCreated(address indexed token, address indexed treasury, address executor);
    event FeeAddressChanged(address feeAddress);

    uint256 public createTreasuryPriceEth = 0;
    uint256 public createTreasuryPriceTokens = 0;
    IERC20 public createTreasuryToken = IERC20(address(0));
    uint256 public version = 1;

    address private _feeAddress;
    address public treasuryImplementation = address(0);

    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    constructor(address feeAddress_) {
        setFeeAddress(feeAddress_);
    }

    function createTreasury(ERC20Burnable token, IUniswapV2Router02 uniswapV2Router, address executor)
        public
        payable
        returns (IManagedTokenTreasury treasury_)
    {
        if (address(createTreasuryToken) != address(0) && createTreasuryPriceTokens > 0) {
            require(
                createTreasuryToken.transferFrom(_msgSender(), _feeAddress, createTreasuryPriceTokens),
                "Could not transfer tokens."
            );
        } else if (createTreasuryPriceEth > 0) {
            require(msg.value >= createTreasuryPriceEth, "Insufficient payment to create Treasury");
            payable(_feeAddress).transfer(address(this).balance);
        }

        return _newTreasury(token, uniswapV2Router, executor, _msgSender());
    }

    function _newTreasury(ERC20Burnable token, IUniswapV2Router02 uniswapV2Router, address executor, address owner)
        internal
        virtual
        returns (IManagedTokenTreasury treasury)
    {
        ManagedTokenTreasury treasury_ = ManagedTokenTreasury(payable(Clones.clone(treasuryImplementation)));
        treasury_.init(this, token, uniswapV2Router);
        treasury_.grantRole(treasury_.AI_EXECUTOR_ROLE(), executor);
        treasury_.grantRole(treasury_.PROTOCOL_OWNER_ROLE(), owner);
        treasury_.grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        emit TreasuryCreated(address(token), address(treasury_), executor);
        return treasury_;
    }

    function setTreasuryImplementation(ManagedTokenTreasury treasury) public {
        require(address(treasury) != address(0), "Must provide implementation");
        treasuryImplementation = address(treasury);
    }

    function feeAddress() external view returns (address) {
        return _feeAddress;
    }

    function setFeeAddress(address newFeeAddress) public onlyOwner {
        require(newFeeAddress != address(0), "Fee address cannot be zero");
        emit FeeAddressChanged(newFeeAddress);
        _feeAddress = newFeeAddress;
    }

    function setCreatePriceEth(uint256 newPriceEth) public onlyOwner {
        createTreasuryPriceEth = newPriceEth;
    }

    function setCreatePriceToken(uint256 newPriceToken, IERC20 token) public onlyOwner {
        createTreasuryPriceTokens = newPriceToken;
        createTreasuryToken = token;
    }
}
