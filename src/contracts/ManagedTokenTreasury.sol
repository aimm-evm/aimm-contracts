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
import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";

import "src/interfaces/IManagedTokenTreasury.sol";
import "src/interfaces/IManagedTokenTreasuryFactory.sol";

contract ManagedTokenTreasury is AccessControl, Multicall, IManagedTokenTreasury {
    IManagedTokenTreasuryFactory public treasuryFactory;
    ERC20Burnable public managedToken;

    bytes32 public constant AI_EXECUTOR_ROLE = keccak256("AI_EXECUTOR");
    bytes32 public constant PROTOCOL_OWNER_ROLE = keccak256("PROTOCOL_OWNER");

    address public protocolRevenueAddress = address(0);

    uint16 public protocolRevenueBips = 0;
    uint16 public constant BIPS_DEMONINATOR = 10_000;
    uint16 public constant MAX_PROTOCOL_REVENUE = 5_000;
    uint16 public version = 1;
    uint256 public minTokensToSwap = 0;

    IUniswapV2Router02 private _uniswapV2Router;
    //slither-disable-next-line naming-convention ; Internal for access in the Testing Harness
    uint256 internal _tokensAccruedForSwap = 0;

    modifier onlyToken() {
        require(address(managedToken) == _msgSender(), "ManagedTokenTreasury: Only callable by Token");
        _;
    }

    constructor() {}

    function init(IManagedTokenTreasuryFactory factory, ERC20Burnable token, IUniswapV2Router02 uniswapV2Router)
        external
    {
        require(address(managedToken) == address(0), "Already initialised.");

        managedToken = token;
        _uniswapV2Router = uniswapV2Router;
        treasuryFactory = factory;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    receive() external payable {
        // Emit 2% of ETH to Factory feeAddress.
        // This works out to paying 1% of the total tax received by the address in TOKEN-ETH pair.
        uint256 platformFee = msg.value * 2 / 100;
        if (platformFee > 0) {
            payable(treasuryFactory.feeAddress()).transfer(platformFee);
        }
    }

    function onTaxSent(uint256 amount, address from) external onlyToken {
        require(
            _msgSender() == address(managedToken),
            "ManagedTokenTreasury: Only the ERC20 token we are managing can invoke"
        );

        // Wait until we have accrued enough tokens to be worth swapping.
        if (_shouldSwap(from)) {
            uint256 tokensToSwap = _tokensAccruedForSwap / 2;
            uint256 tokensRemain = _tokensAccruedForSwap - tokensToSwap;
            _tokensAccruedForSwap = 0;

            uint256 ethReturned = _swapTokensForEth(tokensToSwap, 0);

            _emitProtocolRevenue(tokensRemain, ethReturned);
        }

        _tokensAccruedForSwap += amount;
    }

    function burn(uint256 amount) external onlyRole(AI_EXECUTOR_ROLE) {
        _burn(amount);
    }

    function buyBack(uint256 amountEth) external onlyRole(AI_EXECUTOR_ROLE) returns (uint256 amountToken) {
        return _buyBack(amountEth);
    }

    function buyBackAndBurn(uint256 amountEth) external onlyRole(AI_EXECUTOR_ROLE) {
        uint256 amountToken = _buyBack(amountEth);
        _burn(amountToken);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external onlyRole(AI_EXECUTOR_ROLE) {
        _addLiquidity(tokenAmount, ethAmount);
    }

    function sell(uint256 tokenAmount, uint256 minAmountOut) external onlyRole(AI_EXECUTOR_ROLE) {
        _swapTokensForEth(tokenAmount, minAmountOut);
    }

    function setProtocolRevenueBips(uint16 bips) public onlyRole(PROTOCOL_OWNER_ROLE) {
        require(bips <= MAX_PROTOCOL_REVENUE, "Exceeds maximum revenue share");
        protocolRevenueBips = bips;
    }

    function setProtocolRevenueAddress(address protocolAddress) public onlyRole(PROTOCOL_OWNER_ROLE) {
        require(protocolAddress != address(0), "Cannot set protocol revenue to zero address");
        protocolRevenueAddress = protocolAddress;
    }

    function setMinTokensToSwap(uint256 minTokensToSwap_) public onlyRole(AI_EXECUTOR_ROLE) {
        minTokensToSwap = minTokensToSwap_;
    }

    function _burn(uint256 amount) internal {
        managedToken.burn(amount);
    }

    function _buyBack(uint256 amountEth) internal returns (uint256 amountToken) {
        return _swapEthForTokens(amountEth);
    }

    function _shouldSwap(address sender) internal view returns (bool) {
        if (minTokensToSwap == 0 || _tokensAccruedForSwap < minTokensToSwap) {
            return false;
        }

        address pair =
            IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(managedToken), _uniswapV2Router.WETH());
        if (sender == pair) {
            return false;
        }

        return true;
    }

    function _swapEthForTokens(uint256 ethAmount) private returns (uint256 tokenAmount) {
        address[] memory path = new address[](2);
        path[0] = _uniswapV2Router.WETH();
        path[1] = address(managedToken);

        //slither-disable-next-line arbitrary-send-eth
        (uint256[] memory amounts) =
            _uniswapV2Router.swapExactETHForTokens{value: ethAmount}(0, path, address(this), block.timestamp);

        return amounts[1];
    }

    function _swapTokensForEth(uint256 tokenAmount, uint256 minAmountOut) private returns (uint256 ethAmount) {
        address[] memory path = new address[](2);
        path[0] = address(managedToken);
        path[1] = _uniswapV2Router.WETH();

        uint256 ethBefore = address(this).balance;

        //slither-disable-next-line unused-return
        managedToken.approve(address(_uniswapV2Router), tokenAmount);
        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, minAmountOut, path, address(this), block.timestamp
        );

        uint256 ethAfter = address(this).balance;
        return ethAfter - ethBefore;
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        //slither-disable-next-line unused-return
        managedToken.approve(address(_uniswapV2Router), tokenAmount);

        //slither-disable-next-line arbitrary-send-eth,unused-return
        _uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(managedToken), tokenAmount, 0, 0, address(this), block.timestamp
        );
    }

    function _emitProtocolRevenue(uint256 amountToken, uint256 amountEth) internal {
        if (protocolRevenueBips > 0 && protocolRevenueAddress != address(0)) {
            uint256 protocolTokens = amountToken * protocolRevenueBips / BIPS_DEMONINATOR;
            if (protocolTokens > 0) {
                managedToken.transfer(protocolRevenueAddress, protocolTokens);
            }
            uint256 protocolEth = amountEth * protocolRevenueBips / BIPS_DEMONINATOR;
            if (protocolEth > 0) {
                //slither-disable-next-line arbitrary-send-eth,unused-return
                payable(protocolRevenueAddress).transfer(protocolEth);
            }
        }
    }
}
