// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.16;

import {ManagedToken} from "src/contracts/ManagedToken.sol";

contract ManagedTokenHarness is ManagedToken {
    constructor() ManagedToken("Hello", "World", 0, address(0)) {}

    function mint(address account, uint256 amount) public {
        super._mint(account, amount);
    }
}
