// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Mock HyperCore HLP adapter (custom protocol, not ERC4626)
contract StrategyHLP is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable ASSET;
    address public vault;

    uint256 public totalManaged;
    bool public locked;

    constructor(IERC20 _asset, address _vault) {
        ASSET = _asset;
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    // -----------------------
    // HyperCore-like actions
    // -----------------------

    /// @notice Simulate deposit to HyperCore HLP (Action ID 2)
    function deposit(uint256 amount) external override onlyVault {
        ASSET.safeTransferFrom(msg.sender, address(this), amount);
        totalManaged += amount;
    }

    /// @notice Withdraw from HLP
    function withdraw(uint256 amount, address to) external override onlyVault returns (uint256) {
        require(!locked, "HLP locked");

        uint256 bal = ASSET.balanceOf(address(this));
        uint256 toSend = amount > bal ? bal : amount;

        ASSET.safeTransfer(to, toSend);
        totalManaged -= toSend;

        return toSend;
    }

    function totalAssets() external view override returns (uint256) {
        return totalManaged;
    }

    function hasLockup() external view override returns (bool) {
        return locked;
    }

    // -----------------------
    // HyperCore simulation
    // -----------------------

    function lock() external {
        locked = true;
    }

    function unlock() external {
        locked = false;
    }

    /// @notice Simulate yield from HyperCore
    function simulateProfit(uint256 amount) external {
        ASSET.safeTransferFrom(msg.sender, address(this), amount);
        totalManaged += amount;
    }
}
