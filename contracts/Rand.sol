pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DappToken is ERC20 {
    constructor() public ERC20("RAND Token", "RAND") {
    }

    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}