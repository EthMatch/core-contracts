//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Game {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

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

    function createNewAccount(uint256 _initialDeposit) external onlyERC20 {
        require(!accounts[msg.sender], "Player already exists!");

        accounts[msg.sender] = true;
        if (_initialDeposit > 0) {
            _takeDeposits(msg.sender, _initialDeposit);
        }
    }

    function depositBalances(uint256 _amountIn) external onlyERC20 {
        require(accounts[msg.sender], "Player does not exist!");
        _takeDeposits(msg.sender, _amountIn);
    }

    function _takeDeposits(address _depositor, uint256 _amountIn) internal {
        require(_amountIn > 0, "Invalid deposit amount");

        wantToken.safeTransferFrom(_depositor, address(this), _amountIn);
        accountBalances[_depositor] += _amountIn;
    }

    modifier onlyEth() {
        require(isEthGame, "You cannot deposit IERC20 tokens");
        _;
    }

    modifier onlyERC20() {
        require(!isEthGame, "You cannot deposit ETH");
        _;
    }
}
