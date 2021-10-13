// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./token/IBEP20.sol";
import "./token/SafeBEP20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Farm is a tweaked MasterChef contract that relies on balance to distribute rewards instead of minting
contract Farm is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of BEP20s
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accBEP20PerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBEP20PerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;             // Address of LP token contract.
        uint256 allocPoint;         // How many allocation points assigned to this pool. BEP20s to distribute per block.
        uint256 lastRewardBlock;    // Last block number that BEP20s distribution occurs.
        uint256 accBEP20PerShare;   // Accumulated BEP20s per share, times 1e36.
        uint256 stakedAmount; // amount stakes
    }

    // Address of the BEP20 Token contract.
    IBEP20 public bep20;
    // The total amount of BEP20 that's paid out as reward.
    uint256 public paidOut = 0;
    // BEP20 tokens rewarded per block.
    uint256 public rewardPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    uint256 public totalAllocPoint = 0;

    // The block when farming starts.
    uint256 public startBlock;

    // The block when farming ends.
    uint256 public endBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(IBEP20 bep20_, uint256 rewardPerBlock_, uint256 startBlock_) {
        // reward token
        bep20 = bep20_;
        rewardPerBlock = rewardPerBlock_;
        startBlock = startBlock_;
        endBlock = startBlock_;
    }

    function initialize (uint256 rewardPerBlock_, uint256 startBlock_) external onlyOwner{
        require(rewardPerBlock == 0 && startBlock == 0);
        rewardPerBlock = rewardPerBlock_;
        startBlock = startBlock_;
        endBlock = startBlock_;
    }

    /*
     Number of LP pools
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /*
       Fund the farm, increase the end block
    */
    function fund(uint256 amount_) public {
        require(block.number < endBlock, "fund: too late, the farm is closed");
        bep20.safeTransferFrom(address(_msgSender()), address(this), amount_);
        endBlock += amount_.div(rewardPerBlock);
    }

    /*
        Add a new pool/token for rewards.
    */
    function add(uint256 allocPoint_, IBEP20 lpToken_, bool withUpdate_) public onlyOwner {
        bool exist = false;
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            exist = poolInfo[pid].lpToken == lpToken_;
        }
        require(!exist);
        if (withUpdate_) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(allocPoint_);
        poolInfo.push(PoolInfo({
        lpToken : lpToken_,
        stakedAmount: 0,
        allocPoint : allocPoint_,
        lastRewardBlock : lastRewardBlock,
        accBEP20PerShare : 0
        }));
    }

    /**
     Update the given pool's BEP20 allocation point.
     */
    function set(uint256 pid_, uint256 allocPoint_, bool withUpdate_) public onlyOwner {
        if (withUpdate_) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[pid_].allocPoint).add(allocPoint_);
        poolInfo[pid_].allocPoint = allocPoint_;
    }

    /**
        returns deposited LP for a user.
     */
    function deposited(uint256 pid_, address user_) external view returns (uint256) {
        UserInfo storage user = userInfo[pid_][user_];
        return user.amount;
    }

    /**
         return pending BEP20s rewards for a user.
     */
    function pending(uint256 pid_, address user_) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid_];
        UserInfo storage user = userInfo[pid_][user_];
        uint256 accBEP20PerShare = pool.accBEP20PerShare;
        uint256 stakedAmount = pool.stakedAmount;
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock > pool.lastRewardBlock && block.number > pool.lastRewardBlock && stakedAmount != 0) {
            uint256 nrOfBlocks = lastBlock.sub(pool.lastRewardBlock);
            uint256 bep20Reward = nrOfBlocks.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accBEP20PerShare = accBEP20PerShare.add(bep20Reward.mul(1e36).div(stakedAmount));
        }

        return user.amount.mul(accBEP20PerShare).div(1e36).sub(user.rewardDebt);
    }

    /**
        returns total reward the farm has yet to pay out.
     */
    function totalPending() external view returns (uint256) {
        if (block.number <= startBlock) {
            return 0;
        }

        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
        return rewardPerBlock.mul(lastBlock - startBlock).sub(paidOut);
    }

    /*
     Update reward variables for all pools. Be careful of gas spending!
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /*
     Update reward variables of the given pool to be up-to-date.
     */
    function updatePool(uint256 pid_) public {
        PoolInfo storage pool = poolInfo[pid_];
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock <= pool.lastRewardBlock) {
            return;
        }
        uint256 stakedAmount = pool.stakedAmount;
        if (stakedAmount == 0) {
            pool.lastRewardBlock = lastBlock;
            return;
        }

        uint256 nrOfBlocks = lastBlock.sub(pool.lastRewardBlock);
        uint256 bep20Reward = nrOfBlocks.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        pool.accBEP20PerShare = pool.accBEP20PerShare.add(bep20Reward.mul(1e36).div(stakedAmount));
        pool.lastRewardBlock = block.number;
    }

    /*
     Deposit LP tokens to Farm for BEP20 allocation.
     Does not support deflation tokens (Volume sets the farm as freeloader so VOL can use this farm)
     */
    function deposit(uint256 pid_, uint256 amount_) public {
        PoolInfo storage pool = poolInfo[pid_];
        UserInfo storage user = userInfo[pid_][msg.sender];
        updatePool(pid_);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount.mul(pool.accBEP20PerShare).div(1e36).sub(user.rewardDebt);
            bep20Transfer(msg.sender, pendingAmount);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), amount_);
        pool.stakedAmount += amount_;
        user.amount = user.amount.add(amount_);
        user.rewardDebt = user.amount.mul(pool.accBEP20PerShare).div(1e36);
        emit Deposit(msg.sender, pid_, amount_);
    }

    /* 
        Withdraw LP tokens from Farm.
    */
    function withdraw(uint256 pid_, uint256 amount_) public {
        PoolInfo storage pool = poolInfo[pid_];
        UserInfo storage user = userInfo[pid_][msg.sender];
        require(user.amount >= amount_, "withdraw: can't withdraw more than deposit");
        updatePool(pid_);
        uint256 pendingAmount = user.amount.mul(pool.accBEP20PerShare).div(1e36).sub(user.rewardDebt);
        bep20Transfer(msg.sender, pendingAmount);
        user.amount = user.amount.sub(amount_);
        user.rewardDebt = user.amount.mul(pool.accBEP20PerShare).div(1e36);
        pool.lpToken.safeTransfer(address(msg.sender), amount_);
        pool.stakedAmount -= amount_;
        emit Withdraw(msg.sender, pid_, amount_);
    }

    /*
        Withdraw without caring about rewards. EMERGENCY ONLY.
    */
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        pool.stakedAmount -= user.amount;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /**
        Transfer BEP20 and update the required BEP20 to payout all rewards
    */
    function bep20Transfer(address _to, uint256 _amount) internal {
        bep20.transfer(_to, _amount);
        paidOut += _amount;
    }
}