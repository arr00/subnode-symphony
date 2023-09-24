// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BaseRegistrarImplementationMock is ERC721 {
    bytes32 public constant baseNode =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

    constructor() ERC721("BaseRegistrarImplementationMock", "BRIM") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
