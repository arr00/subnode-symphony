// SPDX-LICENSE: MIT
pragma solidity ^0.8.13;

import {BaseRegistrarImplementation} from "ens-contracts/ethregistrar/BaseRegistrarImplementation.sol";
import {ENSRegistryWithFallback} from "ens-contracts/registry/ENSRegistryWithFallback.sol";
import {NameWrapper} from "ens-contracts/wrapper/NameWrapper.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

abstract contract ENSManager is IERC1155Receiver {
    error NotOwner();
    error NodeNotOwned();
    error InvalidTokenAmount();
    error InvalidTokenSender();
    error NodeLocked();

    BaseRegistrarImplementation public immutable ENS;
    bytes32 public immutable ENS_BASE_NODE;
    ENSRegistryWithFallback public immutable ENS_REGISTRY;
    NameWrapper public immutable NAME_WRAPPER;

    struct NodeInfo {
        address payable owner;
        uint40 lockTime;
    }

    mapping(bytes32 => NodeInfo) public nodeMeta;

    constructor(
        BaseRegistrarImplementation ens,
        ENSRegistryWithFallback ensRegistry,
        NameWrapper nameWrapper
    ) {
        ENS = ens;
        ENS_BASE_NODE = ENS.baseNode();
        ENS_REGISTRY = ensRegistry;
        NAME_WRAPPER = nameWrapper;
    }

    function deposit(uint256 tokenId) external {
        NAME_WRAPPER.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            1,
            ""
        );
    }

    function withdraw(uint256 tokenId) external isAllowed(bytes32(tokenId)) {
        if (nodeMeta[bytes32(tokenId)].lockTime > block.timestamp) {
            revert NodeLocked();
        }
        NAME_WRAPPER.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            1,
            ""
        );
        delete nodeMeta[bytes32(tokenId)];
    }

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external isAllowed(node) {
        NAME_WRAPPER.setRecord(node, owner, resolver, ttl);
    }

    function setResolver(
        bytes32 node,
        address resolver
    ) external isAllowed(node) {
        NAME_WRAPPER.setResolver(node, resolver);
    }

    function setTTL(bytes32 node, uint64 ttl) external isAllowed(node) {
        NAME_WRAPPER.setTTL(node, ttl);
    }

    function _setSubnodeOwner(
        bytes32 node,
        string memory label,
        address owner
    ) internal returns (bytes32) {
        if (nodeMeta[node].owner == address(0)) {
            revert NodeNotOwned();
        }
        return NAME_WRAPPER.setSubnodeOwner(node, label, owner, 0, 0);
    }

    function lockNode(bytes32 node, uint40 timestamp) external isAllowed(node) {
        if (nodeMeta[node].lockTime > timestamp) {
            revert NodeLocked();
        }
        nodeMeta[node].lockTime = timestamp;
    }

    function _ensNodeExists(bytes32 node) internal view returns (bool) {
        return ENS_REGISTRY.owner(node) != address(0);
    }

    function _isLockedForAYear(bytes32 node) internal view returns (bool) {
        (address owner, , uint64 expiry) = NAME_WRAPPER.getData(uint256(node));
        return
            owner == address(this) &&
            nodeMeta[node].lockTime > block.timestamp &&
            nodeMeta[node].lockTime - block.timestamp >= 365 days &&
            expiry > block.timestamp &&
            expiry - block.timestamp - 90 days >= 365 days;
    }

    function _isNodeInGoodStanding(bytes32 node) internal view returns (bool) {
        (address owner, , uint64 expiry) = NAME_WRAPPER.getData(uint256(node));
        return owner == address(this) && expiry - 90 days > block.timestamp;
    }

    function onERC1155Received(
        address,
        address from,
        uint256 tokenId,
        uint256 value,
        bytes calldata
    ) external returns (bytes4) {
        if (msg.sender != address(NAME_WRAPPER)) {
            revert InvalidTokenSender();
        }
        if (value != 1) {
            revert InvalidTokenAmount();
        }
        nodeMeta[bytes32(tokenId)].owner = payable(from);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4) {
        revert();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    modifier isAllowed(bytes32 node) {
        if (nodeMeta[node].owner != msg.sender) {
            revert NotOwner();
        }
        _;
    }
}
