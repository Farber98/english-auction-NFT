// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MyNFT.sol";
import "../src/EnglishAuction.sol";

contract EnglishAuctionTest is Test {
    MyNFT nft;
    EnglishAuction auction;
    address seller = address(0x1);
    address buyer2 = address(0x2);
    address buyer3 = address(0x3);
    uint256 nftId = 77;

    function setUp() public {
        vm.startPrank(seller);
        nft = new MyNFT();
        auction = new EnglishAuction(address(nft), nftId, 1 ether);
        nft.mint(seller, nftId);
        assertEq(nft.ownerOf(nftId), seller);
        assertEq(nft.balanceOf(seller), 1);
        nft.approve(address(auction), nftId);
        assertEq(nft.getApproved(77), address(auction));
        vm.stopPrank();
    }

    function testStartNotSeller() public {
        vm.expectRevert("Not seller");
        auction.start();
    }

    function testStartOk() public {
        vm.startPrank(seller);
        assertEq(auction.started(), false);
        auction.start();
        assertEq(nft.ownerOf(nftId), address(auction));
        assertEq(auction.started(), true);
        assertEq(auction.endAt(), block.timestamp + 60 seconds);
        vm.stopPrank();
    }

    function testBidNotStarted() public {
        vm.expectRevert("Not started.");
        auction.bid();
    }

    function testBidThresholdNotSurpassed() public {
        testStartOk();
        vm.expectRevert("previous bid not surpassed.");
        auction.bid();
    }

    function testBidEndedBlockTimestampPassed() public {
        testStartOk();
        vm.warp(block.timestamp + 70 seconds);
        auction.end();
        assertEq(auction.ended(), true);
        vm.expectRevert("Already ended.");
        auction.bid();
    }

    function testBidFirstTime() public {
        vm.startPrank(seller);
        assertEq(auction.started(), false);
        auction.start();
        vm.stopPrank();

        vm.startPrank(buyer2);
        vm.deal(buyer2, 2 ether);
        auction.bid{value: 2 ether}();
        assertEq(auction.highestBid(), 2 ether);
        assertEq(auction.highestBidder(), buyer2);
        vm.stopPrank();
    }

    function testBidMultipleTimes() public {
        testBidFirstTime();

        vm.startPrank(buyer2);
        vm.deal(buyer2, 3 ether);
        auction.bid{value: 3 ether}();
        assertEq(auction.highestBid(), 3 ether);
        assertEq(auction.highestBidder(), buyer2);
        assertEq(auction.bids(buyer2), 2 ether);
        vm.stopPrank();
    }

    function testWithdraw() public {
        testBidMultipleTimes();
        vm.startPrank(buyer2);
        assertEq(auction.bids(buyer2), 2 ether);
        assertEq(buyer2.balance, 0 ether);
        auction.withdraw();
        assertEq(buyer2.balance, 2 ether);
        assertEq(auction.bids(buyer2), 0 ether);
        vm.stopPrank();
    }

    function testEndNotStarted() public {
        vm.expectRevert("Not started.");
        auction.end();
    }

    function testEndAlreadyEnded() public {
        testStartOk();
        vm.warp(block.timestamp + 70 seconds);
        auction.end();
        assertEq(auction.ended(), true);
        assertEq(block.timestamp >= auction.endAt(), true);
        vm.expectRevert("Already ended.");
        auction.end();
    }

    function testEndThresholdSurpassed() public {
        testBidFirstTime();
        vm.warp(block.timestamp + 70 seconds);
        auction.end();
        assertEq(nft.ownerOf(nftId), buyer2);
        assertEq(seller.balance, 2 ether);
    }

    function testEndThresholdNotSurpassed() public {
        testStartOk();
        vm.warp(block.timestamp + 70 seconds);
        auction.end();
        assertEq(nft.ownerOf(nftId), seller);
    }
}
