import type { UseQueryResult } from '@tanstack/react-query';
import { Link, type To } from 'react-router';
import type { ApiError } from '../api/client';
import {
  discountText,
  paymentKindText,
  useReceipt,
  type Payment as PaymentData,
  type ReceiptDetail,
  type ReceiptHead,
  type ReceiptKind,
  type ReceiptLine,
} from '../api/receipts';
import { dateText, money, timeText } from '../format';
import { Button } from '../ui/Button';
import { ChevronRightIcon } from '../ui/icons';
import { StatusChip } from '../ui/StatusChip';
import styles from './ReceiptDetail.module.css';

type LinkTarget = { to: To; state: unknown };

/** Sonderbelege zeigen ihren Namen statt eines Betrags. */
export const SPECIAL_NAMES: Partial<Record<ReceiptKind, string>> = {
  start: 'Startbeleg',
  month: 'Monatsbeleg',
  year: 'Jahresbeleg',
  zero: 'Nullbeleg',
  collective: 'Sammelbeleg',
  closing: 'Schlussbeleg',
};

/** Die Merkmale eines Bons, immer als Wort. */
export function ReceiptChips({ receipt }: { receipt: Pick<ReceiptHead, 'kind' | 'test' | 'voided'> }) {
  return (
    <>
      {receipt.kind === 'voided' && <StatusChip tone="neutral">Storno</StatusChip>}{' '}
      {receipt.voided && <StatusChip tone="off">Storniert</StatusChip>}{' '}
      {receipt.test && <StatusChip tone="neutral">Testbon</StatusChip>}
    </>
  );
}

/**
 * Der Zustand der Signatur in Worten, nie die Signatur selbst. Der Server liefert `rksv: { damaged, probe }` oder
 * `null` (kein Eintrag im Protokoll): ausgefallen geht vor Probe, sonst signiert.
 */
function signatureState(rksv: ReceiptDetail['rksv']): { text: string; tone: 'ok' | 'off' | 'neutral' } | null {
  if (!rksv) return null;
  if (rksv.damaged) return { text: 'Signatur ausgefallen', tone: 'off' };
  if (rksv.probe) return { text: 'Probe', tone: 'neutral' };
  return { text: 'Signiert', tone: 'ok' };
}

/** Ein Rabatt mit Minus; am Storno-Bon (`mirror`) sein Spiegel mit Plus, wie am Tablet. */
function discountAmount(amountCents: number, mirror: boolean): string {
  return money(mirror ? Math.abs(amountCents) : -Math.abs(amountCents));
}

function Line({ line, mirror }: { line: ReceiptLine; mirror: boolean }) {
  return (
    <li className={styles.line}>
      <span className={styles.quantity}>{Math.abs(line.quantity)} ×</span>
      <span className={styles.lineName}>
        {line.name}
        {line.info && <span className={styles.lineNote}>{line.info}</span>}
        {line.options.map((o) => (
          <span key={`${o.groupName}-${o.optionName}`} className={styles.lineNote}>
            {o.groupName}: {o.optionName}
            {o.surchargeCents !== 0 && <span className={styles.surcharge}> +{money(o.surchargeCents)}</span>}
          </span>
        ))}
        {line.discount && (
          <span className={styles.lineNote} data-testid={`line-discount-${line.position}`}>
            {discountText(line.discount)} <span className={styles.surcharge}>{discountAmount(line.discount.amountCents, mirror)}</span>
          </span>
        )}
      </span>
      <span className={styles.lineAmount}>{money(line.unitPriceCents * line.quantity)}</span>
    </li>
  );
}

/** Verweis auf den anderen Bon eines Storno-Paars, mit seiner Nummer, sobald sie da ist. */
function PairLink({
  businessId,
  id,
  text,
  linkTo,
}: {
  businessId: string;
  id: string;
  text: string;
  linkTo: (id: string) => LinkTarget;
}) {
  const other = useReceipt(businessId, id);
  const target = linkTo(id);
  return (
    <Link className={styles.pair} to={target.to} state={target.state} replace>
      <span>{other.data ? `${text} ${other.data.number}` : text}</span>
      <ChevronRightIcon size={18} />
    </Link>
  );
}

