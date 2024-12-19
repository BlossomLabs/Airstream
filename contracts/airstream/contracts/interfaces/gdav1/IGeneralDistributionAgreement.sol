// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.22;

import { ISuperfluidPool } from "../gdav1/ISuperfluidPool.sol";

/**
 * @title General Distribution Agreement interface
 * @author Superfluid
 */
interface IGeneralDistributionAgreementV1 {

    /// @notice Connects `msg.sender` to `pool`.
    /// @dev This is used to connect a pool to the GDA.
    /// @param pool The pool address
    /// @param ctx Context bytes (see ISuperfluid.sol for Context struct)
    /// @return newCtx the new context bytes
    function connectPool(ISuperfluidPool pool, bytes calldata ctx) external returns (bytes memory newCtx);
}