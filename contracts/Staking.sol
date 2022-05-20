//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libs/EnumerableSet.sol";
import "./interface/IERC721.sol";

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract Staking is IERC721Receiver {

    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using Math for uint256;
    // Event to track the data in EVM blockchain
    event Stake(address sender, address receiver, uint256 tokenId);
    event Unstake(address sender, address receiver, uint256 tokenId);
    event Claim(address user, uint256 tokenId);

    enum DurationIndex {
        LOW,
        MID,
        HIGH
    }
    enum LevelIndex {
        ONE,
        TWO,
        THREE,
        FOUR,
        FIVE
    }

    IERC721 public nftToken;
    IERC20 public myteToken;
    address public owner;

    //The structure of data of staked Pepper token
    /**
        @TODO: We will need at least 2 test cases here to test the lockedRate and lockedClaimDuration when
                - setRateMutiplier is called
                - Level is updated and rate changes
     */
    struct StakingData {
        uint256 tokenId;
        uint256 lockedRate; // The rate for a staking Pepper is always its initial rate        
        uint256 startTime;
        uint256 endTime;
        uint256 lastClaimPoint;
    }

    // Durations in seconds
    uint256 public lowDurationInSeconds;
    uint256 public midDurationInSeconds;
    uint256 public highDurationInSeconds;

    uint256[][] public rateTable;
    uint256 public rateMultiplier;
    LevelIndex currentLevel;

    uint256 public claimDurationInDays;
    uint256 public claimDurationInSeconds;

    // Mapping tokenId -> staking meta data
    mapping(address => mapping(uint256 => StakingData)) public stakingMap;

    // Mapping owner address -> staking Peppers
    mapping(address => uint256[]) public stakingPeppers;

    // holders 
      EnumerableSet.AddressSet private holders; 

    bool isFreeUnstake = false;
    bool isStakingActive = true;

    // Amounts according to LevelIndex
    uint256 public LEVEL_ONE_AMOUNT = 450e6 ether;
    uint256 public LEVEL_TWO_AMOUNT = 250e6 ether;
    uint256 public LEVEL_THREE_AMOUNT = 125e6 ether;
    uint256 public LEVEL_FOUR_AMOUNT = 50e6 ether;
    uint256 public LEVEL_FIVE_AMOUNT = 25e6 ether;

    modifier onlyOwner() {
        require(msg.sender == owner, "The caller is not owner.");
        _;
    }

    constructor(address _nftAddress, address _tokenAddress) {
        nftToken = IERC721(_nftAddress);
        myteToken = IERC20(_tokenAddress);
        owner = msg.sender;
        // Level starts at 1
        currentLevel = LevelIndex.ONE;
        // The default claim duration is 1 day
        setClaimDuration(1);
        // The default durations are 30, 90 and 180 days
        setDurationDays(30, 90, 180);
    }

    function initialize() external onlyOwner {
        rateTable = new uint256[][](n);
        rateTable[0][0] = 90 ether;
        rateTable[0][1] = 120 ether;
        rateTable[0][2] = 150 ether;

        rateTable[1][0] = 45 ether;
        rateTable[1][1] = 60 ether;
        rateTable[1][2] = 75 ether;

        rateTable[2][0] = 24 ether;
        rateTable[2][1] = 32 ether;
        rateTable[2][2] = 40 ether;

        rateTable[3][0] = 12 ether;
        rateTable[3][1] = 16 ether;
        rateTable[3][2] = 20 ether;

        rateTable[4][0] = 6 ether;
        rateTable[4][1] = 8 ether;
        rateTable[4][2] = 10 ether;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function stake(uint256 _tokenId, DurationIndex _stakeDurationIndex)
        external
    {
        require(
            !_isPepperStaking(_tokenId, msg.sender),
            "Your Pepper is being staked already."
        );
        uint256 rate = getCurrentRate(_stakeDurationIndex);
        require(rate > 0, "Staking is inactive.");
        // Send the token from user address to staking contract.
        nftToken.safeTransferFrom(msg.sender, address(this), _tokenId, "");

        uint256 startTime = _getCurrentTime();
        uint256 stakeDurationInSeconds = _convertDurationToSeconds(
            _stakeDurationIndex
        );
        uint256 endTime = SafeMath.add(startTime, stakeDurationInDays);
        uint256 lastClaimPoint = startTime;

        // Instance of staked NFT
        StakingData memory stakingData = StakingData(
            _tokenId,
            rate,
            claimDurationInSeconds,
            startTime,
            endTime,
            lastClaimPoint
        );

        stakingMap[msg.sender][_tokenId] = stakingData;
        stakingPeppers[msg.sender].push(_tokenId);
        if(!holders.contains(msg.sender)){
            holders.add(msg.sender);
        }

        emit Stake(msg.sender, address(this), _tokenId);
    }

    /**@dev Checking the tokenId of staker is exist inside staking contract already.
     * @param _tokenId:uint256 . The tokenId which is staking into staking contract.
     * @param _userAddress :address. The address of staker .
     * @return flag: bool . returning the flag to check tokenId.
     */

    function _isPepperStaking(uint256 _tokenId, address _userAddress)
        internal
        view
        returns (bool)
    {
        // @TODO: will a for loop here expensive?
        //  If no, ignore the below comments
        //
        // If yes, use a struct for stakingPeppers[_userAddress] to avoid the for loop here
        // This function basically check if a tokenId exists in stakingData[_userAddress] struct
        // Maybe we can use it instead of stakingPeppers

        uint256[] storage tokens = stakingPeppers[_userAddress];
        bool flag = false;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _tokenId) {
                flag = true;

                break;
            }
        }

        return flag;
    }

    function _getCurrentTime() internal returns (uint256) {
        return block.timestamp;
    }

    // convert days to timestamp
    function _convertDaysToSeconds(uint256 _duration)
        internal
        returns (uint256)
    {
        return _duration * 1 days;
    }

    function getCurrentRate(DurationIndex _duration)
        external
        view
        returns (uint256)
    {
        uint256 currentRate = 0;

        if (!isStakingActive) {
            return 0;
        }

        if (_currentLevel == LevelIndex.ONE && _duration == DurationIndex.LOW) {
            currentRate = rateTable[0][0];
        } else if (
            _currentLevel == LevelIndex.ONE && _duration == DurationIndex.MID
        ) {
            currentRate = rateTable[0][1];
        } else if (
            _currentLevel == LevelIndex.ONE && _duration == DurationIndex.HIGH
        ) {
            currentRate = rateTable[0][2];
        } else if (
            _currentLevel == LevelIndex.TWO && _duration == DurationIndex.LOW
        ) {
            currentRate = rateTable[1][0];
        } else if (
            _currentLevel == LevelIndex.TWO && _duration == DurationIndex.MID
        ) {
            currentRate = rateTable[1][1];
        } else if (
            _currentLevel == LevelIndex.TWO && _duration == DurationIndex.HIGH
        ) {
            currentRate = rateTable[1][2];
        } else if (
            _currentLevel == LevelIndex.THREE && _duration == DurationIndex.LOW
        ) {
            currentRate = rateTable[2][0];
        } else if (
            _currentLevel == LevelIndex.THREE && _duration == DurationIndex.MID
        ) {
            currentRate = rateTable[2][1];
        } else if (
            _currentLevel == LevelIndex.THREE && _duration == DurationIndex.HIGH
        ) {
            currentRate = rateTable[2][2];
        } else if (
            _currentLevel == LevelIndex.FOUR && _duration == DurationIndex.LOW
        ) {
            currentRate = rateTable[3][0];
        } else if (
            _currentLevel == LevelIndex.FOUR && _duration == DurationIndex.MID
        ) {
            currentRate = rateTable[3][1];
        } else if (
            _currentLevel == LevelIndex.FOUR && _duration == DurationIndex.HIGH
        ) {
            currentRate = rateTable[3][2];
        } else if (
            _currentLevel == LevelIndex.FIVE && _duration == DurationIndex.LOW
        ) {
            currentRate = rateTable[4][0];
        } else if (
            _currentLevel == LevelIndex.FIVE && _duration == DurationIndex.MID
        ) {
            currentRate = rateTable[4][1];
        } else if (
            _currentLevel == LevelIndex.FIVE && _duration == DurationIndex.HIGH
        ) {
            currentRate = rateTable[4][2];
        }

        return currentRate * rateMultiplier;
    }

    /** @dev The unstake function to unstake the Pepper NFT token of staker from staking contract
     *       to user address.
     * @param _tokenId:uint256. The tokenId of staker to unstake from staking contract.
     *
     */

    function unstake(uint256 _tokenId) external {
        require(
            _isPepperStaking(_tokenId, msg.sender),
            "This Pepper has not been staked yet."
        );

        int256 endBlockNumber = stakingMap[_userAddress][_tokenId]
            .endBlockNumber;

        require(
            _getCurrentBlockNumber() >= endBlockNumber || isFreeUnstake,
            "You can not unstake before the end of the staking duration."
        );

        // Get rewards, update level and staking data
        _executeClaim(msg.sender, _tokenId);

        // remove the Pepper in staked NFTs inside staking contract
        _unstakePepper(msg.sender, _tokenId);

        // return the Pepper from staking contract to user address
        nftToken.safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Unstake(address(this), msg.sender, _tokenId);
    }

    function _unstakePepper(address _userAddress, uint256 _tokenId) internal {
        // removing staking data from staking Map
        delete stakingMap[_userAddress][_tokenId];

        // removing the tokenId from staking Pepper list
        uint256[] storage usersStakingPeppers = stakingPeppers[_userAddress];
        uint256 size = usersStakingPeppers.length;
        for (uint256 i = 0; i < size; i++) {
            if (usersStakingPeppers[i] == _tokenId) {
                usersStakingPeppers[i] = usersStakingPeppers[
                    SafeMath.sub(size, 1)
                ];
                usersStakingPeppers.pop();
                break;
            }
        }
    }

    function _convertDurationToSeconds(DurationIndex _durationIndex)
        internal
        view
        returns (uint256)
    {
        uint256 durationInSeconds;
        if (DurationIndex.LOW == _durationIndex) {
            durationInSeconds = lowDurationInSeconds;
        } else if (DurationIndex.MID == _durationIndex) {
            durationInSeconds = midDurationInSeconds;
        } else if (DurationIndex.HIGH == _durationIndex) {
            durationInSeconds = highDurationInSeconds;
        }

        return durationInSeconds;
    }

    function _getCurrentBlockNumber() internal view returns (uint256) {
        return block.number;
    }

    function setFreeUnstake(bool _isFreeUnstake) external onlyOwner {
        isFreeUnstake = _isFreeUnstake;
    }

    function setStakingActive(bool _isStakingActive) external onlyOwner {
        isStakingActive = _isStakingActive;
    }

    function _updateLevel() internal {
        uint256 remainTotalSupply = _getTotalSupply();

        if (remainTotalSupply >= LEVEL_TWO_AMOUNT) {
            currentLevel = LevelIndex.ONE;
        } else if (remainTotalSupply >= LEVEL_THREE_AMOUNT) {
            currentLevel = LevelIndex.TWO;
        } else if (remainTotalSupply >= LEVEL_FOUR_AMOUNT) {
            currentLevel = LevelIndex.THREE;
        } else if (remainTotalSupply >= LEVEL_FIVE_AMOUNT) {
            currentLevel = LevelIndex.FOUR;
        } else if (remainTotalSupply > 0) {
            currentLevel = LevelIndex.FIVE;
        } else {
            setStakingActive(false);
        }
    }

    function _getTotalSupply() internal returns (uint256) {
        return myteToken.balanceOf(address(this));
    }

 

    function _executeClaim(address _userAddress, uint256 _tokenId) internal {
        uint256 lastClaimPoint = stakingMap[_userAddress][_tokenId]
            .lastClaimPoint;
        // Number of seconds past since the last claim time
        uint256 numClaimPeriods = _calculateNumClaimPeriod(lastClaimPoint);
        uint256 reward = _calculateReward(
            stakingMap[_userAddress][_tokenId].lockedRate,
            numClaimPeriods
        );

        if (reward > 0) {
            // Transfer MYTE to the staker
            require(
                myteToken.transferFrom(address(this), _userAddress, reward),
                "The token can not transfer."
            );
            //
            _updateLevel();

            /**
            We will need at least 2 following test cases for the below formula
            Case 1: 
            X stakes on Sep 1 at 4AM, duration is 30 days, claimDuration is 1 day. lastClaimPoint is Sep 1, 4AM
            X claims on Sep 2 at 7AM -> the lastClaimPoint should be Sep 2, 4AM

            Case 2: 
            X stakes on Sep 1 at 4AM, duration is 30 days, claimDuration is 7 day. lastClaimPoint is Sep 1, 4AM
            X claims on Sep 11 at 7AM -> the lastClaimPoint should be Sep 8, 4AM
             */

            // Update lastClaimPoint with currentClaimPoint
            uint256 currentClaimPoint = SafeMath.add(
                lastClaimPoint,
                SafeMath.mul(numClaimPeriods, claimDurationInSeconds)
            );
            stakingMap[_userAddress][_tokenId].lastClaimPoint = currentClaimPoint;
        }
    }

    function _calculateNumClaimPeriod(uint256 lastClaimPoint) {
        uint256 secondDiff = SafeMath.sub(_getCurrentTime(), lastClaimPoint);
        // Number of claim periods since the last claim time
        return SafeMath.div(
            secondDiff,
            claimDurationInSeconds
        );
    }
    
    function _calculateReward(uint256 rate, uint256 numClaimPeriods)
        internal
        view
        returns (uint256)
    {
        // No reward if claiming before the claim duration
        if (numClaimPeriods < 1) {
            return 0;
        }

        uint256 estimatedReward = SafeMath.mul(
            numClaimPeriods,
            claimDurationInDays,
            rate
        );

        uint256 reward = Math.min(_getTotalSupply(), estimatedReward);

        return reward;
    }

    /** @dev The claim function to get the reward instead of staked Pepper NFT.
     *  @param _tokenId : uint256 , the tokenId of staker inside staking contract.
     */

    function claim(uint256 _tokenId) external {
        require(
            _isPepperStaking(_tokenId, msg.sender),
            "This Pepper has not been staked yet."
        );
        require(
            !_isClaimTimeValid(msg.sender, _tokenId),
            "You cannot claim yet."
        );
        _executeClaim(msg.sender, _tokenId);
        emit Claim(msg.sender, _tokenId);
    }

    function _isClaimTimeValid(address _userAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        uint256 currentTime = _getCurrentTime();
        uint256 timeDiff = SafeMath.sub(
            currentTime,
            stakingMap[_userAddress][_tokenId].lastClaimPoint
        );

        uint256 endTime = stakingMap[_userAddress][_tokenId].endTime;
        /**
        We will need to test case to cover an edge case here at the end of the staking 
        For example: 
            X stakes on Sep 1 at 4AM, duration is 30 days, claimDuration is 7 day.
            X claims on Sep 29 at 4AM -> the lastClaimBlock is Sep 29, 4AM
            X claims on September 30 at 4AM -> He should be able to claim, because it is the end of his staking duration            
        */
        return timeDiff >= claimDurationInSeconds || currentTime >= endTime;
    }

    // Extra function just in case the 30 / 90 / 180 days need to be updated during production time
    function setDurationDays(
        uint256 _lowDurationInDays,
        uint256 _midDurationInDays,
        uint256 _highDurationInDays
    ) external onlyOwner {
        require(
            _lowDurationInDays > 0 && _midDurationInDays > 0 && _high > 0,
            "The duration cannot be zero."
        );
        lowDurationInSeconds = SafeMath(_lowDurationInDays, 1 days);
        midDurationInSeconds = SafeMath(_midDurationInDays, 1 days);
        highDurationInSeconds = SafeMath(_highDurationInDays, 1 days);
    }

    function setClaimDuration(uint256 _numDays) external onlyOwner {
        require(_numDays > 0, "Claim duration must be greater than zero.");
        claimDurationInDays = _numDays;

        uint256 _claimDurationInSeconds = _convertDaysToSeconds(_numDays);
        require(
            _claimDurationInSeconds > 0,
            "Claim duration must be greater than zero."
        );
        claimDurationInSeconds = _claimDurationInSeconds;
    }

    function setRateMutiplier(uint256 multiplier) external onlyOwner {
        require(multiplier > 1, "Rate multiplier must be greater than 1.");
        rateMultiplier = multiplier;
    }

    function resetRateMultiplier() external onlyOwner {
        rateMultiplier = 1;
    }

    function numStakingPeppers(address[] memory stakers) external view returns(uint256) {
        // @TODO: return the number of Pepper that are staked here
        // Something like stakingData[address_1].length + stakingData[address_2].length + ....
        // OR
        // Build a counter of numStakingPeppers and keep track of it during staking and unstaking events
        uint256 totalStakingNumber;
        for(uint256 i = 0 ; i < stakers.length ; i++){
          
                totalStakingNumber +=stakingPeppers[stakers[i]].length;
        }

        return totalStakingNumber;
    }

    function numStakingOwner() external view returns(uint256) {
        //@TODO: return the number of owners that has at least 1 Pepper Staking
        // The condition is something like: stakingData[address].length > 0
        require(holders.length() > 0,"The holder is not exist yet.");
        return holders.length();
        
    }

    function stakingOwners(uint256 startIndex,uint256 endIndex) external view returns(address[] memory stakers){
        // @TODO: return the addresses of all owners with at least 1 pepper staking
        // The condition is something like: stakingData[address].length > 0
        require(startIndex < endIndex);
        uint256 length = endIndex - startIndex;
        address[] memory _stakers = new address[](length);
        
        for(uint256 i = startIndex; i < endIndex; i++){
            address staker = holders.at(i);
            uint256 listIndex = i - startIndex;
            _stakers[listIndex] = staker;

        }

        return _stakers;
    }


    function getPendingReward(uint256 tokenId) internal view returns(uint256) {
        uint256 lastClaimPoint = stakingData[msg.sender][tokenId].lastClaimPoint;
        uint256 numClaimPeriod = _calculateNumClaimPeriod(lastClaimPoint);
        uint256 reward = _calculateReward(numClaimPeriod);

        return reward;

    }

    

    function getPendingRewards() external view returns(uint256 totalReward) {

        /** @TODO return the current pending reward for all staking Peppers of an address. Something like:
        */
       for(uint256 i = 0 ; i <  stakingPeppers[msg.sender].length ; i++){
           totalReward += getPendingReward(stakingPeppers[msg.sender][i]);
       }

        return totalReward;
    }

    // function getAllPendingRewards() external view {
    //     /** @TODO return the current pending reward for all staking Peppers of an address. Something like:
    //     uint256 totalReward = 0;
    //     for each tokenId in stakingData[msg.sender]
    //         uint256 rewards = getPendingReward(tokenId)
    //         totalReward += rewards;
    //     return totalReward         
    //      */
    // }

    function getLastClaimTime(uint256 _tokenId) external view {
        require(
            _isPepperStaking(_tokenId, msg.sender),
            "This Pepper has not been staked yet."
        );
        return stakingData[msg.sender][_tokenId].lastClaimPoint;
    }
}
