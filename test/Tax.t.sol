// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "test/ManagedTokenTestBase.t.sol";

contract TaxTests is ManagedTokenTestBase {
    function testTransferFromExemptAccountPaysNoTax() public {
        (, address to) = _mintAndTransferFromExemptAccount(100_000);
        assertEq(token.balanceOf(to), 100_000);
    }

    function testTransferFromNotExemptAccountNoPaysTax() public {
        (, address to) = _mintAndTransferFromNotExemptAccount(1000);
        assertEq(token.balanceOf(to), 1000);
    }
}
