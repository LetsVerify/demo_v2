// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBSMath.sol";

contract BBSMathTest is Test {
    function test_PairingValid() public {
        BBSMath.G1Point memory g1 = BBSMath.g1Generator();
        BBSMath.G2Point memory g2 = BBSMath.g2Generator();
        BBSMath.G1Point memory negG1 = BBSMath.negate(g1);

        // e(g1, g2) * e(-g1, g2) == 1
        bool result = BBSMath.pairing2(g1, g2, negG1, g2);
        assertTrue(result, "Pairing should succeed with e(g1, g2) * e(-g1, g2) == 1");
    }

    function test_PairingInvalid() public {
        BBSMath.G1Point memory g1 = BBSMath.g1Generator();
        BBSMath.G2Point memory g2 = BBSMath.g2Generator();

        // Should return false for e(g1, g2) * e(g1, g2) != 1
        // We catch the revert message if the precompile returns success but output is 0.
        // Wait, precompile 0x08 returns 1 or 0 if it succeeds, but reverts on invalid input format.
        // `BBSMath.pairing2` returns `out[0] == 1`, but requires `success`.
        bool result = BBSMath.pairing2(g1, g2, g1, g2);
        assertFalse(result, "Pairing should return false for e(g1, g2) * e(g1, g2) != 1");
    }
}
