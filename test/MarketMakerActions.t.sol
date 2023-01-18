// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "test/ManagedTokenTestBase.t.sol";

contract MarketMakerActionsTests is ManagedTokenTestBase {
    function testBurn() public {
        token.mint(address(treasury), 100_000);

        uint256 burnAmount = 1000;
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(treasury), address(0), burnAmount);

        uint256 beforeBurn = token.balanceOf(address(treasury));
        vm.prank(executorAccount);
        treasury.burn(burnAmount);
        uint256 afterBurn = token.balanceOf(address(treasury));
        assertEq(afterBurn, beforeBurn - burnAmount);
    }

    function testBuyback() public {
        vm.deal(address(treasury), 1 ether);

        uint256 beforeBuyback = token.balanceOf(address(treasury));
        vm.prank(executorAccount);
        treasury.buyBack(0.01 ether);
        uint256 afterBuyback = token.balanceOf(address(treasury));
        assertGt(afterBuyback, beforeBuyback);

        console.log(
            "Tokens Before: %s, Tokens After: %s, Tokens Bought: %s",
            beforeBuyback,
            afterBuyback,
            afterBuyback - beforeBuyback
        );
    }

    function testBuybackAndBurn() public {
        vm.deal(address(treasury), 1 ether);

        vm.expectEmit(true, true, false, false, address(token));
        emit Transfer(address(treasury), address(0), 1000);

        uint256 beforeBuyback = token.balanceOf(address(treasury));
        vm.prank(executorAccount);
        treasury.buyBackAndBurn(0.01 ether);
        uint256 afterBuyback = token.balanceOf(address(treasury));
        assertEq(afterBuyback, beforeBuyback);

        console.log("Tokens Before: %s, Tokens After: %s", beforeBuyback, afterBuyback);
    }

    function testAddLiquidity() public {
        token.mint(address(treasury), 100_000);
        vm.deal(address(treasury), 1 ether);

        uint256 beforeBuybackToken = token.balanceOf(address(treasury));
        uint256 beforeBuybackEth = address(treasury).balance;
        uint256 beforeLpTokens = pair.balanceOf(address(treasury));

        vm.prank(executorAccount);
        treasury.addLiquidity(1000, 0.01 ether);

        uint256 afterBuybackToken = token.balanceOf(address(treasury));
        uint256 afterBuybackEth = address(treasury).balance;
        uint256 afterLpTokens = pair.balanceOf(address(treasury));

        assertEq(afterBuybackToken, beforeBuybackToken - 1000);
        assertApproxEqAbs(afterBuybackEth, beforeBuybackEth - 0.01 ether, 0.0001 ether);
        assertGt(afterLpTokens, beforeLpTokens);

        console.log("Tokens Before: %s, Tokens After: %s", beforeBuybackToken, afterBuybackToken);
        console.log("Eth Before: %s, Eth After: %s", beforeBuybackEth, afterBuybackEth);
        console.log("LP Before: %s, LP After: %s", beforeLpTokens, afterLpTokens);
    }
}
