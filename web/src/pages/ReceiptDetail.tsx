import type { UseQueryResult } from '@tanstack/react-query';
import { Link, type To } from 'react-router';
import type { ApiError } from '../api/client';
import {
  discountText,
  useReceipt,
  type Payment as PaymentData,
  type ReceiptDelivery,
  type ReceiptDetail,
  type ReceiptHead,
  type ReceiptKind,
  type ReceiptLine,
} from '../api/receipts';
import { dateText, dayKey, money, timeText } from '../format';
import { Button } from '../ui/Button';
import { ChevronRightIcon } from '../ui/icons';
import { StatusChip } from '../ui/StatusChip';
import { paymentKindsText, voucherCodeText } from './receipt_payments';
import styles from './ReceiptDetail.module.css';

type LinkTarget = { to: To; state: unknown };

const DEPOSIT_RETURN_PREFIX = 'deposit-return-';

/** Ob die Zeile "Pfand zurück" ist: ihr Betrag ist ihr Pfand (mit Minus), nicht der Warenwert 0. */
const isDepositReturn = (line: ReceiptLine) => line.itemId.startsWith(DEPOSIT_RETURN_PREFIX);

/** Der Betrag einer Zeile, wie am Papier: bei "Pfand zurück" das Pfand, sonst der Warenwert. */
const lineCents = (line: ReceiptLine) =>
  isDepositReturn(line) ? line.unitDepositCents * line.quantity : line.unitPriceCents * line.quantity;

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
      <span className={styles.lineAmount}>{money(lineCents(line))}</span>
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

/** Eine Gutschein-Zahlung: "Gutschein 1234 5678" mit Betrag, darunter das Restguthaben, wie am Bon des Tablets. */
function VoucherPayment({ p }: { p: PaymentData }) {
  return (
    <dl className={styles.figures} data-testid={`payment-${p.position}`}>
      <div className={styles.figure}>
        <dt>Zahlungsart</dt>
        <dd data-testid="payment-kind">Gutschein</dd>
      </div>
      <div className={styles.figure}>
        <dt data-testid="voucher-label">{p.voucherCode ? `Gutschein ${voucherCodeText(p.voucherCode)}` : 'Gutschein'}</dt>
        <dd data-testid="voucher-amount">{money(p.amountCents)}</dd>
      </div>
      {p.voucherBalanceAfterCents !== null && (
        <div className={styles.figure}>
          <dt>Restguthaben</dt>
          <dd data-testid="voucher-balance">{money(p.voucherBalanceAfterCents)}</dd>
        </div>
      )}
    </dl>
  );
}

/** Ob der Bon eine Auszahlung oder ihr Storno ist, wie am Papier (`isPayoutReceipt`) und auf der Seite des Bons. */
const isPayout = (r: ReceiptDetail) => (r.kind === 'voided' ? r.totalCents > 0 : r.kind === 'sale' && r.totalCents < 0);

/**
 * Eine Zahlung des Bons: Art, bei mehreren oder mit Trinkgeld der Betrag (bei Karte mit Trinkgeld, so wie ihn das
 * Terminal gebucht hat, darunter "davon Trinkgeld"), bei Karte Karte und Kennung, bei bar Gegeben und Rückgeld.
 */
