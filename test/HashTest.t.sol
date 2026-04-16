// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBSMath.sol";

contract HashTest is Test {
    function testHash() public {
        bytes32 ctx = bytes32("LetsVerify");
        bytes memory encodedMsgs;
        uint256 m0 = 48305238028827234457057068308976830949311451167141786071899284143701496669988;
        uint256 m1 = 30362564611297414121344052595118041020684015714278959822893592029797294529055;
        uint256 m2 = 89017634352366059964332753369766654038457760534865200995547152036320389318152;
        uint256 m3 = 89017634352366059964332753369766654038457760534865200995547152036320389318152;
        encodedMsgs = abi.encodePacked(encodedMsgs, m0 % BBSMath.FR_MODULUS);
        encodedMsgs = abi.encodePacked(encodedMsgs, m1 % BBSMath.FR_MODULUS);
        encodedMsgs = abi.encodePacked(encodedMsgs, m2 % BBSMath.FR_MODULUS);
        encodedMsgs = abi.encodePacked(encodedMsgs, m3 % BBSMath.FR_MODULUS);
        
        bytes memory payload = abi.encodePacked(ctx, encodedMsgs);
        console.logBytes(payload);
        uint256 c = uint256(keccak256(payload)) % BBSMath.FR_MODULUS;
        console.log("C: %s", c);
    }
}
