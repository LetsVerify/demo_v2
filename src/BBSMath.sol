// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BBSMath {
    uint256 constant P = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    function g1add(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;
        assembly {
            if iszero(staticcall(not(0), 0x06, input, 0x80, r, 0x40)) {
                revert(0, 0)
            }
        }
    }

    function g1mul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;
        assembly {
            if iszero(staticcall(not(0), 0x07, input, 0x60, r, 0x40)) {
                revert(0, 0)
            }
        }
    }

    // e(A, B) == e(C, D) => e(A, B) * e(C, -D) == 1
    function pairing(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        uint256[12] memory input;
        input[0] = a1.x;
        input[1] = a1.y;
        input[2] = a2.x[1]; // x.c1
        input[3] = a2.x[0]; // x.c0
        input[4] = a2.y[1]; // y.c1
        input[5] = a2.y[0]; // y.c0

        input[6] = b1.x;
        input[7] = b1.y;
        input[8] = b2.x[1]; // x.c1
        input[9] = b2.x[0]; // x.c0
        input[10] = P - b2.y[1]; // negate y.c1 for pairing
        input[11] = P - b2.y[0]; // negate y.c0

        uint256[1] memory out;
        assembly {
            if iszero(staticcall(not(0), 0x08, input, 0x180, out, 0x20)) {
                revert(0, 0)
            }
        }
        return out[0] != 0;
    }
}
