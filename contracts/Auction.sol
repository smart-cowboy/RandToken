pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IRand.sol";
import "./interfaces/IPriceFeed.sol";

contract Auction is Ownable{
    using SafeMath for uint256;

    address public oracleAddress;
    address public lockAddress;
    address public randAddress;
    address public potAddress;
    address public walletAddress;

    enum RefundType{ ETH, RAND }
    uint32 constant DAY = 1 days;

    struct User {
        address userAddress;
        uint256 signupTime;
        RefundType refundType;
        uint256 bidAmount;
        bool isWinner;
        bool isRefunded;
    }

    struct Auction {
        string auctionName;
        uint256 amount;
        uint256 auctionEnd;
        User[] userList;
    }

    Auction[] public auctions;

    constructor(address _owner, address _oracleAddress, address _lockAddress, address _randAddress, address _potAddress, _walletAddress) public Owned(_owner) {
        oracleAddress = _oracleAddress;
        lockAddress = _lockAddress;
        randAddress = _randAddress;
        potAddress = _potAddress;
        walletAddress = _walletAddress;
    }

    function rand() internal view returns(uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(
        block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)) + block.number)));

        return (seed - ((seed / 100) * 100));
    }

    function startAuction(string memory _auctionName) public onlyOwner{
        uint256 memory auctionAmount = rand();
        User[] memory users;
        IRand memory randPool = IRand(randAddress);
        
        randPool.mint(potAddress, auctionAmount);
        auctions.push(Auction(_auctionName, auctionAmount, 0, users));
        emit AuctionStarted(_auctionName, auctionAmount);
    }

    function signUp(address _userAddress, RefundType _refundType) public payable{
        uint256 memory lastAuctionIndex = auctions.length - 1;
        require(auction[lastAuctionIndex].userList.length <= 1000, "User limit exceed");
        
        auction[lastAuctionIndex].push(User(_userAddress, block.timestamp, _refundType, msg.value, false, false));
        emit UserSignedUp(_userAddress, block.timestamp, _refundType, msg.value);
    }

    function selectWinner() public onlyOwner {
        uint256 memory lastAuctionIndex = auctions.length - 1;
        uint16 memory winnerIndex = 1001;
        uint16 memory i;
        uint256 memory max = 0;
        Auction lastAuction = auctions[lastAuctionIndex];
        IRand memory randPool = IRand(randAddress);
        
        for (i = 0; i <= lastAuction.userList.length; i ++) {
            if (lastAuction.userList[i].bidAmount > max) {
                max = lastAuction.userList[i].bidAmount;
                winnerIndex = i;
            }
        }

        require (winnerIndex != 1001, "No winner!");
        lastAuction.userList[winnerIndex].isWinner = true;

        require (randPool.balanceOf(potAddress) >= lastAuction.amount, "Not enough auction");

        randPool.transferFrom(potAddress, lockAddress, lastAuction.amount);
        lastAuction.auctionEnd = block.timestamp;
        emit WinnerSelected(lastAuctionIndex, lastAuction.userList[winnerIndex].userAddress, block.timestamp);
    }

    function withdraw(uint256 _auctionIndex, uint256 _amount) public {
        Auction auction = auctions[_auctionIndex];
        
        require (auction.auctionEnd.add(DAY * 30) <= block.timestamp, "Can not withdraw before 30 days after from you win");

        address memory userIndex;
        for (userIndex = 0; userIndex <= auction.userList.length; userIndex ++) {
            if (auction.userList[userIndex].userAddress == msg.sender)
                break;
        }

        require (auction.userList[userIndex].isWinner == true, "You are not winner");
        require (auction.amount > _amount, "Insufficient amount");
        IRand memory randPool = IRand(randAddress);
        randPool.transferFrom(lockAddress, msg.sender, _amount);
        auction.amount = auction.amount.sub(_amount);
        emit Withdraw(_auctionIndex, msg.sender, _amount);
    }

    function refund(uint256 _auctionIndex) public payable {
        Auction memory auction = auctions[_auctionIndex];

        address memory userIndex;
        for (userIndex = 0; userIndex <= auction.userList.length; userIndex ++) {
            if (auction.userList[userIndex].userAddress == msg.sender)
                break;
        }

        require (auction.userList[userIndex].isWinner == false, "You are the winner");
        require (auction.userList[userIndex].signupTime.add(DAY * 30) <= block.timestamp, "Can not refund before 30 days after from you win");
        require (auction.userList[userIndex].isRefunded == false, "You are already refunded.");
        address payable userAddress = payable(msg.sender);

        if (auction.userList[userIndex].refundType == RefundType.ETH) {
            require(userAddress.send(auction.userList[userIndex].bidAmount), "Refund failed");
        } else if (auction.userList[userIndex].refundType == RefundType.RAND) {
            IPriceFeed priceFeed = IPriceFeed(oracleAddress);
            uint256 price = priceFeed.price();
            uint256 randAmount = auction.userList[userIndex].bidAmount / price;
            IRand memory randPool = IRand(randAddress);
            randPool.mint(msg.sender, randAmount);
        }
        auction.userList[userIndex].isRefunded = true;

        emit Refunded(_auctionIndex, msg.sender, auction.userList[userIndex].bidAmount);
    }

    function getLockedAmount() public view onlyOwner returns (uint256){
        IRand memory randPool = IRand(randAddress);
        return randPool.balanceOf(lockAddress);
    }

    function cutLockedToken() public onlyOwner{
        IRand memory randPool = IRand(randAddress);
        uint256 cutAmount = randPool.balanceOf(lockAddress).div(10);
        randPool.transferFrom(lockAddress, walletAddress, cutAmount);

        uint256 index;
        for (index = 0; i < auctions.length; index ++) {
            auctions[index].amount = auctions[index].amount.div(10);
        }
        emit Cutted(cutAmount);
    }

    event AuctionStarted(auctionName, auctionAmount);
    event UserSignedUp(address userAddress, uint256 timestamp, RefundType refundType, uint256 bidAmount);
    event WinnerSelected(uint256 auctionIndex, address userAddress, uint256 timestamp);
    event Withdraw(uint256 auctionIndex, address userAddress, uint256 amount);
    event Refunded(uint256 auctionIndex, address userAddress, uint256 amount);
    event Cutted(uint256 cutAmount);
}