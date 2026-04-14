// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BBSMath.sol";

/**
 * @title BBSVerifier
 * @notice Pure math and cryptographic logic for verifying BBS+ NIZK proofs. Minimal business logic here.
 */
contract BBSVerifier {
    using BBSMath for BBSMath.G1Point;

    BBSMath.G1Point public G1;
    BBSMath.G2Point internal G2;
    BBSMath.G2Point internal publicKey;
    BBSMath.G1Point[] public publicBases; // H0, H1, ... H_null, H_gamma

    function getG2() public view returns (BBSMath.G2Point memory) {
        return G2;
    }

    function getPublicKey() public view returns (BBSMath.G2Point memory) {
        return publicKey;
    }

    struct Proof {
        BBSMath.G1Point A_bar;
        BBSMath.G1Point B_bar;
        BBSMath.G1Point U;
        uint256 s;
        uint256 t;
        uint256 u_gamma;
    }

    constructor(
        BBSMath.G1Point memory _g1,
        BBSMath.G2Point memory _g2,
        BBSMath.G2Point memory _publicKey,
        BBSMath.G1Point[] memory _publicBases
    ) {
        G1 = _g1;
        G2 = _g2;
        publicKey = _publicKey;
        // Deep copy bases
        for(uint i=0; i<_publicBases.length; i++){
            publicBases.push(_publicBases[i]);
        }
    }

    /**
     * @notice Verify the NIZK proof over disclosed messages
     * @param proof The zero-knowledge proof of knowledge
     * @param disclosedMessages Contains the revealed message constraints + m_null
     * @param ctx Domain separation tag
     */
    function verifyProof(
        Proof calldata proof,
        uint256[] calldata disclosedMessages,
        bytes32 ctx
    ) public view returns (bool) {
        require(disclosedMessages.length == publicBases.length - 1, "Length mismatch");

        // 1. Recompute challenge c'
        // c' = H(ctx || m_J || A_bar || B_bar || U)
        uint256 c = uint256(keccak256(abi.encodePacked(
            ctx,
            disclosedMessages,
            proof.A_bar.x, proof.A_bar.y,
            proof.B_bar.x, proof.B_bar.y,
            proof.U.x, proof.U.y
        ))) % BBSMath.P; // Challenge must be mapped back to the field

        // 2. Pairing check: e(A_bar, PK) == e(B_bar, G2)
        bool pairingOk = BBSMath.pairing(proof.A_bar, publicKey, proof.B_bar, G2);
        if (!pairingOk) return false;

        // 3. Homomorphic check
        // left = U + c*B_bar
        BBSMath.G1Point memory left = proof.U.g1add(proof.B_bar.g1mul(c));

        // compute C_J = G1 + sum(m_j * H_j)
        BBSMath.G1Point memory CJ = G1;
        for (uint i = 0; i < disclosedMessages.length; i++) {
            CJ = CJ.g1add(publicBases[i].g1mul(disclosedMessages[i]));
        }

        // right = s*C_J + t*A_bar + u_gamma*H_gamma
        BBSMath.G1Point memory right = CJ.g1mul(proof.s);
        right = right.g1add(proof.A_bar.g1mul(proof.t));
        
        BBSMath.G1Point memory H_gamma = publicBases[publicBases.length - 1];
        right = right.g1add(H_gamma.g1mul(proof.u_gamma));

        return (left.x == right.x && left.y == right.y);
    }
}
