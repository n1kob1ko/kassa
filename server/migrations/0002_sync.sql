-- Stufe 2: Tabellen für den Abgleich (Bons, Tage, Protokoll, Berichte, Dateien, Sicherung).
-- Alle Tabellen mit Betrieb haben dieselbe Sperre wie in 0001_init.sql.

-- Gerät einer Kassa, Logo des Betriebs, Zeitzone für Tagesgrenzen
alter table registers add column device_id uuid;
alter table businesses add column logo_file_id uuid;
alter table businesses add column time_zone text not null default 'Europe/Vienna';

create table business_days (
  business_id uuid not null references businesses (id),
  id uuid not null,
  register_id uuid not null,
  device_id uuid not null,
  opened_at timestamptz not null,
  closed_at timestamptz,
  opening_float_cents int not null,
  counted_cents int,
  left_in_drawer_cents int,
  expected_cents int,
  difference_cents int,
  closed_by_name text,
  content_hash bytea not null,
  received_at timestamptz not null default now(),
  primary key (business_id, id)
);

create table cash_movements (
  business_id uuid not null references businesses (id),
  id uuid not null,
  register_id uuid not null,
  business_day_id uuid not null,
  kind text not null check (kind in ('deposit', 'withdrawal')),
  amount_cents int not null,
  reason text,
  created_at timestamptz not null,
  staff_id text not null,
  staff_name text not null,
  content_hash bytea not null,
  received_at timestamptz not null default now(),
  primary key (business_id, id)
);

-- Tag und stornierter Bon bewusst ohne Fremdschlüssel: Pakete können in beliebiger Reihenfolge ankommen.
create table receipts (
  business_id uuid not null references businesses (id),
  id uuid not null,
  register_id uuid not null,
  device_id uuid not null,
  number int not null,
  created_at timestamptz not null,
  kind text not null,
  staff_id text not null,
  staff_name text not null,
  business_day_id uuid,
  voids_receipt_id uuid,
  goods_cents int not null,
  deposit_cents int not null,
  total_cents int not null,
  payment_kind text,
  is_test boolean not null,
  content_hash bytea not null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  primary key (business_id, id)
);
create index receipts_business_created on receipts (business_id, created_at desc);
create index receipts_business_register_number on receipts (business_id, register_id, number);
-- Für "wurde dieser Bon storniert" in der Verwaltung.
create index receipts_business_voids on receipts (business_id, voids_receipt_id) where voids_receipt_id is not null;

create table receipt_lines (
  business_id uuid not null references businesses (id),
  receipt_id uuid not null,
  position int not null,
  item_id text not null,
  name text not null,
  info text,
  unit_price_cents int not null,
  quantity int not null,
  unit_deposit_cents int not null,
  gross20_cents int not null,
  gross10_cents int not null,
  gross13_cents int not null,
  gross0_cents int not null,
  gross19_cents int not null,
  options jsonb not null default '[]',
  primary key (business_id, receipt_id, position),
  foreign key (business_id, receipt_id) references receipts (business_id, id)
);

create table rksv_certificates (
  business_id uuid not null references businesses (id),
  device_id uuid not null,
  serial_hex text not null,
  certificate bytea not null,
  issuers jsonb not null default '[]',
  register_id uuid not null,
  content_hash bytea not null,
  received_at timestamptz not null default now(),
  primary key (business_id, device_id, serial_hex)
);

create table rksv_chains (
  business_id uuid not null references businesses (id),
  device_id uuid not null,
  chain int not null,
  mode text not null check (mode in ('probe', 'live')),
  cash_box_id text not null,
  zda_id text not null,
  cert_serial text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  register_id uuid not null,
  content_hash bytea not null,
  received_at timestamptz not null default now(),
  primary key (business_id, device_id, chain)
);

create table rksv_entries (
  business_id uuid not null references businesses (id),
  device_id uuid not null,
  chain int not null,
  position int not null,
  receipt_id uuid not null,
  jws text not null,
  damaged boolean not null,
  cert_serial text not null,
  register_id uuid not null,
  received_at timestamptz not null default now(),
  primary key (business_id, device_id, chain, position),
  unique (business_id, receipt_id)
);

create table reports (
  business_id uuid not null references businesses (id),
  id uuid not null,
  register_id uuid not null,
  source text not null check (source in ('device', 'server')),
  kind text not null,
  at timestamptz not null,
  app_version text,
  android_version text,
  device_model text,
  count int not null default 1,
  content jsonb not null,
  received_at timestamptz not null default now(),
  primary key (business_id, id)
);
create index reports_business_register_received on reports (business_id, register_id, received_at);

