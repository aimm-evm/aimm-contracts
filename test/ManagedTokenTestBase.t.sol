// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "test/harnesses/ManagedTokenHarness.sol";
import "test/harnesses/ManagedTokenTreasuryHarness.sol";
import "test/harnesses/ManagedTokenTreasuryFactoryHarness.sol";
import "test/harnesses/ManagedTokenFactoryHarness.sol";

import "src/contracts/ManagedTokenTaxProvider.sol";
import "uniswap/periphery/interfaces/IUniswapV2Router02.sol";
import "uniswap/core/interfaces/IUniswapV2Factory.sol";
import "uniswap/core/interfaces/IUniswapV2Pair.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

contract ManagedTokenTestBase is Test {
    // Events copied here due to compiler not able to reference Events from Interfaces.
    event Transfer(address indexed from, address indexed to, uint256 value);

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair pair;

    ManagedTokenHarness public token;
    ManagedTokenTreasuryHarness public treasury;
    IManagedTokenTaxProvider public taxProvider;

    address public treasuryFeeAccount = address(0x123456789);
    address public executorAccount = address(0xABABABABA);
    address public protocolAccount = address(0xDEDEDEDED);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        vm.rollFork(16000000);

        ManagedTokenTreasuryHarness treasuryImpl = new ManagedTokenTreasuryHarness();
        treasuryImpl.init(
            IManagedTokenTreasuryFactory(address(0)), ERC20Burnable(address(0)), IUniswapV2Router02(address(0))
        );

        ManagedTokenTreasuryFactoryHarness treasuryFactory = new ManagedTokenTreasuryFactoryHarness(treasuryFeeAccount);
        treasuryFactory.setTreasuryImplementation(treasuryImpl);

        IManagedTokenFactory.CreateSuiteParams memory params;
        params.owner = address(this);
        params.token.name = "Hello";
        params.token.symbol = "World";
        params.token.totalSupply = 1_000_000;

        params.treasury.uniswapRouter = uniswapRouter;
        params.treasury.executor = executorAccount;
        params.treasury.minimumTokensToSwap = 1000;
        params.treasury.protocolRevenueAddress = protocolAccount;
        params.treasury.protocolRevenueBips = 0;

        params.tax.buyTax = 500;
        params.tax.sellTax = 500;

        ManagedToken token_;
        IManagedTokenFactory tokenFactory = new ManagedTokenFactoryHarness(treasuryFactory);
        IManagedTokenTreasury treasury_;
        (token_, treasury_, taxProvider) = tokenFactory.createManagedTokenSuite(params);

        treasury = ManagedTokenTreasuryHarness(payable(address(treasury_)));
        token = ManagedTokenHarness(payable(address(token_)));

        uint256 initialLiq = 1_000_000;
        uint256 initialLiqEth = 10 ether;
        vm.deal(address(this), 10 ether);
        token.mint(address(this), initialLiq);
        token.approve(address(uniswapRouter), initialLiq);
        uniswapRouter.addLiquidityETH{value: initialLiqEth}(
            address(token), initialLiq, initialLiq, initialLiqEth, address(this), block.timestamp
        );
        pair = IUniswapV2Pair(uniswapFactory.getPair(address(token), address(weth)));
    }

    function _mintAndTransferFromExemptAccount(uint256 amount) internal returns (address from, address to) {
        from = address(0x1);
        token.mint(from, amount);
        taxProvider.addExemptions(from);

        to = address(0x2);
        vm.prank(address(from));
        token.transfer(to, amount);
    }

    function _mintAndTransferFromNotExemptAccount(uint256 amount) internal returns (address from, address to) {
        from = address(0x1);
        token.mint(from, amount);

        to = address(0x2);
        vm.prank(address(from));
        token.transfer(to, amount);
    }

    function _purchaseAmount(uint256 ethToBuy, uint16 taxBips) internal {
        console.log("Tax: %s", taxBips);

        vm.prank(executorAccount);
        taxProvider.setTax(taxBips, 0);

        address buyer = address(0x1);
        vm.deal(buyer, ethToBuy);

        uint256 ethBefore = address(buyer).balance;
        uint256 tokensBefore = token.balanceOf(buyer);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(token);

        (uint256 reserve0, uint256 reserve1) = _getReserves(address(pair), address(weth), address(token));
        console.log("Pair %s", address(pair));
        console.log("Reserve0 %s", reserve0);
        console.log("Reserve1 %s", reserve1);
        uint256 quoteZeroTax = uniswapRouter.getAmountOut(ethToBuy, reserve0, reserve1);
        console.log("Spending Eth %s", ethToBuy);
        console.log("Quote Zero Tax: %s", quoteZeroTax);

        uint256 minTokenOut = quoteZeroTax - (quoteZeroTax * taxBips / 10_000);
        console.log("Min Token Out: %s", minTokenOut);

        vm.prank(buyer);
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethToBuy}(
            minTokenOut, path, buyer, block.timestamp
        );

        uint256 ethAfter = address(buyer).balance;
        uint256 tokensAfter = token.balanceOf(buyer);
        console.log("Tokens Received: %s", tokensAfter - tokensBefore);

        assertEq(ethBefore - ethToBuy, ethAfter);
        assertGe(tokensAfter - tokensBefore, minTokenOut);
    }

    function _saleAmount(uint256 tokensToSell, uint16 taxBips, uint256 slippageBips) internal {
        console.log("Tax: %s", taxBips);

        vm.prank(executorAccount);
        taxProvider.setTax(0, taxBips);

        address buyer = address(0x1);
        token.mint(buyer, tokensToSell);

        uint256 ethBefore = address(buyer).balance;
        uint256 tokensBefore = token.balanceOf(buyer);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        (uint256 reserve0, uint256 reserve1) = _getReserves(address(pair), address(token), address(weth));
        console.log("Pair %s", address(pair));
        console.log("Reserve0 %s", reserve0);
        console.log("Reserve1 %s", reserve1);
        uint256 tax = (tokensToSell * taxBips / 10_000);
        uint256 tokensSwapping = tokensToSell - tax;
        console.log("Tokens Selling: %s", tokensToSell);
        console.log("Token Tax: %s", tax);
        console.log("Token Swapping: %s", tokensSwapping);
        uint256 quote = uniswapRouter.getAmountOut(tokensSwapping, reserve0, reserve1);
        uint256 slippageAbs = (quote * slippageBips / 10_000);
        console.log("Min Eth Out: %s", quote);
        quote = quote - slippageAbs;
        console.log("Min Eth Out with Slippage: %s", quote);

        vm.prank(buyer);
        token.approve(address(uniswapRouter), tokensToSell);
        vm.prank(buyer);
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSell, quote, path, buyer, block.timestamp
        );
        console.log("Swap Executed");

        uint256 ethAfter = address(buyer).balance;
        uint256 tokensAfter = token.balanceOf(buyer);
        console.log("Eth Received: %s", ethAfter - ethBefore);

        assertEq(tokensBefore - tokensToSell, tokensAfter);
        assertGe(ethAfter - ethBefore, quote);
    }

    // Taken from UniswapV2Library
    function _getReserves(address pair_, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = _sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair_).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }
}
