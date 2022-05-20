//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
contract Controlled {

    address public controller;
   
    modifier onlyController{
        require(msg.sender == controller,'The caller is not controller.');
        _;
    }

    constructor(){
        controller = msg.sender;
    }

    function changeController(address _newController) external onlyController{
        controller = _newController;
    }
}