// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

import "src/contracts/ManagedTokenFactory.sol";
import "test/harnesses/ManagedTokenHarness.sol";

contract ManagedTokenFactoryHarness is ManagedTokenFactory {
    constructor(IManagedTokenTreasuryFactory treasuryFactory_) ManagedTokenFactory(treasuryFactory_) {}

    function _newManagedToken(TokenParams memory tokenParams, address owner)
        internal
        override
        returns (ManagedToken managedToken)
    {
        return new ManagedTokenHarness();
    }
}
