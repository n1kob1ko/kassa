import type { UseQueryResult } from '@tanstack/react-query';
import { Link, type To } from 'react-router';
import type { ApiError } from '../api/client';
import {
  movementKindText,
  splitVouchers,
  useVoucher,
  useVouchers,
  voucherStateText,
  type Voucher,
  type VoucherDetail,
  type VoucherList,
  type VoucherState,
} from '../api/vouchers';
import { dateText, money, signedMoney, timeText } from '../format';
import { Card } from '../ui/Card';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { PageHeader } from '../ui/PageHeader';
import { RowGroup, RowLink, RowListSkeleton } from '../ui/RowList';
import { StatusChip } from '../ui/StatusChip';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { voucherCodeText } from './receipt_payments';
import { useDetailRoute } from './useDetailRoute';
import styles from './VouchersPage.module.css';

const TONES: Record<VoucherState, 'ok' | 'off' | 'neutral'> = { active: 'ok', empty: 'neutral', voided: 'neutral', overdrawn: 'off' };

/** Der Zustand als Chip: das Wort steht immer da, "Überzogen" dazu rot. */
function StateChip({ state }: { state: VoucherState }) {
  return <StatusChip tone={TONES[state]}>{voucherStateText(state)}</StatusChip>;
}

function VoucherRows({
  label,
  vouchers,
  detailTo,
  linkState,
  openId,
}: {
  label: string;
  vouchers: Voucher[];
  detailTo: (id: string) => To;
  linkState?: unknown;
  openId: string | null;
}) {
  return (
    <RowGroup label={label}>
      {vouchers.map((v) => (
        <RowLink key={v.id} rowId={v.id} to={detailTo(v.id)} state={linkState} selected={openId === v.id} className={styles.row}>
          <span className={styles.code} data-state={v.state}>
            {voucherCodeText(v.code)}
          </span>{' '}
          <span className={styles.meta}>
            {dateText(new Date(v.createdAt))} · Wert {money(v.valueCents)}
          </span>{' '}
          <span className={styles.chip}>
            <StateChip state={v.state} />
          </span>{' '}
          <span className={styles.balance} data-state={v.state}>
            {money(v.balanceCents)}
          </span>
        </RowLink>
      ))}
    </RowGroup>
  );
}

/**
 * Oben die Summe der offenen Guthaben, darunter die echten Gutscheine (neueste zuerst), darunter in einem eigenen
 * Abschnitt die Übungs-Gutscheine. Jede Zeile führt zum Detail.
 */
export function VoucherListView({
  query,
  detailTo,
  linkState,
  openId,
}: {
  query: UseQueryResult<VoucherList, ApiError>;
  detailTo: (id: string) => To;
  linkState?: unknown;
  openId: string | null;
}) {
  if (query.isError && !query.data) return <LoadError message={query.error.message} onRetry={() => void query.refetch()} />;
  const data = query.data;
  if (!data) return <RowListSkeleton rows={6} label="Gutscheine werden geladen" />;
  if (data.vouchers.length === 0) {
    return <EmptyState title="Noch kein Gutschein." text="Sobald an der Kassa ein Gutschein verkauft wird, erscheint er hier." />;
  }
  const { real, practice } = splitVouchers(data.vouchers);
  return (
    <div className={styles.page}>
      <Card className={styles.open} aria-labelledby="gutscheine-offen">
        <h2 id="gutscheine-offen" className={styles.openLabel}>
          Offene Gutscheine
        </h2>
        <p className={styles.openAmount} data-testid="open-cents">
          {money(data.openCents)}
        </p>
        <p className={styles.openNote}>Summe aller Guthaben über 0, ohne Übungs-Gutscheine.</p>
      </Card>
      {real.length > 0 && <VoucherRows label="Gutscheine" vouchers={real} detailTo={detailTo} linkState={linkState} openId={openId} />}
      {practice.length > 0 && (
        <section className={styles.practice} aria-labelledby="gutscheine-uebung">
          <h2 id="gutscheine-uebung" className={styles.sectionTitle}>
            Übungs-Gutscheine
          </h2>
          <p className={styles.sectionNote}>Aus dem Probebetrieb, in keiner Summe.</p>
          <VoucherRows label="Übungs-Gutscheine" vouchers={practice} detailTo={detailTo} linkState={linkState} openId={openId} />
        </section>
      )}
    </div>
  );
}

/** Inhalt des Blatts eines Gutscheins: Wert, Guthaben, Zustand und jede Bewegung mit ihrem Bon. */
export function VoucherDetailView({ businessId, query }: { businessId: string; query: UseQueryResult<VoucherDetail, ApiError> }) {
  if (query.isError && !query.data) {
    return query.error.status === 404 ? (
      <p className={styles.problem}>Diesen Gutschein gibt es nicht.</p>
    ) : (
      <LoadError message={query.error.message} onRetry={() => void query.refetch()} />
    );
  }
  const v = query.data;
  if (!v) return <RowListSkeleton rows={3} label="Gutschein wird geladen" />;
  return (
    <div className={styles.detail}>
      <div className={styles.detailHead}>
        <span className={styles.detailCode}>{voucherCodeText(v.code)}</span>
        <StateChip state={v.state} />
        {v.isTest && <StatusChip tone="neutral">Übung</StatusChip>}
      </div>
      <dl className={styles.facts}>
        <div className={styles.fact}>
          <dt>Verkauft am</dt>
          <dd>{dateText(new Date(v.createdAt))}</dd>
        </div>
        <div className={styles.fact}>
          <dt>Wert</dt>
          <dd>{money(v.valueCents)}</dd>
        </div>
        <div className={styles.fact}>
          <dt>Guthaben</dt>
          <dd className={styles.balance} data-state={v.state}>
            {money(v.balanceCents)}
          </dd>
        </div>
      </dl>
      <section aria-labelledby="gutschein-bewegungen">
        <h3 id="gutschein-bewegungen" className={styles.sectionTitle}>
          Bewegungen
        </h3>
        <ul className={styles.movements} aria-label="Bewegungen">
          {v.movements.map((m) => (
            <li key={`${m.receiptId}-${m.kind}`} className={styles.movement}>
              <span className={styles.movementKind}>{movementKindText(m.kind)}</span>
              <span className={styles.movementAmount}>{signedMoney(m.amountCents)}</span>
              <span className={styles.movementMeta}>
                {dateText(new Date(m.createdAt))} {timeText(new Date(m.createdAt))} ·{' '}
                <Link to={`/b/${businessId}/bons/${encodeURIComponent(m.receiptId)}`}>Bon {m.receiptNumber}</Link>
                {m.registerName ? ` · ${m.registerName}` : ''}
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

export function VouchersPage() {
  const { detail } = useBusinessContext();
  const b = detail.business;
  const route = useDetailRoute(`/b/${b.id}/gutscheine`);
  const query = useVouchers(b.id);
  const opened = useVoucher(b.id, route.id);
  const openCode = opened.data?.code ?? query.data?.vouchers.find((v) => v.id === route.id)?.code;

  return (
    <>
      <PageHeader title="Gutscheine" subtitle={<BusinessName />} />
      <VoucherListView query={query} detailTo={route.detailTo} linkState={route.fromListState} openId={route.id} />
      <Dialog
        variant="side"
        title={openCode === undefined ? 'Gutschein' : `Gutschein ${voucherCodeText(openCode)}`}
        open={route.id !== null}
        onClose={route.close}
        returnFocus={route.rowOf}
      >
        {route.id && <VoucherDetailView businessId={b.id} query={opened} />}
      </Dialog>
    </>
  );
}
