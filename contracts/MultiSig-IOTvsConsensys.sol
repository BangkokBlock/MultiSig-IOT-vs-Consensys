//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

contract MultiSigIOTvsConsensys {

    address[] public owners;
    uint public required;

    //Consensys did not have an array but rather 2 mappings ("isOwner" & "transactions") and a double mapping called "confirmations" which we also have.
    //In the consensys multisig, the "transactions" mapping was a Struct Mapping.
    //Remember arrays are more storage and more expensive than mappings so Consensys mapping is cheaper in that sense.
    Transaction[] transactions;

    mapping (uint => mapping (address => bool)) public confirmations;

    //Consensys did not have a "uint approvals" or "uint id", it had a "bytes data". Instead of the uint id it returned a transactionId in functions
    //Consensys did not have "approvals" in the struct and instead just did a for loop against global variable "required". In one sense Consensys is more
    //streamlined but it also doesn't allow you to check the number of approvals at any given time for a particular Transfer/Transaction (struct).
    struct Transaction {
        address payable destination;
        uint value;
        bool executed;
        uint approvals;
        uint id;
    }

    event Submission (uint _id, uint _value, address _initiator, address _destination);
    event ApprovalReceived (uint _id, uint _approvals, address _approver);
    event TransactionApproved (uint _id);

    //Consensys had 2 other features here. (1)a modifier called validRequirements that ensures the required is not > than the owners.length
    //(2)C had a for loop in constructor that loops against owners.length and then sets the "isOwner" mapping to true..."isOwner[_owners[i]] = true";
    constructor (address[] memory _owners, uint _required) {
        owners = _owners;
        required = _required;
    }

    //Consensys had the "validRequirement" modifier instead of the onlyOwners modifier.
    modifier onlyOwners() {
        bool owner = false;
        for (uint i=0; i<owners.length; i++) {
            if(owners[i] == msg.sender) {
                owner = true;
            }
        }
        require(owner == true);
        _;
    }

    function deposit() public payable {}

    //Consensys not using an array, only mapping. There addTransaction...Transactions[transactionId] = Transaction({ then assigns struct properties
    //C also returns the "transactionId" in header and assigns it to global var "transaction count". We don't do that here, we have "id" in our Struct already.
    function addTransaction (address payable _destination, uint _value) public onlyOwners {
        Transaction memory newTransaction = Transaction(_destination, _value, false, 0, transactions.length);
        transactions.push(newTransaction);
        emit Submission (transactions.length, _value, msg.sender, _destination);
    }

    //After addTransaction, C had submitTransaction, confirmTransaction, & executeTransaction. This is more streamlined but lacks the same flexibility/security.
    //C used address.call. Here we use address.transfer to send the funds. Consensys- (bool success,) = t.destination.call{value: t.value}(t.data);
    //C also flips the double mapping "confirmations" to true but it doesn't have to add the ++ to the struct "approvals" cause it doesn't have one.
    function approvals (uint _id) public onlyOwners {
        require(confirmations[_id][msg.sender] == false);
        require(transactions[_id].executed == false);
        confirmations[_id][msg.sender] = true;
        transactions[_id].approvals++;

        emit ApprovalReceived (_id, transactions[_id].approvals, msg.sender);

        if (transactions[_id].approvals >= required) {
            transactions[_id].executed = true;
            transactions[_id].destination.transfer(transactions[_id].value);
            emit TransactionApproved(_id);
        }
    }

    function getTransactionRequests() public view returns (Transaction[] memory) {
        return transactions;
    }
}
