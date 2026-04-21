// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BBSVerifier.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

interface IERC5484 {
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    event Issued (
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        BurnAuth burnAuth
    );

    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}

/**
 * @title IssuerVerifier
 * @notice Business logic combining Issuer and Verifier responsibilities for the BBS+ DID Scheme
 */
contract IssuerVerifier is ERC721, IERC5484 {
    BBSVerifier public bbsVerifier;
    bytes32 public ctx;
    uint256[] public expectedConstraints;
    address public immutable deployer;
    string public defaultTokenURI;

    mapping(bytes32 => bool) public keyExist;
    mapping(bytes32 => bool) public usedNullifiers;
    mapping(address => bool) public hasToken;

    event NullifierPreCommitted(bytes32 N, address relayer);
    event TokenMinted(address indexed user, uint256 timestamp);

    constructor(
        address _bbsVerifier, 
        bytes32 _ctx, 
        uint256[] memory _expectedConstraints, 
        string memory _tokenURI,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC721(_tokenName, _tokenSymbol) {
        deployer = msg.sender;
        bbsVerifier = BBSVerifier(_bbsVerifier);
        ctx = _ctx;
        for (uint i = 0; i < _expectedConstraints.length; i++) {
            expectedConstraints.push(_expectedConstraints[i]);
        }
        defaultTokenURI = _tokenURI;
    }

    /**
     * @notice Step 2: User pre-commits their nullifier to the contract
     * N = Hash(UserAddr || m_null)
     */
    function stashNullifier(bytes32 N) external {
        require(!keyExist[N], "Nullifier already stashed");
        keyExist[N] = true;
        emit NullifierPreCommitted(N, msg.sender);
    }

    /**
     * @notice Step 5: Network verifies NIZK Proof and Mints the Token
     */
    function verifyAndMint(
        BBSVerifier.Proof calldata proof,
        uint256 m_null,
        uint256[] calldata constraints,
        address userAddr
    ) external {
        // 1. Verify nullifier pre-commitment
        bytes32 N = keccak256(abi.encodePacked(userAddr, m_null));
        require(keyExist[N], "Nullifier not pre-committed by user");
        require(!usedNullifiers[N], "Nullifier already used (Double- spend protection)");

        // 2. Prepare disclosed messages
        // disclosedMessages = constraints || m_null
        uint256[] memory disclosedMessages = new uint256[](constraints.length + 1);
        for(uint i = 0; i < constraints.length; i++) {
            disclosedMessages[i] = constraints[i];
        }
        disclosedMessages[constraints.length] = m_null;

        // 3. check the constraints match expected values
        require(constraints.length == expectedConstraints.length, "Invalid constraints length");
        for(uint i = 0; i < constraints.length; i++) {
            // Only check constraint if the expected constraint is not marked as empty/wildcard (0)
            if (expectedConstraints[i] != 0) {
                require(constraints[i] == expectedConstraints[i], "Constraint mismatch at index");
            }
        }

        // 4. Verify NIZK Proof
        bool isValid = bbsVerifier.verifyProof(proof, disclosedMessages, ctx);
        require(isValid, "ZKP Verification Failed");

        // 5. Mark nullifier as used
        usedNullifiers[N] = true;

        // 6. Mint Soulbound token (abstract representation)
        _mintToken(userAddr, uint256(N));
    }

    function _mintToken(address user, uint256 tokenId) internal {
        require(!hasToken[user], "User already holds token");
        hasToken[user] = true;
        _mint(user, tokenId);
        emit TokenMinted(user, block.timestamp);
        emit Issued(deployer, user, tokenId, BurnAuth.IssuerOnly);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function burnAuth(uint256 /* tokenId */) external pure returns (BurnAuth) {
        return BurnAuth.IssuerOnly;
    }

    /**
     * @notice Returns the URI pointing to the metadata/image for this token
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // OpenZeppelin v5 check for token existence
        _requireOwned(tokenId);
        return defaultTokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        
        // Block transfers and burns unless it's the deployer
        if (from != address(0)) {
            require(msg.sender == deployer, "Only deployer can burn or transfer");
            auth = address(0); // Bypass the OpenZeppelin ERC721 internal auth checks
        }
        
        return super._update(to, tokenId, auth);
    }
}
