// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CFT.sol";

contract CFTTest is Test {
    CFT private cft;
    ERC20Mock private erc20;
    address private owner;
    address private user;
    uint256 private vmId;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        // Deploy a mock ERC20 token and CFT contract
        erc20 = new ERC20Mock("CFT", "CFT");
        cft = new CFT(address(erc20));

        // Set initial balances
        erc20.setBalance(owner, 1000 ether);
        erc20.setBalance(user, 1000 ether);

        // Create a virtual machine
        vmId = cft.createVirtualMachine();
    }

    function testCreateVirtualMachine() public {
        uint256 newVmId = cft.createVirtualMachine();
        (address vmOwner,,,) = cft.virtualMachines(newVmId);
        assertEq(vmOwner, address(this), "Owner should be set correctly for new VM");
    }

    function testStartVirtualMachine() public {
        // Deposit tokens to get minute credits
        erc20.approve(address(cft), 100 ether);
        cft.depositTokens(100 ether);

        // Start the virtual machine
        vm.prank(owner);
        cft.startVirtualMachine(vmId);

        (,,bool isRunning,) = cft.virtualMachines(vmId);
        assertTrue(isRunning, "VM should be running after start");
    }

    function testStopVirtualMachine() public {
        // Deposit tokens to get minute credits
        erc20.approve(address(cft), 100 ether);
        cft.depositTokens(100 ether);

        // Start and then stop the virtual machine
        vm.prank(owner);
        cft.startVirtualMachine(vmId);
        vm.warp(block.timestamp + 120); // Simulate 2 minutes of running
        cft.stopVirtualMachine(vmId);

        (,,bool isRunning,) = cft.virtualMachines(vmId);
        assertFalse(isRunning, "VM should not be running after stop");
    }

    function testDepositTokens() public {
        uint256 amount = 100 ether;
        erc20.approve(address(cft), amount);
        cft.depositTokens(amount);

        uint256 credits = cft.userMinuteCredits(address(this));
        assertEq(credits, amount, "Credits should equal the deposited amount");
    }

    function testGetTotalMinutesConsumed() public {
        // Deposit tokens to get minute credits
        erc20.approve(address(cft), 100 ether);
        cft.depositTokens(100 ether);

        // Start the virtual machine
        vm.prank(owner);
        cft.startVirtualMachine(vmId);
        vm.warp(block.timestamp + 120); // Simulate 2 minutes of running

        uint256 consumed = cft.getTotalMinutesConsumed(vmId);
        assertEq(consumed, 2 ether, "Total minutes consumed should be 2 minutes");
    }

    function testFailStartVirtualMachineWithoutCredits() public {
        // Attempt to start the virtual machine without depositing tokens
        vm.prank(owner);
        cft.startVirtualMachine(vmId);
    }

    function testFailStopVirtualMachineNotRunning() public {
        // Attempt to stop the virtual machine that is not running
        vm.prank(owner);
        cft.stopVirtualMachine(vmId);
    }
}

// Mock ERC20 token for testing purposes
contract ERC20Mock is ERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public allowances;

    function transferFrom(address _from, address _to, uint256 _value) external override returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowances[_from][msg.sender] >= _value, "Insufficient allowance");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        return true;
    }

    function transfer(address _to, uint256 _value) external override returns (bool success) {
        address _from = msg.sender;
        require(balanceOf[_from] >= _value, "Insufficient balance");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowances[msg.sender][_spender] = _value;
        return true;
    }

    function setBalance(address _owner, uint256 _balance) public {
        balanceOf[_owner] = _balance;
    }
}