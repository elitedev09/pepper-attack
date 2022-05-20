//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvestorTreasure is Ownable {
    IERC20 public myteToken;
    address public myteWalletAddress;
    uint256 public priceRate;
    uint256 public totalSaleTokens;

    event BuyMyteToken(address sender, uint256 amount);
    event WhiteList(address userAddress, uint256 quota);

    struct WhiteListUser {
        uint256 index;
        uint256 quota;
    }

    mapping(address => WhiteListUser) private whitelistedUsers;
    address[] private whitelistedIndex;

    modifier isSaleActive() {
        require(totalSaleTokens >= getTokenSupply());
        _;
    }

    constructor(address _myteTokenAddress, address _myteWalletAddress) {
        myteToken = IERC20(_myteTokenAddress);
        myteWalletAddress = _myteWalletAddress;
    }

    /// batch set quota for early user quota

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

    function setPriceRate(uint256 _priceRate) external onlyOwner {
        priceRate = _priceRate;
    }

    function getTokenSupply() internal view returns (uint256) {
        return myteToken.balanceOf(address(this));
    }

    receive() external payable {}

    function batchTransferToken() external payable onlyOwner isSaleActive {
        for (uint256 i = 0; i < whitelistedIndex.length; i++) {
            uint256 amountToUser = getTokenToUser(
                whitelistedUsers[whitelistedIndex[i]].quota
            );
            require(
                myteToken.transfer(whitelistedIndex[i], amountToUser),
                "Insufficient token allowance."
            );
            totalSaleTokens += amountToUser;
        }
    }

    function getTokenToUser(uint256 _quota) internal view returns (uint256) {
        return _quota * priceRate;
    }
}
