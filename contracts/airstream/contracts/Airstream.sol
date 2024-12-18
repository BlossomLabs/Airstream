// SPDX-License-Identifier: AGPLv3
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GDAv1Forwarder, PoolConfig} from "./interfaces/GDAv1Forwarder.sol";
import {ISuperfluidPool} from "./interfaces/ISuperfluidPool.sol";
import {Claimable} from "./abstract/Claimable.sol";
import {Withdrawable} from "./abstract/Withdrawable.sol";
import {AirstreamLib, AirstreamConfig, AirstreamExtendedConfig, ClaimingWindow} from "./libraries/AirstreamLib.sol";
import {RedirectLib} from "./libraries/RedirectLib.sol";

contract Airstream is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, Claimable, Withdrawable, ReentrancyGuardUpgradeable {
    using AirstreamLib for uint256;
    using RedirectLib for ISuperfluidPool;

    error PoolCreationFailed();
    error InvalidDurationOrAmount();
    error NoUnclaimedTokens();
    error NotAirstreamExtended();
    event AirstreamCreated(string name, address pool);

    address public immutable gdav1Forwarder;
    /* Airstream name */
    string public name;
    /* Superfluid pool the airstream is attached to */
    ISuperfluidPool public pool;
    /* Merkle root of the airstream */
    bytes32 private merkleRoot_;
    /* Unclaimed amount */
    uint256 public unclaimedAmount;
    /* Flow rate */
    int96 public flowRate;
    /* Started at */
    uint64 public startedAt;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _gdav1Forwarder) {
        gdav1Forwarder = _gdav1Forwarder;
        _disableInitializers();
    }

    /**
     * @notice Initialize the airstream
     * @param _controller Address of the controller
     * @param _config Airstream configuration
     */
    function initialize(address _controller, AirstreamConfig memory _config, AirstreamExtendedConfig memory _extendedConfig) initializer public virtual {
        if (
            _extendedConfig.initialRewardPPM > 0 ||
            _extendedConfig.feePPM > 0 ||
            _extendedConfig.claimingWindow.startDate > 0 ||
            _extendedConfig.claimingWindow.duration > 0 ||
            _extendedConfig.claimingWindow.treasury != address(0)
        ) {
            revert NotAirstreamExtended();
        }
        __Airstream_init(_controller, _config);
    }

    /**
     * @notice Pause the airstream
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the airstream
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Claim the rewards for the given account
     * @param account Address of the account to claim for
     * @param amount Amount of the rewards to claim
     * @param proof Merkle proof for the claim
     */
    function claim(address account, uint256 amount, bytes32[] calldata proof) external virtual whenNotPaused nonReentrant {
        if (unclaimedAmount == 0) {
            revert NoUnclaimedTokens();
        }
        _claimAirstream(account, amount, proof);
    }

    /**
     * @notice Redirect the rewards to the given addresses
     * @param from Addresses to redirect from
     * @param to Addresses to redirect to
     * @param amounts Amounts to redirect
     */
    function redirectRewards(address[] memory from, address[] memory to, uint256[] memory amounts) external onlyOwner {
        pool.redirectUnits(from, to, amounts);
    }

    /**
     * @notice Withdraw the token from the airstream contract
     * @dev The airstream contract must be paused
     * @param token Address of the token to withdraw
     */
    function withdraw(address token) external onlyOwner whenPaused {
        _withdraw(token);
    }

    /**
     * @notice Get the merkle root
     * @return The merkle root
     */
    function merkleRoot() public view override returns (bytes32) {
        return merkleRoot_;
    }

    /**
     * @notice Get the distribution token
     * @return The distribution token
     */
    function distributionToken() public view returns (address) {
        return pool.superToken();
    }

    /**
     * @notice Get the allocation for the given account
     * @param account Address of the account
     * @return The allocation
     */
    function getAllocation(address account) public view returns (uint256) {
        return AirstreamLib.fromPoolUnits(pool.getUnits(account));
    }

    function __Airstream_init(address _controller, AirstreamConfig memory _config) internal onlyInitializing {
        __Pausable_init();
        __Ownable_init(_controller);
        __UUPSUpgradeable_init();
        if (_config.totalAmount == 0 || _config.duration == 0) {
            revert InvalidDurationOrAmount();
        }
        name = _config.name;
        merkleRoot_ = _config.merkleRoot;
        unclaimedAmount = _config.totalAmount;
        startedAt = uint64(block.timestamp);
        flowRate = int96(_config.totalAmount / _config.duration);
        _createPool(_config.token, gdav1Forwarder);
        emit AirstreamCreated(_config.name, address(pool));
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function _createPool(address _distributionToken, address _gdav1Forwarder) internal onlyInitializing {
        // Create a new pool using the GDAv1Forwarder
        (bool _success, address _pool) = GDAv1Forwarder(_gdav1Forwarder)
            .createPool(
                _distributionToken,
                address(this),
                PoolConfig({
                    transferabilityForUnitsOwner: false,
                    distributionFromAnyAddress: true
                })
            );
        // Revert if pool creation fails
        if (!_success) revert PoolCreationFailed();
        // Set the Airstream's pool
        pool = ISuperfluidPool(_pool);
        pool.updateMemberUnits(address(this), unclaimedAmount.toPoolUnits());
        GDAv1Forwarder(gdav1Forwarder).connectPool(_pool, "");
    }

    function _claimAirstream(address account, uint256 amount, bytes32[] calldata proof) internal {
        // Verify claim and update state
        _claim(account, amount, proof);
        
        // Update pool units for claimer
        pool.updateMemberUnits(account, amount.toPoolUnits());

        IERC20 token = IERC20(pool.superToken());

        uint256 unclaimedBalance = token.balanceOf(address(this)) * amount / unclaimedAmount;

        if (unclaimedBalance > 0) {
            token.transfer(account, unclaimedBalance);
        }

        // Update contract's pool units and state
        unclaimedAmount -= amount;
        pool.updateMemberUnits(address(this), unclaimedAmount.toPoolUnits());
    }
}
