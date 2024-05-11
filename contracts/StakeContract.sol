// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol"; 

contract StakeContract is ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable{

    string public version;

    struct StakePools{
        string stakePoolId;
        string name;
        uint startDate;
        uint endDate;
        uint apy;
        uint poolTotalStakedAmount;
        bool isPaused;
        uint256 minStakingAmount;
        uint256 maxStakingLimit;
        bool isDeleted;

    }

    uint256 _totalPools;

    // listining
    string[] private _allStakePools;
    string[] private _allStakePoolIds;


    //Stake Pool
    mapping(string=>StakePools) private _stakePool;

    // Stakes holder
    struct Stakes{
        string stakePoolId;
        uint256 stakeId;
        uint startDate;
        uint256 lastStakeRewardTime;
        uint stakeAmount;
        uint stakeReward;

        //the reward that would be given to the user at the end of the stake time (the pool time)
        uint256 totalReward; 
        address userAddress; 
    }

    uint256 private idCounter;

    mapping( string => mapping ( address => mapping(uint256 => Stakes)) ) private _stakes;

    uint256[] private _allStakeIds;

    mapping(string => mapping(address => uint256[])) private _userPoolStakeIds;

    mapping(string => Stakes[]) private _stakesInPool;


    //the user
    struct User{
        address account;
        uint256 totalStakedAmount;
        uint256 totalClaimedRewards;
    }

    uint256 _totalUsers;
    string[] private _allUserIds;

    //User mapping

    mapping( string => mapping ( address => User) ) private _users;

    IERC20 private _token;

    //Address of the Staking 
    address private _tokenAddress;

    //================== EVENTS ========================

    event Stake(address indexed user, uint256 amount); // when staking
    event UnStake(address indexed user, uint256 amount); // when unstaking
    event EarlyUnStakeFee(address indexed user, uint256 amount); // when early staking
    event ClaimReward(address indexed user, uint256 amount); //when clamin the reward
    event StakePoolCreated(string indexed stakePoolId, string name, uint startDate, uint endDate, uint apy, uint256 minStakingAmount, uint256 maxStakingLimit);

    event StakePoolUpdated(string indexed stakePoolId, string name, uint startDate, uint endDate, uint apy, uint256 minStakingAmount, uint256 maxStakingLimit);

    //================== MODIFIERS ========================

    //Chekcs if the address has enought balance
    modifier whenTreasuryHasBalance(uint256 amount){

        require(_token.balanceOf(address(this)) >= amount, "Insufficient funds in the treasury.");
        _;
    }

    function setTokenAddress(address tokenAddress_) public  onlyOwner {
        _tokenAddress = tokenAddress_;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize(address initialOwner, address tokenAddress_) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        version = "v2.0";
        _token = IERC20(tokenAddress_);
        _tokenAddress = tokenAddress_;
    }


    //Creates new Stake pool
    function createStakePool(string memory stakePoolId,
        string memory name,
        uint startDate,
        uint endDate,
        uint apy,
        uint256 minStakingAmount,
        uint256 maxStakingLimit) public onlyOwner{

        bool isPoolExists = bytes(_stakePool[stakePoolId].stakePoolId).length != 0;

        require(apy <= 10000, "APY rate should be less then 10000");

        require(startDate < endDate, "Start date connot be greater than the end date");


        require(!isPoolExists, "The pool has already been created.");

        // uint daysOfPool = getStakingDurationInDays(startDate, endDate);
        // Create a new stake pool
        StakePools memory newPool = StakePools({
            stakePoolId: stakePoolId,
            name: name,
            startDate: startDate,
            endDate: endDate,
            apy: apy,
            poolTotalStakedAmount: 0,
            isPaused: false,
            minStakingAmount: minStakingAmount,
            maxStakingLimit: maxStakingLimit,
            isDeleted: false
            // daysOfPool:daysOfPool 
        });

        // set it
        _stakePool[stakePoolId] = newPool;
        
        _allStakePools.push(stakePoolId);
        _allStakePoolIds.push(stakePoolId);


        emit StakePoolCreated(stakePoolId, name, startDate, endDate, apy, minStakingAmount, maxStakingLimit);

    }

    function checkStakingConditions(uint256 _amount, string memory _stakePoolId) internal view {


        require(_stakePool[_stakePoolId].isDeleted == false, "The pool has been deleted.");
        require(_amount > 0, "Stake amount must be non-zero.");
        require(!_stakePool[_stakePoolId].isPaused, "The stake is paused.");
        require(block.timestamp > _stakePool[_stakePoolId].startDate, "Staking not started yet");
        require(_stakePool[_stakePoolId].endDate > block.timestamp, "Staking is ended.");
        require(_amount <= _stakePool[_stakePoolId].maxStakingLimit, "Max staking token limit reached");
        require(_amount >= _stakePool[_stakePoolId].minStakingAmount, "Stake Amount must be greater than min. amount allowed.");
    }


    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount, string memory _stakePoolId) public nonReentrant {
        
        //Some validations
        checkStakingConditions(_amount, _stakePoolId);

        bool isUserExistsInThePool = _users[_stakePoolId][userAddress].account != address(0);
 
        //If the user didn't register for the stake pool
        if(!isUserExistsInThePool)
        {
            _totalUsers +=1;
        }

        //make the transfer
        _token.transferFrom(userAddress, address(this), _amount);

        uint256 stakeId =  generateId();

        // uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;
        Stakes memory newStake = Stakes({
                stakePoolId:_stakePoolId,
                stakeId: stakeId,
                lastStakeRewardTime: block.timestamp,
                startDate: block.timestamp,
                stakeAmount: _amount,
                stakeReward: 0,
                totalReward: 0, 
                userAddress: userAddress 
        });

        _stakes[_stakePoolId][userAddress][stakeId] = newStake;

        //Update the users info
        _users[_stakePoolId][userAddress].totalStakedAmount += _amount;

        //calculate the total reward for the current stake
        uint256 totalReward = totalRewardsOfStake(userAddress, _stakePoolId, stakeId);

        _stakesInPool[_stakePoolId].push(newStake);

        //update it
        _stakes[_stakePoolId][userAddress][stakeId].totalReward =totalReward; 

        _userPoolStakeIds[_stakePoolId][userAddress].push(stakeId);       _allStakeIds.push(stakeId);

        //Throw an event
        emit Stake(userAddress, _amount);
    }

    // Function to calculate daily interest based on APY and stake amount
    function calculateDailyInterest(uint256 stakeAmount, uint256 apy) internal pure returns(uint256) {
        uint256 dailyRate = (apy * 1e18) / 36500;
        return stakeAmount * dailyRate / 1e20;
    }

    //Total reward of a spesific stake in a pool.
    function calculateTotalRewardsOfStake(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {

        // Staked amount
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

        uint stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;

        // APY of the pool
        uint256 apyRate = _stakePool[_stakePoolId].apy;

        uint stakeDays = getStakingDurationInDays(stakeStartDate, stakePoolEndDate); 

        uint256 dailyRate = (apyRate * 1e18) / 36500; 

        uint256 interestPerDay = stakeAmount * dailyRate / 1e20; 
        uint256 totalRewardOfTheStake = interestPerDay * stakeDays;

        return totalRewardOfTheStake;
    }

    function totalRewardsOfStake(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {

        // Fetch stake details
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;
        uint256 stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;

        uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;
        // Calculate the duration in seconds
        uint256 durationInSeconds = getStakingDurationInSeconds(stakeStartDate, stakePoolEndDate);

        // Calculate interest per second based on APY and stake amount
        uint256 perSecondInterest = calculatePerSecondInterest(stakeAmount, _stakePool[_stakePoolId].apy);

        // Sum up total rewards earned during the duration in seconds
        uint256 totalInterestReward = perSecondInterest * durationInSeconds;

        return totalInterestReward;  
    }

    function calculateRewardInSeconds(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {
        // Fetch stake details
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;
        uint256 lastRewardTime = _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime; 
        uint256 stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

        // Calculate the duration in seconds
        uint256 durationInSeconds = getStakingDurationInSeconds(lastRewardTime, block.timestamp < stakeEndDate ? block.timestamp : stakeEndDate);
        uint256 totalStakeSeconds = getStakingDurationInSeconds(stakeStartDate, stakeEndDate);

        // Calculate interest per second based on APY and stake amount
        uint256 perSecondInterest = calculatePerSecondInterest(stakeAmount, _stakePool[_stakePoolId].apy);
        uint256 perSecondPrincipalReturn = stakeAmount / totalStakeSeconds;

        // Sum up total rewards earned during the duration in seconds
        uint256 totalInterestReward = perSecondInterest * durationInSeconds;
        uint256 totalPrincipalReturn = perSecondPrincipalReturn * durationInSeconds;

        // Calculate total reward including principal
        uint256 totalRewardWithPrincipal = totalInterestReward + totalPrincipalReturn;

        return totalRewardWithPrincipal; 
    }

    // Function to calculate per-second interest
   function calculatePerSecondInterest(uint256 stakeAmount, uint256 apy) internal pure returns (uint256) {
        uint256 annualInterest = stakeAmount * apy / 10000; 

        return annualInterest / (365 * 24 * 3600); 
    }

    function getStakingDurationInSeconds(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        return _endTimestamp - _startTimestamp;
    }


    //rewards for each stake
    function claimReward4Each(address userAddress, string memory _stakePoolId, uint256 _stakeId) public returns(uint256){

        require(block.timestamp > _stakePool[_stakePoolId].endDate, "Stake Pool has not ended yet.");

        uint256 rewardAmount = calculateRewardInSeconds(userAddress, _stakePoolId, _stakeId);

        _stakes[_stakePoolId][userAddress][_stakeId].stakeReward = rewardAmount; 

        _token.transfer(userAddress, rewardAmount);

        _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime = block.timestamp; 

        emit ClaimReward(userAddress, rewardAmount);
        return rewardAmount;
    }

    //total rewards of te usr's  stakes 
    function claimReward4Total(address userAddress, string memory _stakePoolId) public returns(uint256){

        uint256[] memory relevantStakeIds = _userPoolStakeIds[_stakePoolId][userAddress];

        uint countStakeOfPool = relevantStakeIds.length;
        uint256 rewardAmount = 0;

        require(block.timestamp > _stakePool[_stakePoolId].endDate, "Stake Pool has not ended yet.");

        for(uint256 i = 0; i < countStakeOfPool; i++){

            uint256 stakeId = relevantStakeIds[i];
            uint256 rewardOfStake = calculateRewardInSeconds(userAddress, _stakePoolId, stakeId);

            _stakes[_stakePoolId][userAddress][stakeId].stakeReward = rewardOfStake; 

            rewardAmount += rewardOfStake;

            uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

            //Update last stake time
            if (block.timestamp < stakeEndDate) {
                _stakes[_stakePoolId][userAddress][stakeId].lastStakeRewardTime = block.timestamp;
            } else {
                _stakes[_stakePoolId][userAddress][stakeId].lastStakeRewardTime = stakeEndDate;
            }
        }

        require(rewardAmount > 0,"No token to claim" );
        _token.transfer(userAddress, rewardAmount);

        emit ClaimReward(userAddress, rewardAmount);
        return rewardAmount;
    }

    function getTotalRewardsInThePoolOfUser(address userAddress, string memory _stakePoolId) public view returns(uint256){

        uint256[] memory relevantStakeIds = _userPoolStakeIds[_stakePoolId][userAddress];

        uint countStakeOfPool = relevantStakeIds.length;
        uint256 rewardAmount = 0;

        for(uint256 i = 0; i < countStakeOfPool; i++){

            uint256 stakeId = relevantStakeIds[i];
            uint256 rewardOfStake = calculateRewardInSeconds(userAddress, _stakePoolId, stakeId);

            rewardAmount += rewardOfStake;
        }
        return rewardAmount;
    }


    function getAllStakePools() public view returns (StakePools[] memory) {
        uint length = _allStakePoolIds.length;
        StakePools[] memory pools = new StakePools[](length);
        for (uint i = 0; i < length; i++) {
            string memory poolId = _allStakePools[i];
            pools[i] = _stakePool[poolId];
        }
        return pools;
    }

    function getStakePoolById(string memory _stakePoolId)public view returns(StakePools memory){
        return _stakePool[_stakePoolId];
    }

    function getAllUserStakesByStakePoolsId(string memory _stakePoolId, address _userAddress) public view returns (Stakes[] memory) {
        uint length = _allStakeIds.length;
        Stakes[] memory stakes = new Stakes[](length);
        for (uint i = 0; i < length; i++) {
            uint256 poolId = _allStakeIds[i];
            stakes[i] = _stakes[_stakePoolId][_userAddress][poolId];
        }
        return stakes;
    }

    function getStakeById(string memory _stakePoolId, address _userAddress, uint256 _stakeId)public view returns(Stakes memory){

        return _stakes[_stakePoolId][_userAddress][_stakeId];
    }

    //Enabling or disabling the staking
    function toggleStakingStatus(string memory _stakePoolId) public onlyOwner{
         _stakePool[_stakePoolId].isPaused = !_stakePool[_stakePoolId].isPaused;
    }

    function setIsDeleted(string memory _stakePoolId) public onlyOwner{
         _stakePool[_stakePoolId].isDeleted = !_stakePool[_stakePoolId].isDeleted;
    }

    function getStakingDurationInDays(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        uint256 durationInSeconds = _endTimestamp - _startTimestamp;
        uint256 durationInDays = durationInSeconds / 60 / 60 / 24;
        return durationInDays;
    }
    
    function calculateStakeRewardWithDefinedAmount(string memory _stakePoolId, uint256 stakeAmount) public view returns(uint256) {

        uint256 stakeStartDate = block.timestamp;
        uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

        if (stakeEndDate <= stakeStartDate) {
            return 0; 
        }

        uint256 totalStakeSeconds = getStakingDurationInSeconds(stakeStartDate, stakeEndDate);

        uint256 perSecondInterest = calculatePerSecondInterest(stakeAmount, _stakePool[_stakePoolId].apy);

        uint256 totalInterestReward = perSecondInterest * totalStakeSeconds;

        return totalInterestReward;
    }

    function calculateCustomizeableStakeReward(uint256 _stakeAmount, uint256 _startDate, uint256 _endDate, uint256 _apyRate) public pure returns(uint256) {

        uint256 stakeStartDate = _startDate;
        uint256 stakeEndDate = _endDate;

        uint256 totalStakeSeconds = getStakingDurationInSeconds(stakeStartDate, stakeEndDate);

        uint256 perSecondInterest = calculatePerSecondInterest(_stakeAmount, _apyRate);

        uint256 totalInterestReward = perSecondInterest * totalStakeSeconds;

        return totalInterestReward;
    }

    //total number of the users that has staked
    function getCountOfUsers() public view returns(uint256) {
        return _totalUsers;
    }


    function checkIsPoolExists(string memory _stakePoolId) public view returns(bool) {
        return bytes(_stakePool[_stakePoolId].stakePoolId).length != 0;
    }

    function generateId() private returns (uint256) {
           idCounter++;
            return idCounter;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner();
    }

    function getTokenAddress() public view returns (address) {
        return address(_token);
    }

    function listAllStakesInPool(string memory stakePoolId) public view returns (Stakes[] memory) {
        return _stakesInPool[stakePoolId];
    }

    function lengthStakesInPool(string memory stakePoolId) public view returns (uint) {
        return _stakesInPool[stakePoolId].length;
    }
       
    function updateStakePool(
        string memory stakePoolId,
        string memory newName,
        uint newStartDate,
        uint newEndDate,
        uint newApy,
        uint256 newMinStakingAmount,
        uint256 newMaxStakingLimit
    ) public onlyOwner {
        require(bytes(_stakePool[stakePoolId].stakePoolId).length != 0, "Stake pool not found");


        require(newApy <= 10000, "APY rate should be less than 10000");
        require(newStartDate < newEndDate, "Start date cannot be greater than the end date");

        // Update the pool
        _stakePool[stakePoolId].name = newName;
        _stakePool[stakePoolId].startDate = newStartDate;
        _stakePool[stakePoolId].endDate = newEndDate;
        _stakePool[stakePoolId].apy = newApy;
        _stakePool[stakePoolId].minStakingAmount = newMinStakingAmount;
        _stakePool[stakePoolId].maxStakingLimit = newMaxStakingLimit;

        emit StakePoolUpdated(
            stakePoolId,
            newName,
            newStartDate,
            newEndDate,
            newApy,
            newMinStakingAmount,
            newMaxStakingLimit
        );
    }

    function getVersion()public view returns(string memory){
        return version;
    }

    function withdraw(address account, uint256 _amount) public onlyOwner nonReentrant {

        _token.approve(address(this), _amount);
        _token.transferFrom(address(this), account, _amount);
    }
    
}