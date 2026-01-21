// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyB is IStrategy {
    IERC20 public immutable asset;
    uint256 public totalManaged;
    bool public locked = true;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount) external {
        asset.transferFrom(msg.sender, address(this), amount);
        totalManaged += amount;
    }

    function withdraw(uint256 amount, address to) external returns (uint256) {
        require(!locked, "LOCKED");
        if (amount > totalManaged) amount = totalManaged;
        totalManaged -= amount;
        asset.transfer(to, amount);
        return amount;
    }

    function totalAssets() external view returns (uint256) {
        return totalManaged;
    }

    function hasLockup() external pure returns (bool) {
        return true;
    }

    function unlock() external {
        locked = false;
    }
}
