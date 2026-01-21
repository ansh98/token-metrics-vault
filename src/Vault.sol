// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IStrategy.sol";

contract Vault is ERC4626, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct Allocation {
        address protocol;
        uint256 targetBps; // out of 10000
    }

    Allocation[] public allocations;

    uint256 public constant MAX_BPS = 10000;
    uint256 public constant MAX_PER_PROTOCOL_BPS = 7000; // allow 60/40

    uint256 public nextRequestId;

    struct WithdrawRequest {
        address user;
        uint256 shares;
        bool claimed;
    }

    mapping(uint256 => WithdrawRequest) public withdrawRequests;

    // ============================
    // 📢 EVENTS (Stretch Feature)
    // ============================
    event Rebalanced(uint256 totalAssetsBefore, uint256 totalAssetsAfter);
    event DepositRouted(address indexed strategy, uint256 amount);
    event WithdrawalRouted(address indexed strategy, uint256 amount);

    constructor(IERC20 _asset)
        ERC20("Token Metrics Vault Share", "TMVS")
        ERC4626(_asset)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    // ------------------ Allocation Management ------------------

    function addAllocation(address protocol, uint256 targetBps) external onlyRole(MANAGER_ROLE) {
        require(targetBps <= MAX_PER_PROTOCOL_BPS, "Cap exceeded");
        allocations.push(Allocation({protocol: protocol, targetBps: targetBps}));
    }

    function rebalance() external onlyRole(MANAGER_ROLE) {
        uint256 beforeTotal = totalAssets();

        uint256 sum;
        for (uint256 i = 0; i < allocations.length; i++) {
            sum += allocations[i].targetBps;
        }
        require(sum == MAX_BPS, "Allocations must be 100%");

        uint256 total = totalAssets();

        for (uint256 i = 0; i < allocations.length; i++) {
            Allocation memory a = allocations[i];
            uint256 targetAmount = (total * a.targetBps) / MAX_BPS;

            IStrategy strat = IStrategy(a.protocol);
            uint256 current = strat.totalAssets();

            if (current < targetAmount) {
                uint256 diff = targetAmount - current;
                IERC20(asset()).approve(a.protocol, diff);
                strat.deposit(diff);
                emit DepositRouted(a.protocol, diff);
            } else if (current > targetAmount) {
                uint256 diff = current - targetAmount;
                strat.withdraw(diff, address(this));
                emit WithdrawalRouted(a.protocol, diff);
            }
        }

        emit Rebalanced(beforeTotal, totalAssets());
    }

    // ------------------ Accounting ------------------

    function totalAssets() public view override returns (uint256) {
        uint256 total = IERC20(asset()).balanceOf(address(this));

        for (uint256 i = 0; i < allocations.length; i++) {
            total += IStrategy(allocations[i].protocol).totalAssets();
        }

        return total;
    }

    // ------------------ Withdraw Queue ------------------

    function requestWithdraw(uint256 shares) external returns (uint256 requestId) {
        _transfer(msg.sender, address(this), shares);

        bool hasLocked;
        for (uint256 i = 0; i < allocations.length; i++) {
            if (IStrategy(allocations[i].protocol).hasLockup()) {
                hasLocked = true;
                break;
            }
        }

        if (!hasLocked) {
            uint256 assets = previewRedeem(shares);
            _burn(address(this), shares);
            _withdrawInstant(assets, msg.sender);
            return type(uint256).max;
        }

        requestId = nextRequestId++;

        withdrawRequests[requestId] = WithdrawRequest({
            user: msg.sender,
            shares: shares,
            claimed: false
        });
    }

    function claimWithdraw(uint256 requestId) external {
        WithdrawRequest storage r = withdrawRequests[requestId];
        require(!r.claimed, "Already claimed");
        require(r.user == msg.sender, "Not yours");

        uint256 assets = previewRedeem(r.shares);
        r.claimed = true;

        _burn(address(this), r.shares);
        _withdrawInstant(assets, msg.sender);
    }

    function _withdrawInstant(uint256 assets, address to) internal {
        uint256 balance = IERC20(asset()).balanceOf(address(this));

        if (balance < assets) {
            uint256 need = assets - balance;

            for (uint256 i = 0; i < allocations.length && need > 0; i++) {
                IStrategy strat = IStrategy(allocations[i].protocol);
                uint256 got = strat.withdraw(need, address(this));
                if (got >= need) break;
                need -= got;
            }
        }

        IERC20(asset()).safeTransfer(to, assets);
    }

    // ------------------ Safety ------------------

    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    // OpenZeppelin v5 hook
    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        require(!paused(), "paused");
        super._update(from, to, amount);
    }
}
