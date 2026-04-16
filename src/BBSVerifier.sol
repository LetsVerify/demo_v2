// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BBSMath.sol";

/**
 * @title BBSVerifier
 * @notice Pure math and cryptographic logic for verifying BBS+ NIZK proofs. Minimal business logic here.
 */
contract BBSVerifier {
    using BBSMath for BBSMath.G1Point;

    BBSMath.G2Point internal publicKey;
    BBSMath.G1Point[] public publicBases; // H0, H1, ... H_null, H_gamma

    function getG2() public pure returns (BBSMath.G2Point memory) {
        return BBSMath.g2Generator();
    }

    function getG1() public pure returns (BBSMath.G1Point memory) {
        return BBSMath.g1Generator();
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
        BBSMath.G2Point memory _publicKey,
        BBSMath.G1Point[] memory _publicBases
    ) {
        publicKey = _publicKey;
        // Deep copy bases
        for(uint i=0; i<_publicBases.length; i++){
            publicBases.push(_publicBases[i]);
        }
    }

    event DebugChallenge(uint256 c);

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
    ) public returns (bool) {
        require(disclosedMessages.length == publicBases.length - 1, "Length mismatch");

        // 1. Recompute challenge c'
        // c' = H(ctx || m_J || A_bar || B_bar || U)
        bytes memory encodedMsgs;
        for (uint i = 0; i < disclosedMessages.length; i++) {
            encodedMsgs = abi.encodePacked(encodedMsgs, disclosedMessages[i]);
        }
        bytes memory payload = abi.encodePacked(
            ctx,
            encodedMsgs,
            proof.A_bar.x, proof.A_bar.y,
            proof.B_bar.x, proof.B_bar.y,
            proof.U.x, proof.U.y
        );
        
        uint256 c = uint256(keccak256(payload)) % BBSMath.FR_MODULUS; // Challenge must be mapped back to the field
        emit DebugChallenge(c);

        // 2. Pairing check: e(A_bar, PK) * e(-B_bar, G2) == 1 => e(A_bar, PK) == e(B_bar, G2)
        bool pairingOk = BBSMath.pairing2(proof.A_bar, publicKey, BBSMath.negate(proof.B_bar), getG2());
        if (!pairingOk) return false;

        // 3. Homomorphic check
        // left = U + c*B_bar
        BBSMath.G1Point memory left = proof.U.plus(proof.B_bar.scalarMul(c));

        // compute C_J = G1 + sum(m_j * H_j)
        BBSMath.G1Point memory CJ = getG1();
        for (uint i = 0; i < disclosedMessages.length; i++) {
            CJ = CJ.plus(publicBases[i].scalarMul(disclosedMessages[i]));
        }

        // right = s*C_J + t*A_bar + u_gamma*H_gamma
        BBSMath.G1Point memory right = CJ.scalarMul(proof.s);
        right = right.plus(proof.A_bar.scalarMul(proof.t));
        
        BBSMath.G1Point memory H_gamma = publicBases[publicBases.length - 1];
        right = right.plus(H_gamma.scalarMul(proof.u_gamma));

        return (left.x == right.x && left.y == right.y);
    }
}
