// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libs/KacoMath.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "./SyrupBar.sol";

interface IMigratorChef {
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to Old LP tokens.
    // new LP must mint EXACTLY the same amount of LP tokens or
    // else something bad will happen.
    function migrate(IERC20 token) external returns (IERC20);
}

// MasterChef is the master of Kaco. He can make Kaco and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Kaco is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using KacoMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Kacos
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accKacPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accKacPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Kacos to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Kacos distribution occurs.
        uint256 accKacPerShare; // Accumulated Kacos per share, times 1e12. See below.
    }

    mapping(address => bool) public lpSet;

    // The SYRUP TOKEN!
    SyrupBar public syrup;
    // Kaco tokens created per block.
    uint256 public kacPerBlock;
    uint256 public allocBSC;
    uint256 public allocShiden;
    uint256 public kacPerShidenBlock;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Kaco mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event NewMigrator(address prevMigrator, address newMigrator);

    constructor(
        IERC20 _kaco,
        SyrupBar _syrup,
        uint256 _startBlock,
        uint256 _kacPerBlock,
        uint256 _allocBSC,
        uint256 _allocShiden
    ) {
        syrup = _syrup;
        startBlock = _startBlock;
        kacPerBlock = _kacPerBlock;
        allocBSC = _allocBSC;
        allocShiden = _allocShiden;

        updateKacPerShidenBlock(_kacPerBlock, _allocBSC, _allocShiden, false);

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _kaco,
            allocPoint: 0,
            lastRewardBlock: startBlock,
            accKacPerShare: 0
        }));
        lpSet[address(_kaco)] = true;
        totalAllocPoint = 0;
    }

    function updateKacPerBlock(
        uint256 _kacPerBlock,
        bool _withUpdate
    ) external onlyOwner {
        updateKacPerShidenBlock(_kacPerBlock, allocBSC, allocShiden, _withUpdate);
        kacPerBlock = _kacPerBlock;
    }

    function updateAllocBSC(
        uint256 _allocBSC,
        bool _withUpdate
    ) external onlyOwner {
        updateKacPerShidenBlock(kacPerBlock, _allocBSC, allocShiden, _withUpdate);
        allocBSC = _allocBSC;
    }

    function updateAllocShiden(
        uint256 _allocShiden,
        bool _withUpdate
    ) external onlyOwner {
        updateKacPerShidenBlock(kacPerBlock, allocBSC, _allocShiden, _withUpdate);
        allocShiden = _allocShiden;
    }

    function updateKacPerShidenBlock(
        uint256 _kacPerBlock,
        uint256 _allocBSC,
        uint256 _allocShiden,
        bool _withUpdate
    ) internal {
        kacPerShidenBlock = _allocShiden / (_allocBSC + _allocShiden) * _kacPerBlock * 4;
        if (_withUpdate) {
            massUpdatePools();
        }
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) external onlyOwner {
        require(!lpSet[address(_lpToken)], "duplicated lp");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accKacPerShare: 0
        }));
        lpSet[address(_lpToken)] = true;
    }

    // Update the given pool's Kaco allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) external onlyOwner {
        emit NewMigrator(address(migrator), address(_migrator));
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) external {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending Kacos on frontend.
    function pendingCake(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accKacPerShare = pool.accKacPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 kacReward = multiplier.mul(kacPerShidenBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accKacPerShare = accKacPerShare.add(kacReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accKacPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 kacReward = multiplier.mul(kacPerShidenBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accKacPerShare = pool.accKacPerShare.add(kacReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for Kaco allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accKacPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeKacTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accKacPerShare).div(1e12);
        if(_pid == 0){
            syrup.mint(msg.sender, _amount);
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accKacPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeKacTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accKacPerShare).div(1e12);
        if(_pid == 0){
            syrup.burn(msg.sender, _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 userAmount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if(_pid == 0){
            syrup.burn(msg.sender, userAmount);
        }
        pool.lpToken.safeTransfer(address(msg.sender), userAmount);
        emit EmergencyWithdraw(msg.sender, _pid, userAmount);
    }

    // Safe Kaco transfer function, just in case if rounding error causes pool to not have enough Kacos.
    function safeKacTransfer(address _to, uint256 _amount) internal {
        syrup.safeKacTransfer(_to, _amount);
    }
}
