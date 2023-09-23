/// SPDX-LICENSE: MIT
pragma solidity ^0.8.13;

import {ENSRegistryWithFallback} from "ens-contracts/registry/ENSRegistryWithFallback.sol";

abstract contract Auctioneer {
    ENSRegistryWithFallback public immutable ENS_REGISTRY;

    constructor(ENSRegistryWithFallback ensRegistry) {
        ENS_REGISTRY = ensRegistry;
    }

    function _setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner
    ) internal returns (bytes32) {
        return ENS_REGISTRY.setSubnodeOwner(node, label, owner);
    }
}