/**
 * Eine Zahlung des Bons: Art, bei mehreren oder mit Trinkgeld der Betrag (bei Karte mit Trinkgeld, so wie ihn das
 * Terminal gebucht hat, darunter "davon Trinkgeld"), bei Karte Karte und Kennung, bei bar Gegeben und Rückgeld.
 */
function Payment({ receipt, p, several }: { receipt: ReceiptDetail; p: PaymentData; several: boolean }) {
  const card = p.kind === 'card';
  const tip = card ? p.tipCents : 0;
  const cardText = [p.cardScheme, p.cardLast4 ? `endet auf ${p.cardLast4}` : null].filter(Boolean).join(', ');
  return (
    <dl className={styles.figures} data-testid={`payment-${p.position}`}>
      <div className={styles.figure}>
        <dt>Zahlungsart</dt>
        <dd data-testid="payment-kind">{card ? 'Karte' : 'Bar'}</dd>
      </div>
      {(several || tip !== 0) && (
        <div className={styles.figure}>
          <dt>Betrag</dt>
          <dd data-testid="payment-amount">{money(p.amountCents + tip)}</dd>
        </div>
      )}
      {tip !== 0 && (
        <div className={styles.figure}>
          <dt>davon Trinkgeld{p.tipStaffName ? ` für ${p.tipStaffName}` : ''}</dt>
          <dd data-testid="tip">{money(tip)}</dd>
        </div>
      )}
      {card && cardText && (
        <div className={styles.figure}>
          <dt>Karte</dt>
          <dd data-testid="card">{cardText}</dd>
        </div>
      )}
      {/* Damit findet der Chef die Zahlung beim Anbieter. Zum Markieren und Kopieren. */}
      {card && p.providerTxCode && (
        <div className={styles.figure}>
          <dt>{p.provider === 'sumup' ? 'Kennung bei SumUp' : 'Kennung der Zahlung'}</dt>
          <dd data-testid="provider-tx" className={styles.txCode}>
            {p.providerTxCode}
          </dd>
        </div>
      )}
      {!card && receipt.kind === 'sale' && p.givenCents !== null && (
        <>
          <div className={styles.figure}>
            <dt>Gegeben</dt>
            <dd data-testid="given">{money(p.givenCents)}</dd>
          </div>
          <div className={styles.figure}>
            <dt>Rückgeld</dt>
            <dd data-testid="change">{money(p.changeCents ?? 0)}</dd>
          </div>
        </>
      )}
    </dl>
  );
}

/** Alle Zahlungen des Bons nach Stelle; bei mehreren steht die Zahlungsart des Bons darüber ("Bar + Karte"). */
function Payments({ receipt }: { receipt: ReceiptDetail }) {
  if (receipt.payments.length === 0) return null;
  const several = receipt.payments.length > 1;
  return (
    <section className={styles.section} aria-labelledby="bon-zahlung">
      <h3 id="bon-zahlung" className={styles.sectionTitle}>
        {several ? `Zahlungen · ${paymentKindText(receipt.paymentKind)}` : 'Zahlung'}
      </h3>
      <div className={styles.payments}>
        {receipt.payments.map((p) => (
          <Payment key={p.position} receipt={receipt} p={p} several={several} />
        ))}
      </div>
    </section>
  );
}

function DetailSkeleton() {
  return (
    <div className={styles.detail} role="status" aria-busy="true">
      <span className="visually-hidden">Bon wird geladen</span>
      <span className={[styles.bone, styles.boneMeta].join(' ')} aria-hidden="true" />
      {[0, 1, 2].map((i) => (
        <span key={i} className={[styles.bone, styles.boneLine].join(' ')} aria-hidden="true" />
      ))}
      <span className={[styles.bone, styles.boneTotal].join(' ')} aria-hidden="true" />
    </div>
  );
}

