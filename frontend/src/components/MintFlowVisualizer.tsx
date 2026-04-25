import { CheckCircle2, Circle, Loader2, XCircle } from 'lucide-react';

export type FlowStepStatus = 'idle' | 'active' | 'done' | 'error' | 'skipped';

export type MintFlowStep = {
  title: string;
  detail: string;
  lane: string;
};

export const MINT_FLOW_STEPS: MintFlowStep[] = [
  {
    title: 'Read Constraints On-chain',
    detail: 'User -> Dapp',
    lane: 'Reading on-chain context and wallet state'
  },
  {
    title: 'Stash Nullifier',
    detail: 'User -> Dapp',
    lane: 'Submitting stashNullifier(bytes32)'
  },
  {
    title: 'Generate Commitment',
    detail: 'User local step',
    lane: 'Create user commitment from m_null / m_gamma / lambda'
  },
  {
    title: 'Apply Partial Signature',
    detail: 'User -> Third-Party KYC (Local mock)',
    lane: 'Mock signer applies a partial signature'
  },
  {
    title: 'Unblind Signature',
    detail: 'User local step',
    lane: 'Recover full signature and verify locally'
  },
  {
    title: 'Generate NIZK Proof',
    detail: 'User local step',
    lane: 'Build proof and validate locally before submitting'
  },
  {
    title: 'Submit verifyAndMint',
    detail: 'User -> Dapp',
    lane: 'Submitting verifyAndMint(...) transaction'
  },
  {
    title: 'Mint Success',
    detail: 'Dapp -> User',
    lane: 'Fetch tokenURI, metadata, and image'
  }
];

type MintFlowVisualizerProps = {
  visible: boolean;
  statuses: FlowStepStatus[];
};

function getStepIcon(status: FlowStepStatus) {
  if (status === 'done') {
    return <CheckCircle2 size={16} />;
  }
  if (status === 'active') {
    return <Loader2 size={16} className="spin" />;
  }
  if (status === 'error') {
    return <XCircle size={16} />;
  }
  return <Circle size={16} />;
}

export default function MintFlowVisualizer({ visible, statuses }: MintFlowVisualizerProps) {
  if (!visible) {
    return null;
  }

  return (
    <section className="flow-panel">
      <h2>Live Mint Flow</h2>
      <p className="muted">The timeline below is synchronized with the real execution path triggered by Start Mint.</p>

      <div className="flow-grid">
        {MINT_FLOW_STEPS.map((step, idx) => {
          const status = statuses[idx] ?? 'idle';
          const statusClass = `flow-step ${status}`;
          const statusLabel = status === 'idle' ? 'Pending' : status === 'active' ? 'Running' : status === 'done' ? 'Done' : status === 'skipped' ? 'Skipped' : 'Failed';

          return (
            <article className={statusClass} key={step.title}>
              <div className="flow-step-head">
                <div className="flow-step-badge">#{idx + 1}</div>
                <div className="flow-step-title-wrap">
                  <h3>{step.title}</h3>
                  <span className="flow-status-tag">{statusLabel}</span>
                </div>
                <div className="flow-step-icon">{getStepIcon(status)}</div>
              </div>
              <p className="flow-step-detail">{step.detail}</p>
              <p className="flow-step-lane">{step.lane}</p>
            </article>
          );
        })}
      </div>
    </section>
  );
}
