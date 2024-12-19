// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.22;

import { ISuperfluid, BatchOperation } from "../interfaces/superfluid/ISuperfluid.sol";
import { IUserDefinedMacro } from "../interfaces/macros/IUserDefinedMacro.sol";
import { IGeneralDistributionAgreementV1 } from "../interfaces/gdav1/IGeneralDistributionAgreement.sol";
import { ISuperfluidPool } from "../interfaces/gdav1/ISuperfluidPool.sol";
import { IAirstream } from "../interfaces/IAirstream.sol";

abstract contract Connectable is IUserDefinedMacro, IAirstream {

    /**
     * @dev Returns the pool address
     * @return pool The pool address
     */
    function pool() public view virtual returns (address);

    /**
     * @dev Builds the batch operations for the macro
     * @param host The host contract set for the executing MacroForwarder
     * @param params The encoded parameters as provided to `MacroForwarder.runMacro()`
     * @param msgSender The msg.sender of the call to the MacroForwarder
     * @return operations The batch operations
     */
    function buildBatchOperations(ISuperfluid host, bytes memory params, address msgSender) public virtual view
        returns (ISuperfluid.Operation[] memory operations)
    {
        address gda = host.getAgreementClass(
            keccak256("org.superfluid-finance.agreements.GeneralDistributionAgreement.v1")
        );

        // parse params
        (address account, uint256 amount, bytes32[] memory proof) = abi.decode(params, (address, uint256, bytes32[]));
    
        // encode calls
        bytes memory claimCallData = abi.encodeCall(IAirstream.claim, (account, amount, proof));
        bytes memory connectCallData = abi.encodeCall(IGeneralDistributionAgreementV1.connectPool, (ISuperfluidPool(pool()), new bytes(0)));

        operations = new ISuperfluid.Operation[](2);

        // claim
        operations[0] = ISuperfluid.Operation({
            operationType: BatchOperation.OPERATION_TYPE_SIMPLE_FORWARD_CALL,
            target: address(this),
            data: abi.encode(claimCallData, new bytes(0))
        });

        // connect pool
        operations[1] = ISuperfluid.Operation({
            operationType : BatchOperation.OPERATION_TYPE_SUPERFLUID_CALL_AGREEMENT,
            target: address(gda),
            data: abi.encode(connectCallData, new bytes(0))
        });
    }

    /**
     * @dev Returns the abi encoded params for the macro, to be used with buildBatchOperations
     * @param account The address of the account to claim for
     * @param amount The amount of the rewards to claim
     * @param proof The Merkle proof for the claim
     * @return params The encoded parameters
     */
    function getParams(address account, uint256 amount, bytes32[] calldata proof) external pure returns (bytes memory) {
        return abi.encode(account, amount, proof);
    }

    /**
     * @dev Post-check function to ensure the pool is connected after the macro is executed
     * @param host The host contract set for the executing MacroForwarder
     * @param params The encoded parameters as provided to `MacroForwarder.runMacro()`
     * @param msgSender The msg.sender of the call to the MacroForwarder
     */
    function postCheck(ISuperfluid host, bytes memory params, address msgSender) external view {
        // Do nothing
    }
}