export type ReceiptDetailViewProps = {
  businessId: string;
  query: UseQueryResult<ReceiptDetail, ApiError>;
  /** Weg zu einem anderen Bon (dem Storno oder dem stornierten Bon), mit den Filtern der Liste. */
  linkTo: (id: string) => LinkTarget;
};

/** Inhalt des Blatts eines Bons. Nichts daran ist änderbar. */
export function ReceiptDetailView({ businessId, query, linkTo }: ReceiptDetailViewProps) {
  // Scheitert nur ein Neuladen, bleibt der Bon stehen.
  if (query.isError && !query.data) {
    return query.error.status === 404 ? (
      <p className={styles.problem}>Diesen Bon gibt es nicht. Prüf die Adresse.</p>
    ) : (
      <div className={styles.problemBox}>
        <p className={styles.problem}>{query.error.message}</p>
        <Button variant="secondary" onClick={() => void query.refetch()}>
          Nochmal versuchen
        </Button>
      </div>
    );
  }
  const r = query.data;
  if (!r) return <DetailSkeleton />;

  const at = new Date(r.createdAt);
  const special = SPECIAL_NAMES[r.kind];
  const signature = signatureState(r.rksv);

  return (
    <div className={styles.detail}>
      <div className={styles.head}>
        <p className={styles.meta}>
          {[`${dateText(at)}, ${timeText(at)}`, r.registerName, r.staffName].filter(Boolean).join(' · ')}
        </p>
        {(r.kind === 'voided' || r.voided || r.test) && (
          <div className={styles.chips}>
            <ReceiptChips receipt={r} />
          </div>
        )}
      </div>

      {r.lines.length > 0 && (
        <section className={styles.section} aria-labelledby="bon-zeilen">
          <h3 id="bon-zeilen" className={styles.sectionTitle}>
            Zeilen
          </h3>
          <ul className={styles.lines} aria-label="Zeilen">
            {r.lines.map((l) => (
              <Line key={l.position} line={l} mirror={r.kind === 'voided'} />
            ))}
          </ul>
        </section>
      )}

      <div className={styles.sum}>
        {r.discount && (
          <p className={styles.sumRow}>
            <span>{discountText(r.discount)}</span>
            <span data-testid="discount">{discountAmount(r.discount.amountCents, r.kind === 'voided')}</span>
          </p>
        )}
        {r.depositCents !== 0 && (
          <p className={styles.sumRow}>
            <span>Pfand</span>
            <span data-testid="deposit">{money(r.depositCents)}</span>
          </p>
        )}
        <p className={[styles.sumRow, styles.total].join(' ')}>
          <span>{special ? 'Sonderbeleg' : 'Summe'}</span>
          <span
            data-testid="total"
            className={[special ? styles.specialName : styles.totalAmount, r.voided ? styles.struck : '']
              .filter(Boolean)
              .join(' ')}
          >
            {special ?? money(r.totalCents)}
          </span>
        </p>
      </div>

      <Payments receipt={r} />

      {signature && (
        <section className={styles.section} aria-labelledby="bon-signatur">
          <h3 id="bon-signatur" className={styles.sectionTitle}>
            Signatur
          </h3>
          <span data-testid="signature" className={styles.signature}>
            <StatusChip tone={signature.tone}>{signature.text}</StatusChip>
          </span>
        </section>
      )}

      {(r.voidsReceiptId || r.voidedByReceiptId) && (
        <div className={styles.pairs}>
          {r.voidsReceiptId && (
            <PairLink businessId={businessId} id={r.voidsReceiptId} text="Zum stornierten Bon" linkTo={linkTo} />
          )}
          {r.voidedByReceiptId && (
            <PairLink businessId={businessId} id={r.voidedByReceiptId} text="Zum Storno-Bon" linkTo={linkTo} />
          )}
        </div>
      )}
    </div>
  );
}
