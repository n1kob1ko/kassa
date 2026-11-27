-- Stufe 1b: Bon v: 3 mit Gutscheinen, Pfand zurück und dem Schlüssel der öffentlichen Seite.
-- payment_kind kennt dazu 'voucher' (nur mit Gutschein bezahlt); zahlen zwei Arten, steht 'mixed'.

-- Alte Bons behalten 0 und keinen Schlüssel: ADD COLUMN mit Vorgabe ändert keine Zeile, der Trigger receipts_immutable bleibt an.
alter table receipts add column voucher_cents int not null default 0, add column voucher_sale_cents int not null default 0,
                     add column deposit_return_cents int not null default 0, add column public_token text;

-- Der Schlüssel der öffentlichen Seite eines Bons. Bewusst ohne Zeilen-Schutz je Betrieb: die Seite sucht ohne Anmeldung
-- nach dem Schlüssel, der Schlüssel ist das Geheimnis.
create table receipt_links (
  token text primary key,
  business_id uuid not null references businesses (id),
  receipt_id uuid not null,
  foreign key (business_id, receipt_id) references receipts (business_id, id)
);

-- Ein Gutschein, angelegt aus dem Bon, der ihn verkauft hat. Das Guthaben ergibt sich aus den Bewegungen.
create table vouchers (
  business_id uuid not null references businesses (id),
  id uuid not null,
  code text not null,
  value_cents int not null,
  created_at timestamptz not null,
  is_test boolean not null,
  sold_receipt_id uuid,
  register_id uuid not null,
  change_seq bigint not null,
  primary key (business_id, id)
);
create index vouchers_business_code on vouchers (business_id, code);

-- Eine Bewegung am Guthaben, höchstens eine je Gutschein und Bon. Bewusst ohne Fremdschlüssel auf vouchers: eine Einlösung
-- kann vor dem Verkauf ankommen (andere Kassa), der signierte Bon gilt trotzdem.
create table voucher_movements (
  business_id uuid not null references businesses (id),
  voucher_id uuid not null,
  receipt_id uuid not null,
  kind text not null check (kind in ('sale', 'redeem', 'void_sale', 'void_redeem')),
  amount_cents int not null,
  created_at timestamptz not null,
  change_seq bigint not null,
  primary key (business_id, voucher_id, receipt_id),
  foreign key (business_id, receipt_id) references receipts (business_id, id)
);

-- Firmenkunden für die Rechnung.
create table customers (
  business_id uuid not null references businesses (id),
  id uuid not null,
  name text not null,
  address_line1 text not null,
  address_line2 text not null,
  vat_id text,
  archived boolean not null default false,
  updated_at timestamptz not null,
  change_seq bigint not null,
  primary key (business_id, id)
);

-- Empfänger der Rechnung zu einem Bon, eine Zeile je Fassung. Ohne Fremdschlüssel: Pakete können in beliebiger
-- Reihenfolge ankommen.
create table receipt_recipients (
  business_id uuid not null references businesses (id),
  receipt_id uuid not null,
  version int not null,
  customer_id uuid,
  name text not null,
  address_line1 text not null,
  address_line2 text not null,
  vat_id text,
  created_at timestamptz not null,
  staff_id text not null,
  staff_name text not null,
  primary key (business_id, receipt_id, version)
);

-- Wie der Beleg zu einem Bon erteilt wurde, eine Zeile je Art.
create table receipt_deliveries (
  business_id uuid not null references businesses (id),
  receipt_id uuid not null,
  kind text not null check (kind in ('printed', 'digital')),
  at timestamptz not null,
  primary key (business_id, receipt_id, kind)
);

-- Die Sperre pro Betrieb, wie in 0002 (nicht für receipt_links, siehe oben).
do $$
declare
  t text;
begin
  foreach t in array array['vouchers', 'voucher_movements', 'customers', 'receipt_recipients', 'receipt_deliveries'] loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
    execute format(
      $p$create policy business_isolation on %I for all
           using (business_id = nullif(current_setting('app.business_id', true), '')::uuid)
           with check (business_id = nullif(current_setting('app.business_id', true), '')::uuid)$p$,
      t
    );
  end loop;
end
$$;

-- Nur anfügen: derselbe Trigger wie bei receipts.
do $$
declare
  t text;
begin
  foreach t in array array['receipt_links', 'voucher_movements', 'receipt_recipients', 'receipt_deliveries'] loop
    execute format(
      'create trigger %I before update or delete on %I for each row execute function reject_change()',
      t || '_immutable', t
    );
  end loop;
end
$$;

-- Rechte für den Dienst
grant select, insert on receipt_links, vouchers, voucher_movements, receipt_recipients, receipt_deliveries to kassa_app;
grant select, insert, update on customers to kassa_app;
