//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DeveloperTreasure is Ownable{
    
    IERC20 public myteToken;
    uint256 public finalizedBlock;
    uint256 public totalTokens;

     uint256 public constant MONTH = 30 days;

    event WhiteList(address userAddress, uint256 quota);
    event Finalize(uint256 finalizedBlock);

    struct WhiteListDev{
        uint256 index;
        uint256 quota;
    }

    mapping(address => WhiteListDev) private whitelistedDevs;
    address[] private whitelistedIndex;

    constructor(address _myteTokenAddress){
       myteToken = IERC20(_myteTokenAddress);
    }

    function addWhiteListDevs(
        address[] memory devAddresses,
        uint256[] memory quota
    ) external onlyOwner{
        for(uint256 i = 0 ; i < devAddresses.length;i++){
            addWhiteListDev(devAddresses[i],quota[i]);
        }
    }

    function addWhiteListDev(address devAddress,uint256 quota) internal onlyOwner{
       
       if(!isWhiteListed(devAddress)){
           whitelistedDevs[devAddress].quota = quota;
           whitelistedIndex.push(devAddress);
           whitelistedDevs[devAddress].index = whitelistedIndex.length - 1;

       }
       emit WhiteList(devAddress,quota);
        
    }

    function finalize() external onlyOwner{
        finalizedBlock = block.number;
        emit Finalize(finalizedBlock);
    }
    
    function getCurrentBlock() public view returns (uint256) {
        return block.number;
    }

     function getUnlockAtBlockNumber(uint256 mm) public view returns (uint256) {
        uint256 blockNumber = finalizedBlock + 
        (mm * MONTH * 24 * 60 * 60) / 15; // 15 second per block
        return blockNumber;
    }

    function isWhiteListed(address devAddress) internal view returns(bool isIndeed){
        if(whitelistedIndex.length == 0) return false;
        return (whitelistedIndex[whitelistedDevs[devAddress].index] == devAddress);
    }

    function getTokenSupply() internal view returns(uint256){
        return myteToken.balanceOf(address(this));
    }

    function batchTransferToken()  external onlyOwner{
       
       require(getCurrentBlock() >= getUnlockAtBlockNumber(24),"The token was locked yet.");
       require(totalTokens >= getTokenSupply(),"The token is insufficient."); 
        for (uint256 i = 0; i < whitelistedIndex.length; i++) {
            require(
                myteToken.transfer(whitelistedIndex[i], whitelistedDevs[whitelistedIndex[i]].quota),
                "Insufficient token allowance."
            );
            totalTokens += whitelistedDevs[whitelistedIndex[i]].quota;
        }

    }
}