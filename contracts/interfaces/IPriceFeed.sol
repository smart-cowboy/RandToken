pragma solidity ^0.6.0; 

contract IPriceFeed {
    function price() external pure returns (uint256);
}