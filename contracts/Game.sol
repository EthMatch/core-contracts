//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game {
    IERC20 public wantToken;
    bool public isEthGame;

    mapping(address => bool) public accounts;
    mapping(address => uint256) public accountBalances;
    mapping(string => mapping(uint256 => mapping(address => uint256)))
        public accountRanks;
    mapping(string => address) public lobbies;

    constructor(address _wantToken) {
        if (_wantToken != address(0x0)) {
            wantToken = IERC20(_wantToken);
        } else {
            isEthGame = true;
        }
    }
}
