//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './Controlled.sol';

contract MyteToken is ERC20,Controlled {
    constructor() ERC20("MYTE", "MYTE") {
     
    }
    function mint(address _to,uint256 _amount) external onlyController{
        _mint(_to, _amount);
    }
}