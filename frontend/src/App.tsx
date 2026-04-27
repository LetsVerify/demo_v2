import { useEffect, useMemo, useState } from 'react';
import { ethers } from 'ethers';
import { AlertTriangle, CheckCircle2, ChevronDown, Loader2, Shield, Wallet } from 'lucide-react';
import MintFlowVisualizer, { FlowStepStatus, MINT_FLOW_STEPS } from './components/MintFlowVisualizer';
import init, {
  init_panic_hook,
  keygen_debug,
  pok_nizk_prove_debug,
  pok_nizk_verify,
  setup_debug,
  signer_sign_debug,
  user_commit,
  user_unblind,
  verify
} from 'bbs_wasm';

const ISSUER_VERIFIER_ADDRESS = '0x8D9d696193C04E4d9CfeBD01f522862A88202AC3';
const REQUIRED_CHAIN_ID = 11155111;

const CTX = 'LetsVerify';
const PRIVACY_STATEMENT =
  'Your personal data is verified by KYC constraints (Age > 18, Country = US, Authorized = true), while the KYC provider cannot see where this signature is used.';
const DEFAULT_M_NULL = '192837465';
const M_GAMMA = '987654321';
const LAMBDA = '1122334455';
const CONSTRAINTS = [
  '4528752285148684012564256818462280771918828852546138746521208354411044252822', // Age > 18
  '8474321739458138899097646849860765932135651313862925479195387843221486033438', // Country = US
  '1464662865008959075347130388737553683672515905673906344791000457739484483820', // Authorized = true
  '1464662865008959075347130388737553683672515905673906344791000457739484483820'  // empty message
];

const ISSUER_VERIFIER_ABI = [
  'event Issued(address indexed from,address indexed to,uint256 indexed tokenId,uint8 burnAuth)',
  'function deployer() external view returns (address)',
  'function stashNullifier(bytes32 N) external',
  'function removeNullifier(bytes32 N) external',
  'function burn(uint256 tokenId) external',
  'function verifyAndMint((tuple(uint256 x,uint256 y) A_bar,tuple(uint256 x,uint256 y) B_bar,tuple(uint256 x,uint256 y) U,uint256 s,uint256 t,uint256 u_gamma) proof,uint256 m_null,uint256[] constraints,address userAddr) external',
  'function tokenURI(uint256 tokenId) external view returns (string)',
  'function keyExist(bytes32 N) external view returns (bool)',
  'function hasToken(address user) external view returns (bool)'
];

type Metadata = {
  name?: string;
  description?: string;
  image?: string;
  external_url?: string;
};

type WasmProof = {
  A_bar: { x: string; y: string };
  B_bar: { x: string; y: string };
  U: { x: string; y: string };
  s: string;
  t: string;
  u_i: string[];
};

type ContractProof = {
  A_bar: { x: bigint; y: bigint };
  B_bar: { x: bigint; y: bigint };
  U: { x: bigint; y: bigint };
  s: bigint;
  t: bigint;
  u_gamma: bigint;
};

type MintState = {
  tokenId?: string;
  tokenUri?: string;
  metadata?: Metadata;
  imageUrl?: string;
  stashTx?: string;
  mintTx?: string;
};

declare global {
  interface Window {
    ethereum?: ethers.Eip1193Provider;
  }
}

function shortHash(value: string): string {
  if (value.length <= 14) {
    return value;
  }
  return `${value.slice(0, 8)}...${value.slice(-6)}`;
}

function normalizeIpfsUrl(uri: string): string {
  if (uri.startsWith('ipfs://')) {
    return `https://ipfs.io/ipfs/${uri.slice('ipfs://'.length)}`;
  }
  return uri;
}

function parseRpcError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return 'Unknown error';
}

