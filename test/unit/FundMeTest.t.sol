// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {Deploy} from "../../script/Deploy.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        // @note tekrar tekrar uğraşmamak için deploydaki kodu burada da aynı şekilde deploy ettik
        Deploy deployFundMe = new Deploy();
        fundMe = deployFundMe.run();
        vm.deal(USER, 20e18); // @note USER' a 20 ether atadık testlerde para gönderebilmesi için. Bu herhangi bir miktar olabilir
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // @note FundMe kontratını deploy eden Test kontratı olduğu için owner, Test kontratı olur
        console.log(fundMe.i_owner());
        console.log(msg.sender);
        console.log(address(this));
        // assertEq(fundMe.i_owner(), address(this));
        assertEq(fundMe.i_owner(), msg.sender);
    }

    // Forked testing
    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    // @note This test expected to revert
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // @note The next TX will be sent by USER
        fundMe.fund{value: 1e18}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, 1e18);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        // @note state tutulmadığı için her testte kontratın state' i yeniden başlar
        fundMe.fund{value: 1e18}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: 1e18}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;
        assertEq(endingContractBalance, 0);
        assertEq(
            startingOwnerBalance + startingContractBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // @note buradaki sayı ile yeni adres üretiyoruz address(0) gibi ve ona miktar ataması yapıyoruz
            hoax(address(i), 5e18);
            fundMe.fund{value: 1e18}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingOwnerBalance + startingContractBalance ==
                fundMe.getOwner().balance
        );
    }
}
