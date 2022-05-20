//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CommunityTreasure is Ownable {
    IERC20 public myteToken;
    uint256 public totalTokens;

    event WhiteList(address userAddress, uint256 quota);

    struct WhiteListUser {
        uint256 index;
        uint256 quota;
    }

    mapping(address => WhiteListUser) private whitelistedUsers;
    address[] private whitelistedIndex;
    modifier isActive() {
        require(totalTokens >= getTokenSupply());
        _;
    }

    constructor(address _myteTokenAddress) {
        myteToken = IERC20(_myteTokenAddress);
    }

    function getTokenSupply() internal view returns (uint256) {
        return myteToken.balanceOf(address(this));
    }

    function addWhiteListUsers(
        address[] memory userAddresses,
        uint256[] memory quota
    ) external onlyOwner {
        for (uint256 i = 0; i < userAddresses.length; i++) {
            addWhiteListUser(userAddresses[i], quota[i]);
        }
    }

    function addWhiteListUser(address userAddress, uint256 quota)
        public
        onlyOwner
    {
        if (!isWhiteListed(userAddress)) {
            whitelistedUsers[userAddress].quota = quota;
            whitelistedIndex.push(userAddress);
            whitelistedUsers[userAddress].index = whitelistedIndex.length - 1;
        }
        emit WhiteList(userAddress, quota);
    }

    function isWhiteListed(address userAddress)
        public
        view
        returns (bool isIndeed)
    {
        if (whitelistedIndex.length == 0) return false;
        return (whitelistedIndex[whitelistedUsers[userAddress].index] ==
            userAddress);
    }

    function batchTransferToken() external onlyOwner isActive {
        for (uint256 i = 0; i < whitelistedIndex.length; i++) {
            require(
                myteToken.transfer(
                    whitelistedIndex[i],
                    whitelistedUsers[whitelistedIndex[i]].quota
                ),
                "Insufficient token allowance."
            );
            totalTokens += whitelistedUsers[whitelistedIndex[i]].quota;
        }
    }
}