function toContractProof(proof: WasmProof): ContractProof {
  if (!proof.u_i || proof.u_i.length === 0) {
    throw new Error('proof.u_i is empty and cannot be mapped to on-chain field u_gamma');
  }

  return {
    A_bar: { x: BigInt(proof.A_bar.x), y: BigInt(proof.A_bar.y) },
    B_bar: { x: BigInt(proof.B_bar.x), y: BigInt(proof.B_bar.y) },
    U: { x: BigInt(proof.U.x), y: BigInt(proof.U.y) },
    s: BigInt(proof.s),
    t: BigInt(proof.t),
    u_gamma: BigInt(proof.u_i[0])
  };
}

async function resolveTokenIdForUser(issuerVerifier: ethers.Contract, userAddress: string, mNull: string): Promise<string> {
  try {
    const issuedFilter = issuerVerifier.filters.Issued(null, userAddress);
    const logs = await issuerVerifier.queryFilter(issuedFilter, 0, 'latest');
    if (logs.length > 0) {
      const lastLog = logs[logs.length - 1];
      if ('args' in lastLog && lastLog.args && lastLog.args.tokenId !== undefined) {
        return lastLog.args.tokenId.toString();
      }
    }
  } catch {
    // Fallback below
  }

  // Demo fallback: if no Issued log was fetched, derive the deterministic tokenId from m_null.
  return ethers.keccak256(ethers.solidityPacked(['address', 'uint256'], [userAddress, BigInt(mNull)]));
}

async function loadMintStateByTokenId(issuerVerifier: ethers.Contract, tokenId: string): Promise<Pick<MintState, 'tokenUri' | 'metadata' | 'imageUrl'>> {
  const tokenUri: string = await issuerVerifier.tokenURI(tokenId);
  const metadataUrl = normalizeIpfsUrl(tokenUri);
  const metadataResp = await fetch(metadataUrl);
  if (!metadataResp.ok) {
    throw new Error(`Failed to fetch metadata, HTTP ${metadataResp.status}`);
  }
  const metadata = (await metadataResp.json()) as Metadata;
  const imageUrl = metadata.image ? normalizeIpfsUrl(metadata.image) : '';

  return {
    tokenUri,
    metadata,
    imageUrl
  };
}

