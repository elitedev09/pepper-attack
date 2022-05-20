//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Owned{

    address public owner;
    address public newOwner;
    
    modifier onlyOwner{
        require(msg.sender == owner,'The caller is not owner.');
        _;
    }
    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() external{
        if(msg.sender == newOwner) {
            owner = newOwner;
        }
    }


}