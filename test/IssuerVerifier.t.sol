// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBSMath.sol";
import "../src/BBSVerifier.sol";
import "../src/IssuerVerifier.sol";

contract IssuerVerifierTest is Test {
    BBSVerifier public bbsVerifier;
    IssuerVerifier public issuerVerifier;

    bytes32 public constant CTX = bytes32("LetsVerify");
    address public user = address(0x1234);
    address public relayer = address(0x5678);

    function setUp() public {
        BBSMath.G2Point memory pk = BBSMath.G2Point({
            x: [
                uint256(3260306681974474822604563648776815682816091416970286175188033719997424721292),
                21078157932976788369811386224298604876283678095953300695193627580536184663017
            ],
            y: [
                uint256(15974835493233460998260511752626128505010865937675816409903067489306439600529),
                21872932232854780648641376857253831029627783545362812619304934661720191529610
            ]
        }); // 1328790040692576325258580129229001772890358018148159309458854770206210226319
        
        BBSMath.G1Point[] memory bases = new BBSMath.G1Point[](6);
        bases[0] = BBSMath.G1Point({x: 1240703902419481545648986623473745806820787811594483762868555478458184666010, y: 18256809644617940920254137422873442228473372063501986223346572230462785524439});
        bases[1] = BBSMath.G1Point({x: 13020051060923754131228834502880722230806022247808159414293488215070332394772, y: 4529195280833079968741232889459250032235684423945803123503195484318934791269});
        bases[2] = BBSMath.G1Point({x: 16297305326858617051978407466566022015897499588105011865519416711980789611480, y: 3457763090096090198366700259693644531770479248862060079356697617968728920669});
        bases[3] = BBSMath.G1Point({x: 2253800715866524994843494300154676387161899760404330152495442103191129641090, y: 9799921154527725974487574934896288658143635125210110869057393462183450014056});
        bases[4] = BBSMath.G1Point({x: 15591676955350207499762345130216057388364340524562767442403038585836757427173, y: 366693626097570863962860699973119751999356879228643136313636147692477681999});
        bases[5] = BBSMath.G1Point({x: 21393812497764701958592826102470503271515498520329721604743009071119726253411, y: 16563212233814295780128168415970014578295470256244992910750946401593357383812});

        // Deploy pure math verifier
        bbsVerifier = new BBSVerifier(pk, bases);
        
        // Expected constraints
        uint256[] memory expectedConstraints = new uint256[](4);
        expectedConstraints[0] = 4528752285148684012564256818462280771918828852546138746521208354411044252822;
        expectedConstraints[1] = 8474321739458138899097646849860765932135651313862925479195387843221486033438;
        expectedConstraints[2] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;
        expectedConstraints[3] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;

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
            A_bar: BBSMath.G1Point(4179854549373647938910268115294581072706185687863174413170531162448041131203, 20210025142984011222056652656858926876353227415128028875057893584335833094561),
            B_bar: BBSMath.G1Point(1227402969657634430354195601747756016090133927089280083753025295027110736534, 8458497876411656801318655241350188994967206519721285737959024229403265170867),
            U: BBSMath.G1Point(17035810371453626241387371415567993318867865234729471761922831284708394104835, 99219156246168972039876991172570883884327041166160191052837059427977499355),
            s: 16018637230591439904573643880561864201630462128299484899669309922016419721602,
            t: 10582240665604962484703294327720900488520972873170677218820877890427331109089,
            u_gamma: 10372339021769194516104634340022921528470216438246179471902157948573761865541
        });

        // 3. Prepare valid constraints matching our setup expected
        uint256[] memory constraints = new uint256[](4);
        // Replace with actual generated array of constraints:
        constraints[0] = 4528752285148684012564256818462280771918828852546138746521208354411044252822;
        constraints[1] = 8474321739458138899097646849860765932135651313862925479195387843221486033438;
        constraints[2] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;
        constraints[3] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;

        // 4. Trigger verifyAndMint business logic
        vm.prank(relayer);
        issuerVerifier.verifyAndMint(proof, m_null, constraints, user);

        // 5. Assert end states
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
        constraints[0] = 4528752285148684012564256818462280771918828852546138746521208354411044252822;
        constraints[1] = 8474321739458138899097646849860765932135651313862925479195387843221486033438;
        constraints[2] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;
        constraints[3] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;

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
        constraints[0] = 4528752285148684012564256818462280771918828852546138746521208354411044252822;
        constraints[1] = 8474321739458138899097646849860765932135651313862925479195387843221486033438;
        constraints[2] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;
        constraints[3] = 1464662865008959075347130388737553683672515905673906344791000457739484483820;

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