export default function App() {
  const [wasmReady, setWasmReady] = useState(false);
  const [walletAddress, setWalletAddress] = useState<string>('');
  const [statusText, setStatusText] = useState<string>('Waiting for wallet connection');
  const [errorText, setErrorText] = useState<string>('');
  const [isWorking, setIsWorking] = useState(false);
  const [userMNull, setUserMNull] = useState<string>(DEFAULT_M_NULL);
  const [mintState, setMintState] = useState<MintState>({});
  const [adminNullifierHash, setAdminNullifierHash] = useState('');
  const [adminTokenId, setAdminTokenId] = useState('');
  const [adminMessage, setAdminMessage] = useState('');
  const [adminError, setAdminError] = useState('');
  const [adminBusy, setAdminBusy] = useState(false);
  const [adminOpen, setAdminOpen] = useState(false);
  const [flowVisible, setFlowVisible] = useState(false);
  const [flowStatuses, setFlowStatuses] = useState<FlowStepStatus[]>(() => MINT_FLOW_STEPS.map(() => 'idle'));

  const [params, setParams] = useState<any>(null);
  const [keys, setKeys] = useState<any>(null);

  const isWalletConnected = useMemo(() => walletAddress.length > 0, [walletAddress]);

  function resetFlowStatuses(): void {
    setFlowVisible(true);
    setFlowStatuses(MINT_FLOW_STEPS.map(() => 'idle'));
  }

  function updateFlowStatus(stepIndex: number, status: FlowStepStatus): void {
    setFlowStatuses((prev) => prev.map((item, idx) => (idx === stepIndex ? status : item)));
  }

  function markFlowRange(status: FlowStepStatus, from: number, to: number): void {
    setFlowStatuses((prev) => prev.map((item, idx) => (idx >= from && idx <= to ? status : item)));
  }

  useEffect(() => {
    async function setupWasm() {
      await init();
      init_panic_hook();

      const numPublicMessages = 4;
      const totalMessages = numPublicMessages + 2;
      setParams(setup_debug(totalMessages));
      setKeys(keygen_debug());
      setWasmReady(true);
    }

    setupWasm().catch((err) => {
      setErrorText(`WASM initialization failed: ${parseRpcError(err)}`);
    });
  }, []);

  async function connectWallet(): Promise<void> {
    setErrorText('');
    if (!window.ethereum) {
      setErrorText('Wallet not detected. Please install MetaMask first.');
      return;
    }

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const network = await provider.getNetwork();

    if (Number(network.chainId) !== REQUIRED_CHAIN_ID) {
      setErrorText(`Please switch to Sepolia (chainId=${REQUIRED_CHAIN_ID})`);
      return;
    }

    setWalletAddress(await signer.getAddress());
    setStatusText('Wallet connected. Ready to run the real mint flow');
  }

  async function runMintFlow(): Promise<void> {
    setErrorText('');
    resetFlowStatuses();
    setStatusText('Generating proof and preparing on-chain transactions...');

    if (!window.ethereum) {
      setErrorText('Wallet not detected. Please install MetaMask first.');
      return;
    }
    if (!wasmReady || !params || !keys) {
      setErrorText('WASM is not initialized yet. Please try again in a moment.');
      return;
    }

    setIsWorking(true);
    let activeStep = 0;

    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const userAddress = await signer.getAddress();
      const network = await provider.getNetwork();

      if (Number(network.chainId) !== REQUIRED_CHAIN_ID) {
        throw new Error(`Please switch to Sepolia (chainId=${REQUIRED_CHAIN_ID})`);
      }

      const issuerVerifier = new ethers.Contract(ISSUER_VERIFIER_ADDRESS, ISSUER_VERIFIER_ABI, signer);
      const currentMNull = userMNull.trim();
      if (!currentMNull) {
        throw new Error('M_NULL is required.');
      }

      activeStep = 0;
      updateFlowStatus(activeStep, 'active');
      setStatusText('1/8 Reading constraints and on-chain context...');
      const alreadyMinted = await issuerVerifier.hasToken(userAddress);
      updateFlowStatus(activeStep, 'done');

      const tokenId = ethers.keccak256(ethers.solidityPacked(['address', 'uint256'], [userAddress, BigInt(currentMNull)]));
      const nullifierHash = tokenId;

      if (alreadyMinted) {
        markFlowRange('skipped', 1, 6);
        activeStep = 7;
        updateFlowStatus(activeStep, 'active');
        setStatusText('Token already found for this address. Querying tokenId and metadata...');
        const existingTokenId = await resolveTokenIdForUser(issuerVerifier, userAddress, currentMNull);
        const existingTokenState = await loadMintStateByTokenId(issuerVerifier, existingTokenId);

        setMintState({
          tokenId: existingTokenId,
          tokenUri: existingTokenState.tokenUri,
          metadata: existingTokenState.metadata,
          imageUrl: existingTokenState.imageUrl,
          stashTx: '',
          mintTx: ''
        });
        updateFlowStatus(activeStep, 'done');
        setStatusText('Token already exists. Loaded on-chain metadata and image directly.');
        return;
      }

      activeStep = 1;
      updateFlowStatus(activeStep, 'active');
      setStatusText('2/8 Stashing nullifier on-chain...');
      const alreadyStashed = await issuerVerifier.keyExist(nullifierHash);
      let stashTxHash = '';
      if (!alreadyStashed) {
        const stashTx = await issuerVerifier.stashNullifier(nullifierHash);
        await stashTx.wait();
        stashTxHash = stashTx.hash;
      }
      updateFlowStatus(activeStep, 'done');

      activeStep = 2;
      updateFlowStatus(activeStep, 'active');
      setStatusText('3/8 Generating user commitment...');
      const commitment = user_commit(currentMNull, M_GAMMA, LAMBDA, params);
      updateFlowStatus(activeStep, 'done');

      activeStep = 3;
      updateFlowStatus(activeStep, 'active');
      setStatusText('4/8 Applying partial signature with local mock KYC...');
      const partialSig = signer_sign_debug(keys.sk, CONSTRAINTS, params, commitment);
      updateFlowStatus(activeStep, 'done');

      activeStep = 4;
      updateFlowStatus(activeStep, 'active');
      setStatusText('5/8 Unblinding full signature...');
      const fullSig = user_unblind(partialSig, LAMBDA);
      const allMessages = [...CONSTRAINTS, currentMNull, M_GAMMA];
      const fullSigValid = verify(allMessages, fullSig, params, keys.pk);
      if (!fullSigValid) {
        throw new Error('Local signature validation failed. Transaction aborted.');
      }
      updateFlowStatus(activeStep, 'done');

      activeStep = 5;
      updateFlowStatus(activeStep, 'active');
      setStatusText('6/8 Generating NIZK proof...');
      const disclosedCount = CONSTRAINTS.length + 1;
      const proof = pok_nizk_prove_debug(CTX, params, keys.pk, allMessages, fullSig, disclosedCount) as WasmProof;
      const disclosedMessages = allMessages.slice(0, disclosedCount);
      const proofValid = pok_nizk_verify(CTX, params, keys.pk, disclosedMessages, proof);
      if (!proofValid) {
        throw new Error('Local NIZK validation failed. Transaction aborted.');
      }
      const contractProof = toContractProof(proof);
      updateFlowStatus(activeStep, 'done');

      activeStep = 6;
      updateFlowStatus(activeStep, 'active');
      setStatusText('7/8 Submitting verifyAndMint transaction...');
      const mintTx = await issuerVerifier.verifyAndMint(contractProof, BigInt(currentMNull), CONSTRAINTS.map((v) => BigInt(v)), userAddress);
      await mintTx.wait();
      updateFlowStatus(activeStep, 'done');

      activeStep = 7;
      updateFlowStatus(activeStep, 'active');
      setStatusText('8/8 Finalizing and loading token metadata...');
      const mintedTokenState = await loadMintStateByTokenId(issuerVerifier, tokenId);

      setMintState({
        tokenId,
        tokenUri: mintedTokenState.tokenUri,
        metadata: mintedTokenState.metadata,
        imageUrl: mintedTokenState.imageUrl,
        stashTx: stashTxHash,
        mintTx: mintTx.hash
      });
      updateFlowStatus(activeStep, 'done');

      setStatusText('Mint succeeded. Metadata and image loaded.');
    } catch (err) {
      setErrorText(parseRpcError(err));
      setStatusText('Flow failed. Please check parameters, network, and on-chain state based on the error.');
      if (activeStep >= 0) {
        updateFlowStatus(activeStep, 'error');
      }
    } finally {
      setIsWorking(false);
    }
  }

  async function removeNullifierAdmin(): Promise<void> {
    setAdminError('');
    setAdminMessage('');

    if (!window.ethereum) {
      setAdminError('Wallet not detected. Please install MetaMask first.');
      return;
    }
    if (!ethers.isHexString(adminNullifierHash, 32)) {
      setAdminError('Invalid nullifier hash. Please provide a bytes32 hex value (0x + 64 hex chars).');
      return;
    }

    setAdminBusy(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const network = await provider.getNetwork();
      if (Number(network.chainId) !== REQUIRED_CHAIN_ID) {
        throw new Error(`Please switch to Sepolia (chainId=${REQUIRED_CHAIN_ID})`);
      }

      const issuerVerifier = new ethers.Contract(ISSUER_VERIFIER_ADDRESS, ISSUER_VERIFIER_ABI, signer);
      const tx = await issuerVerifier.removeNullifier(adminNullifierHash);
      setAdminMessage(`removeNullifier submitted: ${tx.hash}`);
      await tx.wait();
      setAdminMessage(`removeNullifier succeeded: ${tx.hash}`);
    } catch (err) {
      setAdminError(parseRpcError(err));
    } finally {
      setAdminBusy(false);
    }
  }

  async function burnTokenAdmin(): Promise<void> {
    setAdminError('');
    setAdminMessage('');

    if (!window.ethereum) {
      setAdminError('Wallet not detected. Please install MetaMask first.');
      return;
    }
    if (!adminTokenId.trim()) {
      setAdminError('Token ID is required.');
      return;
    }

    setAdminBusy(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const network = await provider.getNetwork();
      if (Number(network.chainId) !== REQUIRED_CHAIN_ID) {
        throw new Error(`Please switch to Sepolia (chainId=${REQUIRED_CHAIN_ID})`);
      }

      const issuerVerifier = new ethers.Contract(ISSUER_VERIFIER_ADDRESS, ISSUER_VERIFIER_ABI, signer);
      const signerAddress = await signer.getAddress();
      const deployer: string = await issuerVerifier.deployer();
      if (signerAddress.toLowerCase() !== deployer.toLowerCase()) {
        throw new Error(`Only deployer can burn. Connected wallet: ${signerAddress}`);
      }

      const tokenId = BigInt(adminTokenId.trim());
      const tx = await issuerVerifier.burn(tokenId);
      setAdminMessage(`burn submitted: ${tx.hash}`);
      await tx.wait();
      setAdminMessage(`burn succeeded: ${tx.hash}`);
    } catch (err) {
      setAdminError(parseRpcError(err));
    } finally {
      setAdminBusy(false);
    }
  }

  return (
    <div className="app-shell">
      <div className="bg-orb orb-left" />
      <div className="bg-orb orb-right" />

      <main className="panel">
        <header className="hero">
          <div className="hero-icon-wrap">
            <Shield className="hero-icon" />
          </div>
          <div>
            <h1>LetsVerify Mint Console</h1>
            <p className="subtitle">
              Proejct URL: <a href="http://github.com/letsverify">http://github.com/letsverify</a>            
            </p>
            <p className="privacy-note">{PRIVACY_STATEMENT}</p>
          </div>
        </header>

        <section className="action-grid">
          <article className="card">
            <h2>Wallet and Network</h2>
            <p className="muted">You must connect a Sepolia wallet before running the real mint flow.</p>
            <div className="user-setting">
              <label htmlFor="user-m-null">M_NULL</label>
              <input
                id="user-m-null"
                className="user-input"
                value={userMNull}
                onChange={(e) => setUserMNull(e.target.value.trim())}
                disabled={isWorking}
                inputMode="numeric"
              />
              <p className="setting-hint">Default value is preserved until you change it.</p>
            </div>
            <button className="btn btn-secondary" onClick={connectWallet} disabled={isWorking}>
              <Wallet size={16} />
              {isWalletConnected ? 'Wallet Connected' : 'Connect MetaMask'}
            </button>
            <div className="kv-list">
              <div>
                <span>Chain</span>
                <b>Sepolia ({REQUIRED_CHAIN_ID})</b>
              </div>
              <div>
                <span>Contract</span>
                <b>{shortHash(ISSUER_VERIFIER_ADDRESS)}</b>
              </div>
              <div>
                <span>Address</span>
                <b>{walletAddress ? shortHash(walletAddress) : 'Not connected'}</b>
              </div>
            </div>
          </article>

          <article className="card card-primary">
            <h2>Run Real Flow in One Click</h2>
            <p className="muted">commit -{'>'} signer sign -{'>'} unblind -{'>'} prove -{'>'} stashNullifier -{'>'} verifyAndMint</p>
            <button
              className="btn btn-primary"
              onClick={runMintFlow}
              disabled={!isWalletConnected || !wasmReady || isWorking}
            >
              {isWorking ? <Loader2 size={16} className="spin" /> : <CheckCircle2 size={16} />}
              {isWorking ? 'Running...' : 'Start Mint'}
            </button>
            <p className="status-text">{statusText}</p>
            {!wasmReady && <p className="muted">WASM is initializing...</p>}
            {errorText && (
              <div className="error-box">
                <AlertTriangle size={18} />
                <span>{errorText}</span>
              </div>
            )}
          </article>
        </section>

        <section className="admin-panel">
          <article className="card admin-card">
            <button
              className="admin-toggle"
              type="button"
              onClick={() => setAdminOpen((prev) => !prev)}
              aria-expanded={adminOpen}
            >
              <h2>Admin Panel</h2>
              <span className="admin-toggle-right">
                {adminOpen ? 'Collapse' : 'Expand'}
                <ChevronDown size={16} className={adminOpen ? 'admin-chevron open' : 'admin-chevron'} />
              </span>
            </button>

            {adminOpen && (
              <>
                <p className="muted">Contract-level admin actions: delete a nullifier or burn an existing token.</p>

                <div className="admin-row">
                  <label htmlFor="nullifier-hash">Delete Nullifier (bytes32)</label>
                  <div className="admin-input-wrap">
                    <input
                      id="nullifier-hash"
                      className="admin-input"
                      placeholder="0x..."
                      value={adminNullifierHash}
                      onChange={(e) => setAdminNullifierHash(e.target.value.trim())}
                      disabled={adminBusy}
                    />
                    <button
                      className="btn btn-secondary"
                      onClick={removeNullifierAdmin}
                      disabled={!isWalletConnected || adminBusy}
                    >
                      {adminBusy ? 'Processing...' : 'Delete Nullifier'}
                    </button>
                  </div>
                </div>

                <div className="admin-row">
                  <label htmlFor="burn-token">Burn Token (tokenId)</label>
                  <div className="admin-input-wrap">
                    <input
                      id="burn-token"
                      className="admin-input"
                      placeholder="Decimal or 0x tokenId"
                      value={adminTokenId}
                      onChange={(e) => setAdminTokenId(e.target.value)}
                      disabled={adminBusy}
                    />
                    <button
                      className="btn btn-secondary"
                      onClick={burnTokenAdmin}
                      disabled={!isWalletConnected || adminBusy}
                    >
                      {adminBusy ? 'Processing...' : 'Burn Token'}
                    </button>
                  </div>
                </div>

                {adminMessage && <p className="admin-success">{adminMessage}</p>}
                {adminError && (
                  <div className="error-box admin-error">
                    <AlertTriangle size={18} />
                    <span>{adminError}</span>
                  </div>
                )}
              </>
            )}
          </article>
        </section>

        <MintFlowVisualizer visible={flowVisible} statuses={flowStatuses} />

        <section className="result">
          <h2>Mint Result</h2>
          {!mintState.tokenId && <p className="muted">No token to display yet. After a successful mint, or after auto-loading an existing token, metadata and image will appear here.</p>}

          {mintState.tokenId && (
            <div className="result-grid">
              <article className="card">
                <h3>On-chain Result</h3>
                <div className="kv-list">
                  <div>
                    <span>Token ID</span>
                    <b className="wrap">{mintState.tokenId}</b>
                  </div>
                  <div>
                    <span>Stash Tx</span>
                    <b className="wrap">{mintState.stashTx || 'Already stashed earlier, not submitted again'}</b>
                  </div>
                  <div>
                    <span>Mint Tx</span>
                    <b className="wrap">{mintState.mintTx || 'No mint submitted this time, existing token loaded'}</b>
                  </div>
                  <div>
                    <span>Token URI</span>
                    <b className="wrap">{mintState.tokenUri}</b>
                  </div>
                </div>
              </article>

              <article className="card nft-card">
                <h3>Metadata and Image</h3>
                {mintState.imageUrl ? (
                  <img src={mintState.imageUrl} alt={mintState.metadata?.name || 'Minted token'} className="nft-image" />
                ) : (
                  <div className="img-placeholder">No image field found in metadata</div>
                )}
                <div className="meta-text">
                  <p>
                    <span>Name: </span>
                    {mintState.metadata?.name || 'N/A'}
                  </p>
                  <p>
                    <span>Description: </span>
                    {mintState.metadata?.description || 'N/A'}
                  </p>
                  <p>
                    <span>External URL: </span>
                    {mintState.metadata?.external_url || 'N/A'}
                  </p>
                </div>
              </article>
            </div>
          )}
        </section>
      </main>
    </div>
  );
}