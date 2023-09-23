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

    BaseRegistrarImplementation public immutable ENS;
    bytes32 public immutable ENS_BASE_NODE;
    ENSRegistryWithFallback public immutable ENS_REGISTRY;
    NameWrapper public immutable NAME_WRAPPER;

    mapping(bytes32 => address) public nodeOwners;

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
        nodeOwners[bytes32(tokenId)] = msg.sender;
    }

    function withdraw(uint256 tokenId) external {
        if (nodeOwners[bytes32(tokenId)] != msg.sender) {
            revert NotOwner();
        }
        NAME_WRAPPER.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            1,
            ""
        );
        delete nodeOwners[bytes32(tokenId)];
    }

    function _setSubnodeOwner(
        bytes32 node,
        string memory label,
        address owner
    ) internal returns (bytes32) {
        if (nodeOwners[node] == address(0)) {
            revert NodeNotOwned();
        }
        return NAME_WRAPPER.setSubnodeOwner(node, label, owner, 0, 0);
    }

    function _ensNodeExists(bytes32 node) internal view returns (bool) {
        return ENS_REGISTRY.owner(node) != address(0);
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
        nodeOwners[bytes32(tokenId)] = from;
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
}
