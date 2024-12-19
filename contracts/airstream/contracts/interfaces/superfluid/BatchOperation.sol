// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.22;

/**
 * @title Batch operation library
 * @author Superfluid
 */
library BatchOperation {
    /**
     * @dev ERC20.approve batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationApprove(
     *     abi.decode(data, (address spender, uint256 amount))
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_APPROVE = 1;
    /**
     * @dev ERC20.transferFrom batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationTransferFrom(
     *     abi.decode(data, (address sender, address recipient, uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_TRANSFER_FROM = 2;
    /**
     * @dev ERC777.send batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationSend(
     *     abi.decode(data, (address recipient, uint256 amount, bytes userData)
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC777_SEND = 3;
    /**
     * @dev ERC20.increaseAllowance batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationIncreaseAllowance(
     *     abi.decode(data, (address account, address spender, uint256 addedValue))
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_INCREASE_ALLOWANCE = 4;
    /**
     * @dev ERC20.decreaseAllowance batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationDecreaseAllowance(
     *     abi.decode(data, (address account, address spender, uint256 subtractedValue))
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_DECREASE_ALLOWANCE = 5;
    /**
     * @dev SuperToken.upgrade batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationUpgrade(
     *     abi.decode(data, (uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_UPGRADE = 1 + 100;
    /**
     * @dev SuperToken.downgrade batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationDowngrade(
     *     abi.decode(data, (uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_DOWNGRADE = 2 + 100;
    /**
     * @dev SuperToken.upgradeTo batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationUpgradeTo(
     *     abi.decode(data, (address to, uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_UPGRADE_TO = 3 + 100;
    /**
     * @dev SuperToken.downgradeTo batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationDowngradeTo(
     *     abi.decode(data, (address to, uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_DOWNGRADE_TO = 4 + 100;
    /**
     * @dev Superfluid.callAgreement batch operation type
     *
     * Call spec:
     * callAgreement(
     *     ISuperAgreement(target)),
     *     abi.decode(data, (bytes callData, bytes userData)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERFLUID_CALL_AGREEMENT = 1 + 200;
    /**
     * @dev Superfluid.callAppAction batch operation type
     *
     * Call spec:
     * callAppAction(
     *     ISuperApp(target)),
     *     data
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERFLUID_CALL_APP_ACTION = 2 + 200;
    /**
     * @dev SimpleForwarder.forwardCall batch operation type
     *
     * Call spec:
     * forwardCall(
     *     target,
     *     data
     * )
     * NOTE: This operation allows to make arbitrary calls to arbitrary targets.
     * The calls are routed through a dedicated utility contract `SimpleForwarder`.
     * This is important because the host contract has privileged access to other framework contracts,
     * SuperTokens, SuperApps etc.
     * Allowing arbitrary calls to arbitrary targets with the host as sender would thus be unsafe.
     */
    uint32 constant internal OPERATION_TYPE_SIMPLE_FORWARD_CALL = 1 + 300;
    /**
     * @dev ERC2771Forwarder.forward2771Call batch operation type
     *
     * Call spec:
     * forward2771Call(
     *     target,
     *     msgSender,
     *     data
     * )
     *
     * NOTE: In the context of this operation, the `ERC2771Forwarder` contract acts as the
     * _trusted forwarder_ which must be trusted by the _recipient contract_ (operation target).
     * It shall do so by dynamically looking up the ERC2771Forwarder used by the host, like this:
     *
     * function isTrustedForwarder(address forwarder) public view returns(bool) {
     *     return forwarder == address(host.getERC2771Forwarder());
     * }
     *
     * If used in the context of a `forwardBatchCall`, we effectively have a chaining/nesting
     * of ERC-2771 calls where the host acts as _recipient contract_ of the enveloping 2771 call
     * and the ERC2771Forwarder acts as the _trusted forwarder_ of the nested 2771 call(s).
     * That's why `msgSender` could be either the actual `msg.sender` (if using `batchCall`)
     * or the relayed sender address (if using `forwardBatchCall`).
     */
    uint32 constant internal OPERATION_TYPE_ERC2771_FORWARD_CALL = 2 + 300;
}
