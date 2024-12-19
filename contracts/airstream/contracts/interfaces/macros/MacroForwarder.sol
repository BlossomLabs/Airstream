// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IUserDefinedMacro} from "./IUserDefinedMacro.sol";

interface MacroForwarder {
    function runMacro(IUserDefinedMacro m, bytes calldata params) external payable returns (bool);
}
