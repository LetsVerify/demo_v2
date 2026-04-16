// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BBSMath {
    uint256 internal constant FR_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 internal constant FQ_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    function g1Generator() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    function g2Generator() internal pure returns (G2Point memory) {
        return G2Point(
            [
                uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781),
                uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634)
            ],
            [
                uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930),
                uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531)
            ]
        );
    }

    function isInfinity(G1Point memory p) internal pure returns (bool) {
        return p.x == 0 && p.y == 0;
    }

    function negate(G1Point memory p) internal pure returns (G1Point memory) {
        if (isInfinity(p)) return G1Point(0, 0);
        return G1Point(p.x, FQ_MODULUS - (p.y % FQ_MODULUS));
    }

    function plus(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        bool success;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(p1))
            mstore(add(ptr, 0x20), mload(add(p1, 0x20)))
            mstore(add(ptr, 0x40), mload(p2))
            mstore(add(ptr, 0x60), mload(add(p2, 0x20)))
            success := staticcall(gas(), 0x06, ptr, 0x80, r, 0x40)
        }
        require(success, "BBSMath: ecadd failed");
    }

    function scalarMul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {
        bool success;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, mload(p))
            mstore(add(ptr, 0x20), mload(add(p, 0x20)))
            mstore(add(ptr, 0x40), s)
            success := staticcall(gas(), 0x07, ptr, 0x60, r, 0x40)
        }
        require(success, "BBSMath: ecmul failed");
    }

    function pairing2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2)
        internal
        view
        returns (bool)
    {
        uint256[12] memory input;
        input[0] = a1.x;
        input[1] = a1.y;
        input[2] = a2.x[1];
        input[3] = a2.x[0];
        input[4] = a2.y[1];
        input[5] = a2.y[0];
        
        input[6] = b1.x;
        input[7] = b1.y;
        input[8] = b2.x[1];
        input[9] = b2.x[0];
        input[10] = b2.y[1];
        input[11] = b2.y[0];

        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(gas(), 0x08, input, 0x180, out, 0x20)
        }
        require(success, "BBSMath: pairing failed");
        return out[0] == 1;
    }
}
