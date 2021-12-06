//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Game {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    event LobbyGenerated(
        uint256 pool,
        address operator,
        uint256 operatorsShare,
        address[] registeredPlayers
    );
    address public governance;
    struct lobby {
        uint256 pool;
        address operator;
        bool isValue;
        uint256 operatorsShare;
        address[] registeredPlayers;
    }

    mapping(string => mapping(address => uint256)) players;
    mapping(string => mapping(address => uint256)) playerSignatures;
    struct ticket {
        address player;
        uint256 amount;
        bytes signature;
    }
    string public gameTitle;
    uint256 currentSeason;
    uint256 public minPlayers;
    uint256 public maxPlayers;
    IERC20 public wantToken;
    bool public isEthGame;
    mapping(address => bool) public operators;
    mapping(address => uint256) public operatorBalances;
    mapping(address => bool) public accounts;
    mapping(address => uint256) public accountBalances;
    mapping(string => mapping(uint256 => mapping(address => uint256)))
        public accountRanks;
    mapping(string => lobby) public lobbies;

    constructor(address _wantToken) {
        if (_wantToken != address(0x0)) {
            wantToken = IERC20(_wantToken);
        } else {
            isEthGame = true;
        }

        governance = msg.sender;
    }

    function newSeason() external onlyGovernance {
        currentSeason += 1;
    }

    function createNewAccount() external payable onlyEth {
        require(!accounts[msg.sender], "Player already exists!");

        accounts[msg.sender] = true;
        accountBalances[msg.sender] += msg.value;
    }

    function depositBalances() external payable onlyEth {
        require(accounts[msg.sender], "Player does not exist!");
        require(msg.value > 0, "Invalid deposit amount");

        accountBalances[msg.sender] += msg.value;
    }

    function getBalance() public view virtual returns (uint256) {
        require(accounts[msg.sender], "Player does not exist!");
        return accountBalances[msg.sender];
    }

    function createNewAccount(uint256 _initialDeposit) external onlyERC20 {
        require(!accounts[msg.sender], "Player already exists!");

        accounts[msg.sender] = true;
        if (_initialDeposit > 0) {
            _takeDeposits(msg.sender, _initialDeposit);
        }
    }

    function createLobby(
        ticket[] memory tickets,
        string memory lobbyId,
        uint256 operatorsShare
    ) external returns (bool) {
        require(!lobbies[lobbyId].isValue, "lobby aready exists");
        lobbies[lobbyId] = lobby({
            pool: 0,
            operator: address(0),
            isValue: true,
            operatorsShare: 0,
            registeredPlayers: new address[](tickets.length)
        });
        for (uint256 i = 0; i < tickets.length; i++) {
            ticket memory _ticket = tickets[i];
            bool transferred = _transaferBalanceToLobby(
                _ticket.player,
                _ticket.amount,
                lobbyId
            );
            require(transferred, "failed to transfer amount");
            players[lobbyId][_ticket.player] = _ticket.amount;
            lobbies[lobbyId].pool += _ticket.amount;
            lobbies[lobbyId].registeredPlayers[i] = _ticket.player;
        }
        lobbies[lobbyId].operator = msg.sender;
        lobbies[lobbyId].operatorsShare = operatorsShare;
        emit LobbyGenerated(
            lobbies[lobbyId].pool,
            lobbies[lobbyId].operator,
            lobbies[lobbyId].operatorsShare,
            lobbies[lobbyId].registeredPlayers
        );
        return true;
    }

    function _transaferBalanceToLobby(
        address account,
        uint256 amount,
        string memory lobbyId
    ) internal returns (bool) {
        require(accounts[account], "Player does not exist!");
        require(accountBalances[account] >= amount, "insufficient Balance");
        require(lobbies[lobbyId].isValue, "lobby does not exists");
        accountBalances[account] -= amount;
        return true;
    }

    function getLobby(string memory id)
        public
        view
        returns (
            string memory _lobbyId,
            address[] memory _players,
            uint256 pool,
            address operator
        )
    {
        require(lobbies[id].isValue, "lobby does not exist ");
        return (
            id,
            lobbies[id].registeredPlayers,
            lobbies[id].pool,
            lobbies[id].operator
        );
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

    function transferGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    function destroyGovernance() external onlyGovernance {
        governance = address(0x0);
    }

    modifier onlyEth() {
        require(isEthGame, "You cannot deposit IERC20 tokens");
        _;
    }
    modifier onlyERC20() {
        require(!isEthGame, "You cannot deposit ETH");
        _;
    }
    modifier onlyOperator() {
        require(operators[msg.sender], "Operator not found");
        _;
    }
    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance can call");
        _;
    }
}
