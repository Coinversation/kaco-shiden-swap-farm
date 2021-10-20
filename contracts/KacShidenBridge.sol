// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;
}

// Deployed to BSC
contract KacShidenBridge is Ownable {
    IERC20 public kaco;
    IERC20 public tagCoin;
    IMasterChef public masterChef;
    address public anySwap;
    uint256 public minimumAmount;
    uint256 public pid;
    uint256 public maximumAmount;

    event BridgeAmount(uint256 amount);

    constructor(
        IERC20 _kaco,
        IERC20 _tagCoin,
        IMasterChef _masterChef,
        address _anySwap,
        uint256 _pid,
        uint256 _minimumAmount,
        uint256 _maximumAmount
    ) {
        kaco = _kaco;
        tagCoin = _tagCoin;
        masterChef = _masterChef;
        anySwap = _anySwap;
        pid = _pid;
        minimumAmount = _minimumAmount;
        maximumAmount = _maximumAmount;
    }

    function updateMaximumAmoun(uint256 _amount) external onlyOwner {
        maximumAmount = _amount;
    }

    function updateMinimumAmoun(uint256 _amount) external onlyOwner {
        minimumAmount = _amount;
    }

    function updatePid(uint256 _pid) external onlyOwner {
        pid = _pid;
    }

    function updateAnyswap(address _anySwap) external onlyOwner {
        anySwap = _anySwap;
    }

    //transfer tagCoin to this contract before call this function.
    function depositTagCoin() external onlyOwner {
        tagCoin.approve(address(masterChef), type(uint256).max);
        masterChef.deposit(pid, 1 * (10**18));
    }

    function bridgeToShiden() external {
        masterChef.deposit(pid, 0);
        uint256 amount = kaco.balanceOf(address(this));
        if (amount > minimumAmount && amount < maximumAmount) {
            kaco.transfer(anySwap, amount);
            emit BridgeAmount(amount);
        }
    }
}