create table files (
  business_id uuid not null references businesses (id),
  id uuid not null default gen_random_uuid(),
  kind text not null check (kind in ('item_photo', 'logo')),
  storage_key text not null,
  size int,
  width int,
  height int,
  color text,
  created_at timestamptz not null default now(),
  primary key (business_id, id)
);

-- Sicherungen gehören dem ganzen Dienst, nicht einem Betrieb: keine Sperre.
create table backups (
  id bigserial primary key,
  day date not null,
  storage_key text,
  size bigint,
  ok boolean not null,
  error text,
  started_at timestamptz not null,
  finished_at timestamptz
);

-- Das Foto eines Artikels ist jetzt eine Datei der Tabelle files.
alter table items drop column photo_file;
alter table items add column photo_file_id uuid;

-- Die Sperre pro Betrieb, wie in 0001.
do $$
declare
  t text;
begin
  foreach t in array array[
    'business_days', 'cash_movements', 'receipts', 'receipt_lines',
    'rksv_certificates', 'rksv_chains', 'rksv_entries', 'reports', 'files'
  ] loop
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

-- Unveränderlich, auch für den Besitzer: die Datenbank weist es selbst ab.

create function reject_change() returns trigger
language plpgsql
as $$
begin
  raise exception '% sind unveränderlich', tg_table_name
    using errcode = 'integrity_constraint_violation';
end
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'receipts', 'receipt_lines', 'cash_movements', 'reports', 'rksv_entries', 'rksv_certificates'
  ] loop
    execute format(
      'create trigger %I before update or delete on %I for each row execute function reject_change()',
      t || '_immutable', t
    );
  end loop;
end
$$;

-- Ein Tag und eine Kette ändern sich, bis sie abgeschlossen sind; gelöscht werden sie nie.
create function reject_change_after_close() returns trigger
language plpgsql
as $$
declare
  closed_column text := tg_argv[0];
  was_closed boolean;
begin
  if tg_op = 'DELETE' then
    raise exception '% sind unveränderlich', tg_table_name
      using errcode = 'integrity_constraint_violation';
  end if;
  execute format('select ($1).%I is not null', closed_column) into was_closed using old;
  if was_closed then
    raise exception 'Ein abgeschlossener Eintrag in % ist unveränderlich', tg_table_name
      using errcode = 'integrity_constraint_violation';
  end if;
  return new;
end
$$;

create trigger business_days_immutable before update or delete on business_days
  for each row execute function reject_change_after_close('closed_at');
create trigger rksv_chains_immutable before update or delete on rksv_chains
  for each row execute function reject_change_after_close('ended_at');

-- Berichte aller Betriebe für den Anbieter. Läuft mit den Rechten des Besitzers,
-- weil die Sperre sonst jede Zeile verbirgt. Neueste zuerst nach Eingang am Server
-- (die Uhr eines Tablets kann falsch gehen). Berichte eines Pakets teilen sich received_at,
-- darum ist die Grenze für die nächste Seite das Paar (before_at, before_id) des letzten Eintrags.
create function list_reports(lim int, before_at timestamptz, before_id uuid)
returns table (
  id uuid,
  business_id uuid,
  business_name text,
  register_id uuid,
  register_name text,
  source text,
  kind text,
  at timestamptz,
  app_version text,
  android_version text,
  device_model text,
  count int,
  content jsonb,
  received_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, pg_temp
as $$
  select r.id, r.business_id, b.name, r.register_id, g.name, r.source, r.kind, r.at,
         r.app_version, r.android_version, r.device_model, r.count, r.content, r.received_at
    from public.reports r
    join public.businesses b on b.id = r.business_id
    left join public.registers g on g.business_id = r.business_id and g.id = r.register_id
   where (list_reports.before_at is null and list_reports.before_id is null)
      or (r.received_at, r.id) < (list_reports.before_at, list_reports.before_id)
   order by r.received_at desc, r.id desc
   limit list_reports.lim
$$;

revoke all on function list_reports(int, timestamptz, uuid) from public;
grant execute on function list_reports(int, timestamptz, uuid) to kassa_app;

-- Rechte für den Dienst
grant select, insert on
  receipts, receipt_lines, cash_movements, reports, rksv_certificates, rksv_entries
  to kassa_app;
grant select, insert, update on business_days, rksv_chains, backups to kassa_app;
grant select, insert, delete on files to kassa_app;
grant usage on sequence backups_id_seq to kassa_app;
