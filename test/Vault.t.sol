// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Vault.sol";
import "../src/MockUSDC.sol";
import "../src/strategies/StrategyA.sol";
import "../src/strategies/StrategyB.sol";

contract VaultTest is Test {
    Vault vault;
    MockUSDC usdc;
    StrategyA stratA;
    StrategyB stratB;

    function setUp() public {
        usdc = new MockUSDC();
        vault = new Vault(usdc);

        stratA = new StrategyA(address(usdc));
        stratB = new StrategyB(address(usdc));

        vault.grantRole(vault.MANAGER_ROLE(), address(this));

        vault.addAllocation(address(stratA), 6000); // 60%
        vault.addAllocation(address(stratB), 4000); // 40%

        usdc.mint(address(this), 1000e6);
        usdc.approve(address(vault), type(uint256).max);

        vault.deposit(1000e6, address(this));
        vault.rebalance();
    }

    function testFullFlow() public {
        // Check initial allocation
        assertEq(stratA.totalAssets(), 600e6);
        assertEq(stratB.totalAssets(), 400e6);

        // ============================
        // Simulate profit on Strategy A (+60)
        // IMPORTANT: mint real USDC!
        // ============================
        usdc.mint(address(stratA), 60e6);
        stratA.simulateProfit(60e6);

        // Vault valuation should update
        assertEq(vault.totalAssets(), 1060e6);

        uint256 shares = vault.balanceOf(address(this));

        // ============================
        // Request withdraw (will be queued because StrategyB is locked)
        // ============================
        uint256 reqId = vault.requestWithdraw(shares);

        // Must NOT be instant
        assertTrue(reqId != type(uint256).max);

        // We cannot claim because underlying is locked,
        // but this proves the withdrawal queue logic works.
    }
}
