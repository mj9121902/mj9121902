// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyToken.sol";

contract TokenStaking {
    MyToken public token;
    address public staker;
    uint256 public stakedAmount;
    uint256 public unlockTimestamp;

    constructor(address _tokenAddress, uint256 _unlockTimestamp) {
        token = MyToken(_tokenAddress);
        staker = msg.sender;
        unlockTimestamp = _unlockTimestamp;
    }

    function stake(uint256 _amount) public {
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        stakedAmount += _amount;
    }

    function withdraw() public {
        require(msg.sender == staker, "Not authorized");
        require(block.timestamp >= unlockTimestamp, "Staking period not over");
        require(token.transfer(staker, stakedAmount), "Transfer failed");
        stakedAmount = 0;
    }
}
