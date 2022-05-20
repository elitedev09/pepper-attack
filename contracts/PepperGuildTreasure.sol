//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract PepperGuildTreasure is Ownable{
    
    IERC20 public myteToken;
    address public walletAddress;

    constructor(address _myteTokenAddress,address _walletAddress){
         myteToken = IERC20(_myteTokenAddress);
         walletAddress = _walletAddress;
    }

    function getTokenSupply() internal view returns(uint256){
        return myteToken.balanceOf(address(this));
    }

    


}