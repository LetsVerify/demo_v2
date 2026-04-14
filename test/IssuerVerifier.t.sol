// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBSMath.sol";
import "../src/BBSVerifier.sol";
import "../src/IssuerVerifier.sol";

contract IssuerVerifierTest is Test {
    BBSVerifier public bbsVerifier;
    IssuerVerifier public issuerVerifier;

    bytes32 public constant CTX = keccak256("BBS_DID_APP_V2");
    address public user = address(0x1234);
    address public relayer = address(0x5678);

    function setUp() public {
        BBSMath.G1Point memory g1 = BBSMath.G1Point({x: 1, y: 2}); // Mocks!
        BBSMath.G2Point memory g2 = BBSMath.G2Point({
            x: [uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781), 11559732032986387107991004021392285783925812861821192530917403151452391805634],
            y: [uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930), 4082367875863433681332203403145435568316851327593401208105741076214120093531]
        });
        BBSMath.G2Point memory pk = BBSMath.G2Point({
            x: [uint256(21078157932976788369811386224298604876283678095953300695193627580536184663017), 3260306681974474822604563648776815682816091416970286175188033719997424721292], 
            y: [uint256(21872932232854780648641376857253831029627783545362812619304934661720191529610), 15974835493233460998260511752626128505010865937675816409903067489306439600529]
        }); // 1328790040692576325258580129229001772890358018148159309458854770206210226319
        
        BBSMath.G1Point[] memory bases = new BBSMath.G1Point[](6);
        bases[0] = BBSMath.G1Point({x: 1240703902419481545648986623473745806820787811594483762868555478458184666010, y: 18256809644617940920254137422873442228473372063501986223346572230462785524439});
        bases[1] = BBSMath.G1Point({x: 13020051060923754131228834502880722230806022247808159414293488215070332394772, y: 4529195280833079968741232889459250032235684423945803123503195484318934791269});
        bases[2] = BBSMath.G1Point({x: 16297305326858617051978407466566022015897499588105011865519416711980789611480, y: 3457763090096090198366700259693644531770479248862060079356697617968728920669});
        bases[3] = BBSMath.G1Point({x: 2253800715866524994843494300154676387161899760404330152495442103191129641090, y: 9799921154527725974487574934896288658143635125210110869057393462183450014056});
        bases[4] = BBSMath.G1Point({x: 15591676955350207499762345130216057388364340524562767442403038585836757427173, y: 366693626097570863962860699973119751999356879228643136313636147692477681999});
        bases[5] = BBSMath.G1Point({x: 21393812497764701958592826102470503271515498520329721604743009071119726253411, y: 16563212233814295780128168415970014578295470256244992910750946401593357383812});

        // Deploy pure math verifier
        bbsVerifier = new BBSVerifier(g1, g2, pk, bases);
        
        // Expected constraints
        uint256[] memory expectedConstraints = new uint256[](4);
        expectedConstraints[0] = uint256(0x6acbcbbc11c81227f015cba2082d6b71a8792fee9e139685dec3cc78556ba724); // Age=18
        expectedConstraints[1] = uint256(0x43209a421195688f1d02b91a0f147396c9d214f488a3c501ad3f73fd10c3da1f); // Nationality=US
        expectedConstraints[2] = uint256(0x6fdf09da2cebbbdbd7e38e0efd01288065743c2a87b82fadd86a1af98ffc3184); // Verified=true
        expectedConstraints[3] = uint256(0xc4ce3210982aa6fc94dabe46dc1dbf454d54a3a2fbc51d2ae982e47c784f4608); // Empty

        string memory testTokenURI = "ipfs://QmTestHash...";
        string memory testTokenName = "LetsVerify";
        string memory testTokenSymbol = "LetsV";

        // Deploy combined logic contract
        issuerVerifier = new IssuerVerifier(
            address(bbsVerifier), 
            CTX, 
            expectedConstraints,
            testTokenURI,
            testTokenName,
            testTokenSymbol
        );
    }

    function test_InitialState() view public {
        assertEq(address(issuerVerifier.bbsVerifier()), address(bbsVerifier));
        assertEq(issuerVerifier.ctx(), CTX);
    }

    // Mocking a successful ZKP workflow is mathematically complex without FFI due to BN254 constraints.
    // In actual implementation, we would extract a real proof from Rust and feed it here.
    function test_StashNullifier() public {
        uint256 m_null = 192837465;
        bytes32 N = keccak256(abi.encodePacked(user, m_null));

        vm.prank(relayer);
        issuerVerifier.stashNullifier(N);

        assertTrue(issuerVerifier.keyExist(N));
    }

    function test_VerifyAndMint() public {
        uint256 m_null = 192837465;
        bytes32 N = keccak256(abi.encodePacked(user, m_null));

        // 1. Pre-commit nullifier
        vm.prank(relayer);
        issuerVerifier.stashNullifier(N);

        // 2. Prepare mock proof struct
        BBSVerifier.Proof memory proof = BBSVerifier.Proof({
            A_bar: BBSMath.G1Point(uint256(18240449537066144224374956612927054362722724221656931348090417631743859197384), 9219297243724659693974501719167475285107135868283376375754495406007940627103),
            B_bar: BBSMath.G1Point(uint256(3722135581318468566903890117346542015830640382754361500474997601945512614300), 3524037676911001584192983393295475122659736155527353835007614541310400852872),
            U: BBSMath.G1Point(uint256(17942713163671002772048476628456036555361061105266416839098197374779677304219), 6358543843323181799283503706896002459221761971952669513594424446307322210490),
            s: 19520145271776029937683947518516203872450041095466355072915075574615239343812,
            t: 12403803877892551323243645288320623263978788684600641656202520356751162864536,
            u_gamma: 2770982020189074713186096940998458865333388660612628666011804758211952355741
        });

        // 3. Prepare valid constraints matching our setup expected
        uint256[] memory constraints = new uint256[](4);
        constraints[0] = uint256(0x6acbcbbc11c81227f015cba2082d6b71a8792fee9e139685dec3cc78556ba724);
        constraints[1] = uint256(0x43209a421195688f1d02b91a0f147396c9d214f488a3c501ad3f73fd10c3da1f);
        constraints[2] = uint256(0x6fdf09da2cebbbdbd7e38e0efd01288065743c2a87b82fadd86a1af98ffc3184);
        constraints[3] = uint256(0xc4ce3210982aa6fc94dabe46dc1dbf454d54a3a2fbc51d2ae982e47c784f4608);

        // 4. Mock the call to pure math library to return `true` (bypass curve validation)
        vm.mockCall(
            address(bbsVerifier),
            abi.encodeWithSelector(BBSVerifier.verifyProof.selector),
            abi.encode(true)
        );

        // 5. Trigger verifyAndMint business logic
        vm.prank(relayer);
        issuerVerifier.verifyAndMint(proof, m_null, constraints, user);

        // 6. Assert end states
        assertTrue(issuerVerifier.usedNullifiers(N), "Nullifier should be marked used");
        assertTrue(issuerVerifier.hasToken(user), "User should have minted token");
    }

    function test_RevertIf_ZKPVerificationFails() public {
        uint256 m_null = 192837465;
        bytes32 N = keccak256(abi.encodePacked(user, m_null));

        vm.prank(relayer);
        issuerVerifier.stashNullifier(N);

        BBSVerifier.Proof memory proof;
        uint256[] memory constraints = new uint256[](4);
        constraints[0] = uint256(0x6acbcbbc11c81227f015cba2082d6b71a8792fee9e139685dec3cc78556ba724);
        constraints[1] = uint256(0x43209a421195688f1d02b91a0f147396c9d214f488a3c501ad3f73fd10c3da1f);
        constraints[2] = uint256(0x6fdf09da2cebbbdbd7e38e0efd01288065743c2a87b82fadd86a1af98ffc3184);
        constraints[3] = uint256(0xc4ce3210982aa6fc94dabe46dc1dbf454d54a3a2fbc51d2ae982e47c784f4608);

        // Mock math evaluation to reject the proof
        vm.mockCall(
            address(bbsVerifier),
            abi.encodeWithSelector(BBSVerifier.verifyProof.selector),
            abi.encode(false)
        );

        vm.prank(relayer);
        vm.expectRevert("ZKP Verification Failed");
        issuerVerifier.verifyAndMint(proof, m_null, constraints, user);
    }

    function _mintTokenToUser() internal returns (uint256) {
        uint256 m_null = 192837465;
        bytes32 N = keccak256(abi.encodePacked(user, m_null));

        vm.prank(relayer);
        issuerVerifier.stashNullifier(N);

        BBSVerifier.Proof memory proof;
        uint256[] memory constraints = new uint256[](4);
        constraints[0] = uint256(0x6acbcbbc11c81227f015cba2082d6b71a8792fee9e139685dec3cc78556ba724);
        constraints[1] = uint256(0x43209a421195688f1d02b91a0f147396c9d214f488a3c501ad3f73fd10c3da1f);
        constraints[2] = uint256(0x6fdf09da2cebbbdbd7e38e0efd01288065743c2a87b82fadd86a1af98ffc3184);
        constraints[3] = uint256(0xc4ce3210982aa6fc94dabe46dc1dbf454d54a3a2fbc51d2ae982e47c784f4608);

        vm.mockCall(
            address(bbsVerifier),
            abi.encodeWithSelector(BBSVerifier.verifyProof.selector),
            abi.encode(true)
        );

        vm.prank(relayer);
        issuerVerifier.verifyAndMint(proof, m_null, constraints, user);

        return uint256(N);
    }

    function test_ERC5484_InterfaceAndBurnAuth() public {
        uint256 tokenId = _mintTokenToUser();
        
        // Assert token was minted properly as ERC721
        assertEq(issuerVerifier.ownerOf(tokenId), user);
        assertEq(issuerVerifier.balanceOf(user), 1);
        
        // Check ERC5484 interface string and burnAuth
        assertTrue(issuerVerifier.supportsInterface(type(IERC5484).interfaceId));
        assertEq(uint(issuerVerifier.burnAuth(tokenId)), uint(IERC5484.BurnAuth.IssuerOnly));
    }

    function test_RevertIf_UserTriesToTransfer() public {
        uint256 tokenId = _mintTokenToUser();
        address recipient = address(0x999);
        
        vm.prank(user);
        vm.expectRevert("Only deployer can burn or transfer");
        issuerVerifier.transferFrom(user, recipient, tokenId);
    }

    function test_DeployerCanTransfer() public {
        uint256 tokenId = _mintTokenToUser();
        address recipient = address(0x999);
        
        // The test contract deploys IssuerVerifier, so it is the deployer
        issuerVerifier.transferFrom(user, recipient, tokenId);
        
        assertEq(issuerVerifier.ownerOf(tokenId), recipient);
    }

    function test_RevertIf_UserTriesToBurn() public {
        uint256 tokenId = _mintTokenToUser();
        
        vm.prank(user);
        vm.expectRevert("Only deployer can burn or transfer");
        issuerVerifier.burn(tokenId);
    }

    function test_DeployerCanBurn() public {
        uint256 tokenId = _mintTokenToUser();
        
        // The test contract is the deployer
        issuerVerifier.burn(tokenId);
        
        assertEq(issuerVerifier.balanceOf(user), 0);
        vm.expectRevert(); // ownerOf will revert for Nonexistent ERC721 Token
        issuerVerifier.ownerOf(tokenId);
    }
}
