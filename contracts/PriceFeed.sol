pragma solidity ^0.6.0;

contract PriceFeed {
    function price() external pure returns (uint256) {
        return 50;
    }
}