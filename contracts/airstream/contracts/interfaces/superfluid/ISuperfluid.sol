// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { BatchOperation } from "./BatchOperation.sol";

/**
 * @title Host interface
 * @author Superfluid
 * @notice This is the central contract of the system where super agreement, super app
 * and super token features are connected.
 *
 * The Superfluid host contract is also the entry point for the protocol users,
 * where batch call and meta transaction are provided for UX improvements.
 *
 */
interface ISuperfluid {

    /**
    * @notice Get agreement class
    * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
    */
    function getAgreementClass(bytes32 agreementType) external view returns(address agreementClass);

    /**************************************************************************
    * Batch call
    **************************************************************************/
    /**
     * @dev Batch operation data
     */
    struct Operation {
        // Operation type. Defined in BatchOperation (Definitions.sol)
        uint32 operationType;
        // Operation target
        address target;
        // Data specific to the operation
        bytes data;
    }

    /**
     * @dev Batch call function
     * @param operations Array of batch operations
     *
     * NOTE: `batchCall` is `payable, because there's limited support for sending
     * native tokens to batch operation targets.
     * If value is > 0, the whole amount is sent to the first operation matching any of:
     * - OPERATION_TYPE_SUPERFLUID_CALL_APP_ACTION
     * - OPERATION_TYPE_SIMPLE_FORWARD_CALL
     * - OPERATION_TYPE_ERC2771_FORWARD_CALL
     * If the first such operation does not allow receiving native tokens,
     * the transaction will revert.
     * It's currently not possible to send native tokens to multiple operations, or to
     * any but the first operation of one of the above mentioned types.
     * If no such operation is included, the native tokens will be sent back to the sender.
     */
    function batchCall(Operation[] calldata operations) external payable;

    /**
     * @dev Batch call function with EIP-2771 encoded msgSender
     * @param operations Array of batch operations
     *
     * NOTE: This can be called only by contracts recognized as _trusted forwarder_
     * by the host contract (see `Superfluid.isTrustedForwarder`).
     * If native tokens are passed along, the same rules as for `batchCall` apply,
     * with an optional refund going to the encoded msgSender.
     */
    function forwardBatchCall(Operation[] calldata operations) external payable;

    /**
     * @dev returns the address of the forwarder contract used to route batch operations of type
     * OPERATION_TYPE_ERC2771_FORWARD_CALL.
     * Needs to be set as _trusted forwarder_ by the call targets of such operations.
     */
    // solhint-disable func-name-mixedcase
    function getERC2771Forwarder() external view returns(address);

}