function Payment({ receipt, p, several }: { receipt: ReceiptDetail; p: PaymentData; several: boolean }) {
  if (p.kind === 'voucher') return <VoucherPayment p={p} />;
  const card = p.kind === 'card';
  // Eine Auszahlung (ein Verkauf mit Summe unter 0) und ihr Storno (Summe über 0) heißen wie am Papier und auf der
  // Seite "Bar ausbezahlt", ohne Gegeben und Rückgeld; der Betrag ohne Minus, beim Storno mit. Jeder andere Storno
  // liest sich wie in 1.11.0.
  if (!card && isPayout(receipt)) {
    return (
      <dl className={styles.figures} data-testid={`payment-${p.position}`}>
        <div className={styles.figure}>
          <dt>Zahlungsart</dt>
          <dd data-testid="payment-kind">Bar</dd>
        </div>
        <div className={styles.figure}>
          <dt>Bar ausbezahlt</dt>
          <dd data-testid="paid-out">{money(-p.amountCents)}</dd>
        </div>
      </dl>
    );
  }
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

/** Alle Zahlungen des Bons nach Stelle; bei mehreren steht die Zahlungsart des Bons darüber ("Gutschein + Bar"). */
function Payments({ receipt }: { receipt: ReceiptDetail }) {
  if (receipt.payments.length === 0) return null;
  const several = receipt.payments.length > 1;
  return (
    <section className={styles.section} aria-labelledby="bon-zahlung">
      <h3 id="bon-zahlung" className={styles.sectionTitle}>
        {several ? `Zahlungen · ${paymentKindsText(receipt.paymentKinds)}` : 'Zahlung'}
      </h3>
      <div className={styles.payments}>
        {receipt.payments.map((p) => (
          <Payment key={p.position} receipt={receipt} p={p} several={several} />
        ))}
      </div>
    </section>
  );
}

/** Die auf dem Bon verkauften Gutscheine mit Code und Wert. */
function SoldVouchers({ receipt }: { receipt: ReceiptDetail }) {
  if (receipt.vouchers.length === 0) return null;
  return (
    <section className={styles.section} aria-labelledby="bon-gutscheine">
      <h3 id="bon-gutscheine" className={styles.sectionTitle}>
        {receipt.vouchers.length === 1 ? 'Verkaufter Gutschein' : 'Verkaufte Gutscheine'}
      </h3>
      <dl className={styles.figures}>
        {receipt.vouchers.map((v) => (
          <div key={v.linePosition} className={styles.figure}>
            <dt data-testid="sold-voucher">Gutschein {voucherCodeText(v.code)}</dt>
            <dd data-testid="sold-voucher-value">{money(v.valueCents)}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

/** "Rechnung an": der Empfänger der Rechnung mit Name, Adresse und UID; ohne Empfänger nichts. */
function Recipient({ receipt }: { receipt: ReceiptDetail }) {
  const r = receipt.recipient;
  if (!r) return null;
  return (
    <section className={styles.section} aria-labelledby="bon-rechnung">
      <h3 id="bon-rechnung" className={styles.sectionTitle}>
        Rechnung an
      </h3>
      <address data-testid="recipient" className={styles.recipient}>
        <span>{r.name}</span>
        <span>{r.addressLine1}</span>
        <span>{r.addressLine2}</span>
        {r.vatId && <span>UID {r.vatId}</span>}
      </address>
    </section>
  );
}

/**
 * "Gedruckt 12:03" oder "Digital angeboten 12:03", in Wiener Zeit; an einem anderen Tag als dem des Bons (`receiptAt`)
 * mit Datum: "Gedruckt 28.11.2026, 09:15".
 */
export function deliveryText(d: ReceiptDelivery, receiptAt?: string): string {
  const at = new Date(d.at);
  const otherDay = receiptAt !== undefined && dayKey(at) !== dayKey(new Date(receiptAt));
  const when = otherDay ? `${dateText(at)}, ${timeText(at)}` : timeText(at);
  return `${d.kind === 'printed' ? 'Gedruckt' : 'Digital angeboten'} ${when}`;
}

/** Zeile "Beleg": wie der Beleg erteilt wurde, dazu der Weg zur Seite des Bons; ohne beides nichts. */
function Delivery({ receipt }: { receipt: ReceiptDetail }) {
  const deliveries = receipt.deliveries ?? [];
  if (deliveries.length === 0 && !receipt.pageUrl) return null;
  return (
    <section className={styles.section} aria-label="Beleg">
      <dl className={styles.figures}>
        <div className={styles.figure}>
          <dt data-testid="delivery-title">Beleg</dt>
          <dd className={styles.deliveries}>
            {deliveries.length === 0
              ? 'Noch nicht erteilt'
              : deliveries.map((d) => (
                  <span key={d.kind} data-testid="delivery">
                    {deliveryText(d, receipt.createdAt)}
                  </span>
                ))}
          </dd>
        </div>
      </dl>
      {receipt.pageUrl && (
        // Die Seite gehört nicht zur Verwaltung: ein eigener Tab, ohne Verweis zurück.
        <a className={styles.pair} data-testid="page-link" href={receipt.pageUrl} target="_blank" rel="noopener noreferrer">
          <span>Seite des Bons</span>
          <ChevronRightIcon size={18} />
        </a>
      )}
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
  // Nur das verlangte Pfand, wie am Papier; das zurückgegebene steht einmal, bei seinen Zeilen.
  const depositAskedCents = r.depositCents - r.lines.filter(isDepositReturn).reduce((sum, l) => sum + lineCents(l), 0);

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
        {depositAskedCents !== 0 && (
          <p className={styles.sumRow}>
            <span>Pfand</span>
            <span data-testid="deposit">{money(depositAskedCents)}</span>
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

      <SoldVouchers receipt={r} />

      <Recipient receipt={r} />

      <Delivery receipt={r} />

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
