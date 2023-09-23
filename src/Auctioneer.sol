/// SPDX-LICENSE: MIT
pragma solidity ^0.8.13;

contract Auctioneer {
    error NotEnoughEth();
    error AuctionAlreadyExists();
    error AuctionNotLive();
    error AuctionNotExecutable();

    mapping(bytes32 => Auction) public auctions;
    uint72 public constant MIN_BID = 0.001 ether;
    uint72 public constant MIN_DELTA = 0.001 ether;
    uint40 public constant AUCTION_DURATION = 1 days;

    struct Auction {
        address payable leadingBidder;
        uint72 firstPrice;
        uint72 secondPrice;
        uint40 startTime;
    }

    function lick(bytes32 node, bytes32 label) external payable {
        if (msg.value != MIN_BID) {
            revert NotEnoughEth();
        }

        if (auctions[keccak256(abi.encodePacked(node, label))].startTime == 0) {
            revert AuctionAlreadyExists();
        }

        auctions[keccak256(abi.encodePacked(node, label))] = Auction({
            leadingBidder: payable(msg.sender),
            firstPrice: MIN_BID,
            secondPrice: MIN_BID,
            startTime: uint40(block.timestamp)
        });
    }

    function bid(bytes32 node, bytes32 label) external payable {
        Auction storage auction = auctions[
            keccak256(abi.encodePacked(node, label))
        ];
        if (
            auction.startTime == 0 ||
            auction.startTime + AUCTION_DURATION < block.timestamp
        ) {
            revert AuctionNotLive();
        }
        if (msg.value < auction.firstPrice + MIN_DELTA) {
            revert NotEnoughEth();
        }
        auction.secondPrice = auction.firstPrice;
        auction.firstPrice = uint72(msg.value);
        // Refund previous bidder
        auction.leadingBidder.transfer(auction.secondPrice);
        auction.leadingBidder = payable(msg.sender);
    }

    function finalize(bytes32 node, bytes32 label) external payable {
        Auction memory auction = auctions[
            keccak256(abi.encodePacked(node, label))
        ];
        if (
            auction.startTime == 0 ||
            auction.startTime + AUCTION_DURATION > block.timestamp
        ) {
            revert AuctionNotExecutable();
        }
        // Winner gets second price
        auction.leadingBidder.transfer(auction.firstPrice - auction.secondPrice);
        delete auctions[keccak256(abi.encodePacked(node, label))];
    }
}
