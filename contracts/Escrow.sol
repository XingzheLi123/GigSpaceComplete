// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./Counters.sol";

contract Escrow {
    
    struct Contract {
        address payable employer;
        address payable employee;
        uint256 salary;
        uint256 employer_lock;
        uint256 employee_lock;
        uint256 status; //0 for requested; 1 for pending; 2 for completed or deleted;
        bool employee_breakup;
        bool employer_breakup;
        //uint256 offerTime; //timelock
    }
    mapping(uint256 => Contract) _contracts;
    mapping(address => uint256[]) _employers;
    mapping(address => uint256[]) _employees;

    using Counters for Counters.Counter;
    Counters.Counter public _contractIDs;

    event Requested(uint256 contractID);
    event Canceled();
    event StateChange(uint256 new_state);
    event Approve();
    event BreakUpEvent(bool requested); //true => requested; false => approved

    constructor() {
        
    }

    function extendOffer(address payable employer, address payable employee, uint256 salary, uint256 employer_lock, uint256 employee_lock) public payable{
        require(msg.value == salary + employer_lock, "wrong amount of money");
        uint256 current = _contractIDs.current();
        _contracts[current] = Contract(employer, employee, salary, employer_lock, employee_lock, 0, false, false);
        _employers[employer].push(current);
        _employees[employee].push(current);
        emit Requested(current);
    }

    function rescindOffer(uint256 contractID) public payable{
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        require(msg.sender == thisContract.employer, "not your project");
        require(thisContract.status == 0, "too late");
        _contracts[contractID].status = 2;

        if(thisContract.status != 0){
            thisContract.employee.transfer(thisContract.employee_lock);
        }
        thisContract.employer.transfer(thisContract.salary);
        emit Canceled();
    }

    function acceptOffer(uint256 contractID) public payable{
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        require(msg.value == thisContract.employee_lock, "wrong amount of money");
        require(msg.sender == thisContract.employee, "not your project");
        require(thisContract.status == 0, "already accepted");
        _contracts[contractID].status = 1;
        emit StateChange(1);
    }
    function breakOffer(uint256 contractID) public payable{
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        require(msg.sender == thisContract.employee, "not your project");
        _contracts[contractID].status = 2;
        thisContract.employer.transfer(thisContract.employer_lock + thisContract.salary);
        emit Canceled();
    }

    // function submit(uint256 contractID) public{
    //     Contract memory thisContract = _contracts[contractID];
    //     require(thisContract.employer_lock != 0, "Invalid Contract");
    //     require(msg.sender == thisContract.employee, "not your project");
    //     require(thisContract.status == 1, 'cannot submit, already submitted or not yet accepted');
    //     _contracts[contractID].status = 2;
    //     emit StateChange(2);
    // }

    function approve(uint256 contractID) public payable{
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        require(msg.sender == thisContract.employer, "not your project");
        thisContract.employee.transfer(thisContract.employee_lock + thisContract.salary);
        thisContract.employer.transfer(thisContract.employer_lock);
        _contracts[contractID].status = 2;
        emit Approve();
    }
    // function disapprove(uint256 contractID) public payable{
    //     Contract memory thisContract = _contracts[contractID];
    //     require(thisContract.employer_lock != 0, "Invalid Contract");
    //     require(msg.sender == thisContract.employer, "not your project");
    //     require(thisContract.status == 2, "not ready yet");
    //     _contracts[contractID].status = 1;
    //     emit Approval(false);
    // }
    function BreakUp(uint256 contractID, bool employee) public{
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        if (employee){
            require(msg.sender == thisContract.employee, "not your project");
            _contracts[contractID].employee_breakup = true;
        }
        else{
            require(msg.sender == thisContract.employer, "not your project");
            _contracts[contractID].employer_breakup = true;
        }
        if(_contracts[contractID].employer_breakup && _contracts[contractID].employee_breakup){
            thisContract.employer.transfer(thisContract.salary + thisContract.employer_lock);
            thisContract.employee.transfer(thisContract.employee_lock);
            emit BreakUpEvent(false);
        }
        else{
            emit BreakUpEvent(true);
        }
    }

    function contractDetails(uint256 contractID) public view returns(Contract memory){
        Contract memory thisContract = _contracts[contractID];
        require(thisContract.employer_lock != 0, "Invalid Contract");
        require(msg.sender == thisContract.employer || msg.sender == thisContract.employee, "not your project");
        return thisContract;
    }

    function currentContract(bool employer) public view returns(Contract[] memory){
        uint256[] memory contract_indices = _employees[msg.sender];
        if (employer){
            contract_indices = _employers[msg.sender];
        }
        Contract[] memory contracts = new Contract[](contract_indices.length);
        for (uint256 i = 0; i < contract_indices.length; i++){
            contracts[i] = _contracts[contract_indices[i]];
        }
        return contracts;
    }
}
