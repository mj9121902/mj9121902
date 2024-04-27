// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) isConfirmed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;

    event Deposit(address indexed sender, uint256 value, uint256 indexed txIndex);
    event Submission(uint256 indexed txIndex);
    event Confirmation(address indexed sender, uint256 indexed txIndex);
    event Execution(uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier transactionExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "Invalid number of confirmations"
        );
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function deposit() public payable {
        emit Deposit(msg.sender, msg.value, transactions.length);
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyOwner
    {
        uint256 txIndex = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));
        emit Submission(txIndex);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        transactionExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        transactions[_txIndex].isConfirmed[msg.sender] = true;
        transactions[_txIndex].numConfirmations++;
        emit Confirmation(msg.sender, _txIndex);
        if (transactions[_txIndex].numConfirmations >= numConfirmationsRequired) {
            executeTransaction(_txIndex);
        }
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        transactionExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(
            transactions[_txIndex].numConfirmations >= numConfirmationsRequired,
            "Not enough confirmations"
        );
        Transaction storage txn = transactions[_txIndex];
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        emit Execution(_txIndex);
    }
}
