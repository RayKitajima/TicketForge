//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../src/AgencyFactory.sol";
import "../src/Agency.sol";
import "../src/Show.sol";
import "../src/Staff.sol";
import "../src/Ticket.sol";
import "../src/Utils.sol";

import "./MusicFes.sol";
import "./Buyer.sol";

contract CheckInTest is Test {
    address owner;

    MusicFes fesContract;
    AgencyFactory agencyFactoryContract;
    Agency agencyContract;

    function setUp() public {
        owner = address(this);
        agencyFactoryContract = new AgencyFactory();

        fesContract = new MusicFes(vm, owner, agencyFactoryContract);
        vm.deal(address(fesContract), 100 ether);
        fesContract.setup();

        agencyContract = fesContract.agencyContract();
        vm.deal(address(agencyContract), 100 ether);
        
        vm.deal(address(this), 100 ether);
        
        fesContract.deploy();

        fesContract.setAllShowsScheduled();
    }

    /**
     * In this test case, CheckinCode is composed of message body, hash and signature.
     *
     * Message body is composed of showId, seatTypeId, seatNum, seatName,
     * ticketId, buyerName, buyer address and nonce.
     * The nonce value is used to prevent copying the pregenerated CheckinCode.
     * The hash is generated by keccak256 of the message body.
     * The signature is generated by the buyer's private key.
     *
     * Test check-in procedures
     *   1. ticket holder (=buyer) open the ticket page
     *   2. enter "check-in code" (=nonce) posted near the admission gate to the tiekcet page, and make QR code
     *   3. admission staff scans the generated code and obtains its address
     *   4. verify that the address obtained matches the address who purchased the ticket
     *
     * Test check-in code:
     *   <showId>,<seatTypeId>,<seatNum>,<seatName>,<buyerName>,<buyerAddress>,<nonce>
     *
     *   <showId> - the id of the show
     *   <seatTypeId> - the id of the seat type
     *   <seatNum> - the number of the seat
     *   <seatName> - the name of the seat
     *   <buyerName> - the name of the buyer
     *   <buyerAddress> - the address of the buyer
     *   <nonce>: random number (4 digits)
     *
     * Test buyer:
     *   address : 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
     *   private key : 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
     *
     * Test CheckinCode:
     * {
     *   "message": "1,1,1,Standard Seat 1-1,John Doe,0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266,1234",
     *   "messageHash": "0x83cbf4837c15e737f352f6b7b28989a42667a7e65070c8eec548384f4560f221",
     *   "v": "0x1c",
     *   "r": "0x5d606cf3fcb0b9d8eab22c689baf12b62571df76787b8ac7fdb642d0bf3d7c3d",
     *   "s": "0x7064e327e2848fc74cc4b19c4669bfd3e0d8b8179e2c0277566d5e6dd8e03ff7",
     *   "signature": "0x5d606cf3fcb0b9d8eab22c689baf12b62571df76787b8ac7fdb642d0bf3d7c3d7064e327e2848fc74cc4b19c4669bfd3e0d8b8179e2c0277566d5e6dd8e03ff71c"
     * }
     */
    function testCheckIn() public {
        vm.prank(owner);

        uint256 showId = 0;
        uint256 seatTypeId = 0;
        uint256 seatNum = 3;

        Show show = agencyContract.getShow(showId);

        // add staff
        address staffAddress = address(1234);
        string memory staffName = "John Doe";
        vm.prank(owner);
        show.addStaff(staffAddress, staffName);

        // test staff name
        assertEq(
            show.getStaffName(staffAddress),
            staffName,
            string(
                abi.encodePacked(
                    "staff name is unexpected : ",
                    show.getStaffName(staffAddress)
                )
            )
        );

        // buy ticket
        Buyer buyer = new Buyer(agencyContract, "John Doe");
        vm.deal(address(buyer), 100 ether);

        uint256 seatTypePrice = show.getSeatTypePrice(seatTypeId);

        buyer.buyTicket(showId, seatTypeId, seatNum, seatTypePrice);
        Ticket.TicketInfo memory ticketInfo = buyer.getTicketInfo();
        uint256 ticketId = ticketInfo.ticketId;
        assertEq(ticketId, 1, "ticketId should be 1");

        // get CheckinCode from emulated buyer contract
        (, bytes32 checkinCodeHash, bytes memory checkinCodeSig) = buyer
            .makeCheckinCode();

        // check sig length
        assertEq(
            checkinCodeSig.length,
            65,
            string(
                abi.encodePacked(
                    "checkinCodeSig.length is unexpected : ",
                    checkinCodeSig.length
                )
            )
        );

        // recover address from the checkinCode
        address buyerAddress = Utils.verifySign(
            checkinCodeHash,
            checkinCodeSig
        );

        // check if the checkinCode is valid
        assertTrue(
            buyerAddress ==
                address(0x00f39fd6e51aad88f6f4ce6ab8827279cfffb92266),
            string(
                abi.encodePacked("buyer address is unexpected : ", buyerAddress)
            )
        );
    }
}
