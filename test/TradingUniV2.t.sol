// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "test/ManagedTokenTestBase.t.sol";

contract TradingUniV2Tests is ManagedTokenTestBase {
    function testPurchaseSmallAmount() public {
        _purchaseAmount(0.1 ether, 500);
    }

    function testPurchaseOverSwapAmount() public {
        _purchaseAmount(1 ether, 500);
    }

    function testPurchase(uint256 amountEth, uint16 taxBips) public {
        vm.assume(taxBips <= 500);
        vm.assume(amountEth > 0.00001 ether);
        vm.assume(amountEth < 100 ether);

        _purchaseAmount(amountEth, taxBips);
    }

    function testSaleSmallAmount() public {
        _saleAmount(1000, 500, 0);
    }

    function testSaleOverSwapAmount() public {
        _saleAmount(1 ether, 500, 0);
    }

    function testSale(uint256 amountTokens, uint16 taxBips) public {
        vm.assume(taxBips <= 500);
        vm.assume(amountTokens > 0);
        vm.assume(amountTokens < 100_000_000_000_000_000);

        _saleAmount(amountTokens, taxBips, 0);
    }

    function testConsecutiveSales(uint256 amountTokens, uint16 taxBips) public {
        vm.assume(taxBips <= 500);
        vm.assume(amountTokens > 0);
        vm.assume(amountTokens < 100_000_000_000_000_000);

        _saleAmount(amountTokens, taxBips, 0);
        // 50% slippage for testing.
        _saleAmount(amountTokens, taxBips, 5000);
    }

    function testSaleOverSwapAmountAboveMinTokensSwaps() public {
        _saleAmount(1 ether, 500, 0);

        uint256 ethBefore = address(treasury).balance;
        console.log("Treasury Eth Balance: %s", ethBefore);

        // Because we are going to a liquidation swap, we need slippage.
        // Add 50% as slippage.
        _saleAmount(1 ether, 500, 5000);

        uint256 ethAfter = address(treasury).balance;
        console.log("New Treasury Eth Balance: %s", ethAfter);

        // Swaps should set tokens accrued not be to zero (because we do a swap, then take this swaps tax).
        assertGt(treasury.getTokensAccruedForSwap(), 0);
        // ETH on the Treasury should have increased.
        assertGt(ethAfter, ethBefore);
    }

    function testTaxReceivedUnderMinAddsToBalance() public {
        _purchaseAmount(0.1 ether, 500);
        assertEq(token.balanceOf(address(treasury)), 493);
    }

    function testTaxReceivedUnderMinAcurrues() public {
        _purchaseAmount(0.1 ether, 500);
        assertEq(treasury.getTokensAccruedForSwap(), 493);
    }

    function testTaxReceivedOverMinSwapsOnSale() public {
        uint256 ethBefore = address(treasury).balance;
        uint256 ethBeforeFee = address(treasuryFeeAccount).balance;
        console.log("Treasury Eth Balance: %s", ethBefore);
        console.log("Treasury Fee Eth Balance: %s", ethBeforeFee);

        _saleAmount(50000, 500, 50);
        _saleAmount(50000, 500, 50);

        uint256 ethAfter = address(treasury).balance;
        uint256 ethAfterFee = address(treasuryFeeAccount).balance;
        console.log("New Treasury Eth Balance: %s", ethAfter);
        console.log("New Treasury Fee Balance: %s", ethAfterFee);

        // ETH on the Treasury should have increased.
        assertGt(ethAfter, ethBefore);
        assertGt(ethAfterFee, ethBeforeFee);
    }
}
