// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "test/ManagedTokenTestBase.t.sol";

contract ProtocolRevenueTests is ManagedTokenTestBase {
    function testProtocolRevenue() public {
        console.log("Max Protocol Revenue: %s", treasury.MAX_PROTOCOL_REVENUE());
        // Set the ProtocolRevenue fee to 10%.
        treasury.setProtocolRevenueBips(1000);

        _saleAmount(1 ether, 500, 0);

        uint256 ethBefore = address(treasury).balance;
        uint256 tokenBefore = token.balanceOf(protocolAccount);
        console.log("Protocol Eth Balance: %s", ethBefore);
        console.log("Protocol Token Balance: %s", tokenBefore);

        // Because we are going to a liquidation swap, we need slippage.
        // Add 50% as slippage.
        _saleAmount(1 ether, 500, 5000);

        uint256 ethAfter = address(treasury).balance;
        uint256 tokenAfter = token.balanceOf(protocolAccount);
        console.log("Protocol Eth Balance: %s", ethAfter);
        console.log("Protocol Token Balance: %s", tokenAfter);

        assertGt(tokenAfter, tokenBefore);
        assertGt(ethAfter, ethBefore);
    }
}
