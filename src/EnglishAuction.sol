// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./MyNFT.sol";
import "forge-std/console.sol";

contract EnglishAuction {
    IERC721 public immutable nft;
    uint256 public immutable nftId;
    address payable public immutable seller;
    uint32 public endAt;
    bool public started;
    bool public ended;
    address payable public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public bids;

    event Start();
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event End(address highestBidder, uint256 highestBid);

    constructor(
        address _nft,
        uint256 _nftId,
        uint256 _startingBid
    ) {
        nft = IERC721(_nft);
        nftId = _nftId;
        highestBid = _startingBid; // threshold
        seller = payable(msg.sender);
    }

    function start() external {
        require(msg.sender == seller, "Not seller");
        require(!started, "Already started.");

        started = true;
        endAt = uint32(block.timestamp + 60 seconds);

        // Transfer nft from seller to SC.
        nft.transferFrom(seller, address(this), nftId);
        emit Start();
    }

    function bid() external payable {
        require(started, "Not started.");
        require(!ended || block.timestamp < endAt, "Already ended.");
        require(msg.value > highestBid, "previous bid not surpassed.");

        if (highestBidder != address(0)) {
            // Previous highest bidder will be able to withdraw.
            bids[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = payable(msg.sender);
        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 val = bids[msg.sender];
        // No reentrancy.
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(val);
        emit Withdraw(msg.sender, val);
    }

    function end() external {
        require(started, "Not started.");
        require(!ended, "Already ended.");
        require(block.timestamp >= endAt, "Not ended.");

        ended = true;

        if (highestBidder != address(0)) {
            // If threshold was surpassed
            // Transfers nft from SC to highest bidder.
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            // Transfers funds from SC to seller.
            (bool success, ) = seller.call{value: highestBid}("");
            require(success, "Transfer failed.");
        } else {
            // If threshold was not surpassed
            // Transfer nft back to seller.
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
