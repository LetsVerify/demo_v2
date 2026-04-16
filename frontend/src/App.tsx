import { useState, useEffect } from 'react';
import { Shield, Key, FileCheck, RefreshCw, CheckCircle } from 'lucide-react';
import init, {
  init_panic_hook,
  setup_debug,
  keygen_debug,
  signer_sign,
  user_commit,
  user_unblind,
  pok_nizk_prove_debug,
  pok_nizk_verify,
  verify
} from 'bbs_wasm';

// Mock values from the provided demo
const MOCK_CONSTRAINTS = [
  "48305238028827234457057068308976830949311451167141786071899284143701496669988",
  "30362564611297414121344052595118041020684015714278959822893592029797294529055",
  "89017634352366059964332753369766654038457760534865200995547152036320389318152",
  "89017634352366059964332753369766654038457760534865200995547152036320389318152"
];
const MOCK_M_NULL = "192837465";
const MOCK_M_GAMMA = "987654321";
const MOCK_LAMBDA = "1122334455";

export default function App() {
  const [initDone, setInitDone] = useState(false);
  const [activeTab, setActiveTab] = useState<'user' | 'signer' | 'verifier'>('user');

  // Trusted setup
  const [params, setParams] = useState<any>(null);
  const [keys, setKeys] = useState<any>(null);
  
  // States
  const [userCommitment, setUserCommitment] = useState<any>(null);
  const [partialSig, setPartialSig] = useState<any>(null);
  const [fullSig, setFullSig] = useState<any>(null);
  const [proof, setProof] = useState<any>(null);
  const [verificationResult, setVerificationResult] = useState<boolean | null>(null);

  useEffect(() => {
    async function initWasm() {
      await init();
      init_panic_hook();
      
      // Perform Trusted Setup
      const numPublicMessages = 4;
      const totalMessages = numPublicMessages + 2;
      const p = setup_debug(totalMessages);
      const k = keygen_debug();
      
      setParams(p);
      setKeys(k);
      setInitDone(true);
    }
    initWasm();
  }, []);

  const handleUserCommit = () => {
    try {
      const commit = user_commit(MOCK_M_NULL, MOCK_M_GAMMA, MOCK_LAMBDA, params);
      setUserCommitment(commit);
    } catch(e) {
      console.error(e);
      alert("Error generating commitment");
    }
  };

  const handleSignerSign = () => {
    try {
      const sig = signer_sign(keys.sk, MOCK_CONSTRAINTS, params, userCommitment);
      setPartialSig(sig);
    } catch(e) {
      console.error(e);
      alert("Error signing");
    }
  };

  const handleUserUnblindAndProve = () => {
    try {
      const unblinded = user_unblind(partialSig, MOCK_LAMBDA);
      setFullSig(unblinded);
      
      const allMessages = [...MOCK_CONSTRAINTS, MOCK_M_NULL, MOCK_M_GAMMA];
      const isValid = verify(allMessages, unblinded, params, keys.pk);
      if(!isValid) throw new Error("Unblinded signature is invalid!");

      const numPublicMessages = 4;
      const disclosedCount = numPublicMessages + 1; // 4 + m_null
      const generatedProof = pok_nizk_prove_debug(params, keys.pk, allMessages, unblinded, disclosedCount);
      setProof(generatedProof);
    } catch(e) {
      console.error(e);
      alert("Error unblinding or proving");
    }
  };

  const handleVerifierCheck = () => {
    try {
      const numPublicMessages = 4;
      const disclosedCount = numPublicMessages + 1;
      const allMessages = [...MOCK_CONSTRAINTS, MOCK_M_NULL, MOCK_M_GAMMA];
      const disclosedMsgs = allMessages.slice(0, disclosedCount);

      const isProofValid = pok_nizk_verify(params, keys.pk, disclosedMsgs, proof);
      setVerificationResult(isProofValid);
    } catch(e) {
      console.error(e);
      setVerificationResult(false);
    }
  };


  return (
    <div className="min-h-screen container mx-auto p-4 max-w-4xl">
      <header className="py-6 mb-4 flex items-center gap-3 border-b">
        <Shield className="w-8 h-8 text-blue-600" />
        <h1 className="text-2xl font-bold">BBS+ DID Demo Platform</h1>
        {!initDone && <RefreshCw className="w-5 h-5 ml-auto animate-spin text-gray-400" />}
      </header>

      <div className="flex bg-gray-100 p-1 rounded-lg w-fit mb-6">
        <button 
          onClick={() => setActiveTab('user')}
          className={`px-4 py-2 rounded-md font-medium ${activeTab === 'user' ? 'bg-white shadow' : 'text-gray-500 hover:text-gray-700'}`}
        >
          <UserIcon /> User
        </button>
        <button 
          onClick={() => setActiveTab('signer')}
          className={`px-4 py-2 rounded-md font-medium ${activeTab === 'signer' ? 'bg-white shadow' : 'text-gray-500 hover:text-gray-700'}`}
        >
          <KeyIcon /> Signer (Mock)
        </button>
        <button 
          onClick={() => setActiveTab('verifier')}
          className={`px-4 py-2 rounded-md font-medium ${activeTab === 'verifier' ? 'bg-white shadow' : 'text-gray-500 hover:text-gray-700'}`}
        >
          <FileCheckIcon /> Verifier
        </button>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border min-h-[400px]">
        {activeTab === 'user' && (
          <div className="space-y-6">
            <h2 className="text-xl font-semibold">User Perspective</h2>
            <p className="text-gray-600">The User commits to their nullifier and blind factor before requesting a signature.</p>
            
            <div className="bg-blue-50 p-4 rounded-lg">
              <h3 className="font-semibold text-blue-800">1. Generate Commitment</h3>
              <p className="text-sm text-blue-600 mt-1 mb-3">m_null: {MOCK_M_NULL} | m_gamma: {MOCK_M_GAMMA}</p>
              <button 
                onClick={handleUserCommit}
                className="bg-blue-600 text-white px-4 py-2 rounded shadow hover:bg-blue-700 transition"
              >
                Create Commitment (C2)
              </button>
              {userCommitment && (
                <div className="mt-3 text-xs bg-white p-2 rounded border border-blue-200 break-all text-gray-700">
                  <span className="font-bold">C2 Point:</span> {JSON.stringify(userCommitment)}
                </div>
              )}
            </div>

            <div className="bg-blue-50 p-4 rounded-lg">
              <h3 className="font-semibold text-blue-800">4. Unblind & Prove</h3>
              <p className="text-sm text-blue-600 mt-1 mb-3">Requires a partial signature from the Signer (Step 3)</p>
              <button 
                onClick={handleUserUnblindAndProve}
                disabled={!partialSig}
                className="bg-blue-600 text-white px-4 py-2 rounded shadow hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Unblind Signature & Create Proof
              </button>
              {fullSig && (
                <div className="mt-3 text-xs bg-white p-2 rounded border border-blue-200 break-all text-gray-700">
                  <span className="font-bold flex items-center text-green-600 mt-1"><CheckCircle className="w-3 h-3 mr-1"/> Valid Full Signature Recovered!</span>
                </div>
              )}
              {proof && (
                <div className="mt-2 text-xs bg-white p-2 rounded border border-blue-200 break-all text-gray-700">
                  <span className="font-bold text-blue-800">Generated NIZK Proof (hiding m_gamma)</span>
                  <div className="line-clamp-3 mt-1 text-gray-500">{JSON.stringify(proof)}</div>
                </div>
              )}
            </div>
          </div>
        )}

        {activeTab === 'signer' && (
          <div className="space-y-6">
             <h2 className="text-xl font-semibold">Signer Perspective (Mock)</h2>
             <p className="text-gray-600">The Signer verifies user data off-chain and provides a partial BBS+ signature over the public constraints and user's commitment.</p>
             
             <div className="bg-purple-50 p-4 rounded-lg">
                <h3 className="font-semibold text-purple-800">3. Evaluate & Sign</h3>
                <p className="text-sm text-purple-600 mt-1 mb-3">Signer observes Constraints: <br /> [{MOCK_CONSTRAINTS.map(c => c.slice(0, 10) + '...').join(', ')}]</p>
                <button 
                  onClick={handleSignerSign}
                  disabled={!userCommitment}
                  className="bg-purple-600 text-white px-4 py-2 rounded shadow hover:bg-purple-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Generate Partial Signature
                </button>
                {partialSig && (
                  <div className="mt-3 text-xs bg-white p-2 rounded border border-purple-200 break-all text-gray-700">
                    <span className="font-bold">Partial Sig (e, A', etc):</span>
                    <div className="line-clamp-3 mt-1 text-gray-500">{JSON.stringify(partialSig)}</div>
                  </div>
                )}
             </div>
          </div>
        )}

        {activeTab === 'verifier' && (
          <div className="space-y-6">
             <h2 className="text-xl font-semibold">Verifier Perspective</h2>
             <p className="text-gray-600">Off-chain/On-chain Verifier validates the ZK Proof without seeing the user's hidden attributes (e.g. m_gamma).</p>
             
             <div className="bg-green-50 p-4 rounded-lg">
                <h3 className="font-semibold text-green-800">5. Verify Proof</h3>
                <p className="text-sm text-green-600 mt-1 mb-3">Disclosed messages: 4 Constraints + m_null</p>
                <button 
                  onClick={handleVerifierCheck}
                  disabled={!proof}
                  className="bg-green-600 text-white px-4 py-2 rounded shadow hover:bg-green-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Verify NIZK Proof
                </button>
                {verificationResult !== null && (
                  <div className={`mt-3 p-3 rounded flex items-center font-bold font-mono text-sm ${verificationResult ? 'bg-green-100 text-green-800 border border-green-300' : 'bg-red-100 text-red-800 border border-red-300'}`}>
                    {verificationResult ? <><CheckCircle className="w-5 h-5 mr-2" /> SUCCESS: Proof Valid!</> : "FAILED: Proof Invalid!"}
                  </div>
                )}
             </div>
          </div>
        )}
      </div>
    </div>
  );
}

const UserIcon = () => <svg className="w-4 h-4 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>;
const KeyIcon = () => <Key className="w-4 h-4 inline-block mr-1" />;
const FileCheckIcon = () => <FileCheck className="w-4 h-4 inline-block mr-1" />;