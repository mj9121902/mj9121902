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
    }

    mapping(bytes32 => Transaction) public transactions;

    event Deposit(address indexed sender, uint256 value, bytes32 indexed txHash);
    event Submission(bytes32 indexed txHash);
    event Confirmation(address indexed sender, bytes32 indexed txHash);
    event Execution(bytes32 indexed txHash);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier transactionExists(bytes32 _txHash) {
        require(transactions[_txHash].to != address(0), "Transaction does not exist");
        _;
    }

    modifier notExecuted(bytes32 _txHash) {
        require(!transactions[_txHash].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(bytes32 _txHash) {
        require(!transactions[_txHash].isConfirmed[msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of confirmations");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, bytes32(0));
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyOwner
    {
        bytes32 txHash = keccak256(abi.encodePacked(_to, _value, _data, block.timestamp));
        transactions[txHash] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        });
        emit Submission(txHash);
    }

    function confirmTransaction(bytes32 _txHash)
        public
        onlyOwner
        transactionExists(_txHash)
        notExecuted(_txHash)
        notConfirmed(_txHash)
    {
        transactions[_txHash].isConfirmed[msg.sender] = true;
        emit Confirmation(msg.sender, _txHash);
        if (getConfirmationCount(_txHash) >= numConfirmationsRequired) {
            executeTransaction(_txHash);
        }
    }

    function executeTransaction(bytes32 _txHash)
        public
        onlyOwner
        transactionExists(_txHash)
        notExecuted(_txHash)
    {
        require(getConfirmationCount(_txHash) >= numConfirmationsRequired, "Not enough confirmations");
        Transaction storage txn = transactions[_txHash];
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");
        emit Execution(_txHash);
    }

    function getConfirmationCount(bytes32 _txHash) public view returns (uint256 count) {
        Transaction storage txn = transactions[_txHash];
        for (uint256 i = 0; i < owners.length; i++) {
            if (txn.isConfirmed[owners[i]]) {
                count++;
            }
        }
    }
}
