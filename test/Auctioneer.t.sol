// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "../src/Auctioneer.sol";

contract AuctioneerTest is Test {
    Auctioneer public auctioneer;
    address constant arr00 = 0x2B384212EDc04Ae8bB41738D05BA20E33277bf33;
    NameWrapper constant namewrapper =
        NameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    BaseRegistrarImplementation constant ens =
        BaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    function setUp() public {
        auctioneer = new Auctioneer(
            ens,
            ENSRegistryWithFallback(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e),
            namewrapper
        );

        vm.startPrank(arr00);
        ens.setApprovalForAll(address(namewrapper), true);
        namewrapper.wrapETH2LD(
            "arr00",
            arr00,
            0,
            0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41
        );
        vm.stopPrank();
    }

    function test_depositEns() public {
        vm.prank(arr00);
        namewrapper.safeTransferFrom(
            arr00,
            address(auctioneer),
            42101940235729599527735073319648523872099689871269006044944747914291998316615,
            1,
            ""
        );

        assertEq(
            namewrapper.balanceOf(
                arr00,
                42101940235729599527735073319648523872099689871269006044944747914291998316615
            ),
            0
        );
        assertEq(
            namewrapper.balanceOf(
                address(auctioneer),
                42101940235729599527735073319648523872099689871269006044944747914291998316615
            ),
            1
        );
    }

    function test_lickAuction() public {
        address firstBidder = address(0x12345);
        address secondVoter = address(0x2345);

        vm.prank(arr00);
        namewrapper.safeTransferFrom(
            arr00,
            address(auctioneer),
            42101940235729599527735073319648523872099689871269006044944747914291998316615,
            1,
            ""
        );

        vm.deal(firstBidder, 1 ether);
        vm.prank(firstBidder);
        auctioneer.lick{value: 0.001 ether}(
            bytes32(
                uint256(
                    42101940235729599527735073319648523872099689871269006044944747914291998316615
                )
            ),
            "zoo"
        );

        vm.deal(secondVoter, 1 ether);
        vm.prank(secondVoter);
        auctioneer.bid{value: 0.002 ether}(
            bytes32(
                uint256(
                    42101940235729599527735073319648523872099689871269006044944747914291998316615
                )
            ),
            "zoo"
        );

        vm.warp(block.timestamp + 1 days);

        auctioneer.finalize(
            bytes32(
                uint256(
                    42101940235729599527735073319648523872099689871269006044944747914291998316615
                )
            ),
            "zoo"
        );
    }
}
