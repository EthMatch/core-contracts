//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract Game is EIP712 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    event LobbyGenerated(string id);
    event LobbyResult(string id);
    bytes32 private _PROPOSAL_HASH;
    address public governance;
    struct lobby {
        uint256 pool;
        address operator;
        uint256 createdAt;
        uint256 expireAt;
        bool isValue;
        uint256 operatorsShare;
        address[] registeredPlayers;
        string gameData;
        bool isCompleted;
        bool operatorRedeemed;
    }
    struct sigReq {
        address player;
        uint256 winningAmount;
        bytes initalState;
        string finalState;
    }
    struct resultType {
        string finalState;
        uint256 winnigAmount;
        bool redeemed;
    }
    mapping(string => mapping(uint256 => uint256)) public winnigAmount;
    mapping(string => mapping(address => resultType)) private results;
    mapping(string => mapping(address => uint256)) public players;
    struct ticket {
        string id;
        address player;
        uint256 amount;
        bytes signature;
    }
    string public gameTitle;
    uint256 public currentSeason;
    uint256 public minPlayers;
    uint256 public maxPlayers;
    IERC20 public wantToken;
    bool public isEthGame;
    mapping(address => bool) public operators;
    mapping(address => uint256) public operatorBalances;
    mapping(address => bool) public accounts;
    mapping(address => uint256) public accountBalances;
    mapping(string => lobby) public lobbies;

    constructor(
        address _wantToken,
        string memory _gameTitle,
        string memory _version,
        uint256 _maxPlayers,
        uint256 _minPlayers
    ) EIP712(_gameTitle, _version) {
        if (_wantToken != address(0x0)) {
            wantToken = IERC20(_wantToken);
        } else {
            isEthGame = true;
        }
        gameTitle = _gameTitle;
        governance = msg.sender;
        maxPlayers = _maxPlayers;
        minPlayers = _minPlayers;
        operators[msg.sender] = true;
        operatorBalances[msg.sender] = 0;
        _PROPOSAL_HASH = keccak256(
            "Proposal(string id,string ticket_id,uint256 entry_fee,uint256 operators_share,address operators_address)"
        );
    }

    function _verifyTicket(
        address player,
        bytes memory signature,
        string memory lobbyId,
        string memory ticketId,
        uint256 entryFee,
        uint256 operatorsShare,
        address operatorsAddress
    ) internal view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _PROPOSAL_HASH,
                    keccak256(bytes(lobbyId)),
                    keccak256(bytes(ticketId)),
                    entryFee,
                    operatorsShare,
                    operatorsAddress
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return signer == player;
    }

    function addOperator(address operator) external onlyGovernance {
        require(operators[operator], "Operator already exists!");
        operators[operator] = true;
        operatorBalances[operator] = 0;
    }

    function getOperatorsBalance() external onlyOperator returns (uint256) {
        return operatorBalances[msg.sender] = 0;
    }

    function _verifyJoiningKey(
        address player,
        bytes memory signature,
        string memory lobbyId
    ) internal view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("Key(string id)"),
                    keccak256(bytes(lobbyId))
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return signer == player;
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

    function withdrawBalance() external {
        require(accounts[msg.sender], "Player does not exist!");
        _withdraw(msg.sender);
    }

    function createLobby(
        ticket[] memory tickets,
        string memory lobbyId,
        uint256 operatorsShare,
        uint256 lobbyTimeout
    ) external returns (bool) {
        require(!lobbies[lobbyId].isValue, "lobby aready exists");
        require(
            minPlayers <= tickets.length && tickets.length <= maxPlayers,
            "invalid length"
        );
        lobbies[lobbyId] = lobby({
            pool: 0,
            operator: address(0x0),
            isValue: true,
            operatorsShare: 0,
            registeredPlayers: new address[](tickets.length),
            createdAt: block.timestamp,
            expireAt: block.timestamp + (lobbyTimeout * 1 seconds),
            gameData: "",
            isCompleted: false,
            operatorRedeemed: false
        });
        for (uint256 i = 0; i < tickets.length; i++) {
            ticket memory _ticket = tickets[i];
            require(
                _verifyTicket(
                    _ticket.player,
                    _ticket.signature,
                    lobbyId,
                    _ticket.id,
                    _ticket.amount,
                    operatorsShare,
                    msg.sender
                ),
                "failed to verify ticket signature"
            );
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
        emit LobbyGenerated(lobbyId);
        return true;
    }

    function submitResults(
        sigReq[] memory requests,
        string memory lobbyId,
        string memory gameData
    ) external onlyOperator {
        require(lobbies[lobbyId].isValue, "lobby does not exist");
        require(
            lobbies[lobbyId].operator == msg.sender,
            "Operator does not own lobby"
        );
        for (uint256 i = 0; i < requests.length; i++) {
            sigReq memory _request = requests[i];
            require(
                _verifyJoiningKey(
                    _request.player,
                    _request.initalState,
                    lobbyId
                ),
                "Invalid joining Key"
            );
            results[lobbyId][_request.player] = resultType({
                finalState: _request.finalState,
                winnigAmount: _request.winningAmount,
                redeemed: false
            });
        }
        lobbies[lobbyId].gameData = gameData;
        lobbies[lobbyId].isCompleted = true;
        _transferOperatorsShare(msg.sender, lobbyId);
        emit LobbyResult(lobbyId);
    }

    function redeemWinnings(string memory lobbyId) external returns (bool) {
        require(lobbies[lobbyId].isValue, "lobby does not exist");
        require(lobbies[lobbyId].isCompleted, "result not declared yet");
        require(
            _transferWinnings(msg.sender, lobbyId),
            "Failed to redeem winnings"
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

    function _transferWinnings(address account, string memory lobbyId)
        internal
        returns (bool)
    {
        require(
            results[lobbyId][msg.sender].winnigAmount != 0,
            "no value found for result"
        );
        require(
            !results[lobbyId][msg.sender].redeemed,
            "already redeemed amount"
        );
        accountBalances[account] += lobbies[lobbyId].pool;
        results[lobbyId][msg.sender].redeemed = true;
        return true;
    }

    function _transferOperatorsShare(address op, string memory lobbyId)
        internal
        returns (bool)
    {
        require(operators[op], "Operator not found");
        require(lobbies[lobbyId].isValue, "lobby does not exists");
        lobbies[lobbyId].pool -= lobbies[lobbyId].operatorsShare;
        operatorBalances[op] += lobbies[lobbyId].operatorsShare;
        lobbies[lobbyId].operatorRedeemed = true;
        return true;
    }

    function getLobbyPlayers(string memory id)
        public
        view
        returns (address[] memory _players)
    {
        require(lobbies[id].isValue, "lobby does not exist ");
        return (lobbies[id].registeredPlayers);
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

    function _withdraw(address player) internal {
        require(accountBalances[player] > 0, "Insufficent amount to withdraw");
        uint256 transferAmount = accountBalances[player];
        accountBalances[player] = 0;
        payable(player).transfer(transferAmount);
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
