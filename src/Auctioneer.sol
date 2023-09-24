/// SPDX-LICENSE: MIT
pragma solidity ^0.8.13;

import {ENSManager, BaseRegistrarImplementation, ENSRegistryWithFallback, NameWrapper} from "./ENSManager.sol";

contract Auctioneer is ENSManager {
    event AuctionCreated(bytes32 indexed parentNode, string label, string name);
    event AuctionBid(
        bytes32 indexed parentNode,
        string label,
        uint72 bid,
        address bidder
    );
    event AuctionFinalized(
        bytes32 indexed parentNode,
        string label,
        bytes32 newNode,
        uint72 price,
        address winner
    );

    error NotEnoughEth();
    error AuctionAlreadyExists();
    error AuctionNotLive();
    error AuctionNotExecutable();
    error NodeExists();
    error ClaimLocked();

    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => FutureClaim) public futureClaims;
    uint72 public constant MIN_BID = 0.001 ether;
    uint72 public constant MIN_DELTA = 0.001 ether;
    uint40 public constant AUCTION_DURATION = 5 minutes; // Temporary for testing

    struct Auction {
        address payable leadingBidder;
        uint72 firstPrice;
        uint72 secondPrice;
        uint40 startTime;
    }

    /// @notice Store info regarding a future claim of an auction proceeds
    struct FutureClaim {
        bytes32 parentNode;
        uint40 unlockTime;
        address payable claimer;
        address payable payer;
    }

    constructor(
        BaseRegistrarImplementation ens,
        ENSRegistryWithFallback ensRegistry,
        NameWrapper nameWrapper
    ) ENSManager(ens, ensRegistry, nameWrapper) {}

    function lick(bytes32 parentNode, string memory label) external payable {
        bytes32 labelHash = keccak256(bytes(label));
        if (msg.value != MIN_BID) {
            revert NotEnoughEth();
        }

        if (
            auctions[keccak256(abi.encodePacked(parentNode, labelHash))]
                .startTime != 0
        ) {
            revert AuctionAlreadyExists();
        }

        if (
            _ensNodeExists(keccak256(abi.encodePacked(parentNode, labelHash)))
        ) {
            revert NodeExists();
        }

        auctions[keccak256(abi.encodePacked(parentNode, labelHash))] = Auction({
            leadingBidder: payable(msg.sender),
            firstPrice: MIN_BID,
            secondPrice: MIN_BID,
            startTime: uint40(block.timestamp)
        });

        emit AuctionCreated(
            parentNode,
            label,
            string(abi.encodePacked(label, NAME_WRAPPER.names(parentNode)))
        );
        emit AuctionBid(parentNode, label, uint72(msg.value), msg.sender);
    }

    function bid(bytes32 parentNode, string memory label) external payable {
        bytes32 labelHash = keccak256(bytes(label));
        Auction storage auction = auctions[
            keccak256(abi.encodePacked(parentNode, labelHash))
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
        emit AuctionBid(parentNode, label, uint72(msg.value), msg.sender);
    }

    function finalize(bytes32 parentNode, string memory label) external {
        bytes32 labelHash = keccak256(bytes(label));
        Auction memory auction = auctions[
            keccak256(abi.encodePacked(parentNode, labelHash))
        ];
        if (
            auction.startTime == 0 ||
            auction.startTime + AUCTION_DURATION > block.timestamp
        ) {
            revert AuctionNotExecutable();
        }
        bytes32 newNode = _setSubnodeOwner(
            parentNode,
            label,
            auction.leadingBidder
        );
        emit AuctionFinalized(
            parentNode,
            label,
            newNode,
            auction.secondPrice,
            auction.leadingBidder
        );
        // Winner gets second price
        auction.leadingBidder.transfer(
            auction.firstPrice - auction.secondPrice
        );
        address payable parentNodeOwner = nodeMeta[parentNode].owner;
        // Only send eth immediatly if locked for at least a year
        if (_isLockedForAYear(parentNode)) {
            parentNodeOwner.transfer(auction.secondPrice);
        } else {
            futureClaims[newNode] = FutureClaim({
                parentNode: parentNode,
                unlockTime: uint40(block.timestamp + 365 days),
                claimer: parentNodeOwner,
                payer: auction.leadingBidder
            });
        }
        delete auctions[keccak256(abi.encodePacked(parentNode, labelHash))];
    }

    function claim(bytes32 node) external {
        FutureClaim memory futureClaim = futureClaims[node];
        if (
            futureClaim.unlockTime > block.timestamp &&
            futureClaim.unlockTime > nodeMeta[futureClaim.parentNode].lockTime
        ) {
            revert ClaimLocked();
        }
        delete futureClaims[node];
        futureClaim.claimer.transfer(futureClaim.claimer.balance);
    }

    function refund(bytes32 node) external {
        FutureClaim memory futureClaim = futureClaims[node];
        if (
            _isNodeInGoodStanding(futureClaim.parentNode) &&
            nodeMeta[futureClaim.parentNode].owner == futureClaim.claimer &&
            ENS_REGISTRY.owner(node) == address(this)
        ) {
            revert ClaimLocked();
        }
        delete futureClaims[node];
        futureClaim.payer.transfer(futureClaim.payer.balance);
    }
}
