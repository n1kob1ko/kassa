-- Alle Tabellen des Servers und die Sperre pro Betrieb.
-- Besitzer bleibt die Rolle aus DATABASE_URL. Der Dienst arbeitet als kassa_app und
-- sieht in den gesperrten Tabellen nur die Zeilen des Betriebs aus app.business_id.

-- Fortlaufende Änderungs-Nummer für alle Betriebe. Nur in withBusinessWrite ziehen.
create sequence change_seq;

-- Tabellen ohne Sperre (System)

create table businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address_lines text[] not null default '{}',
  vat_id text,
  receipt_footer text,
  change_seq bigint not null,
  created_at timestamptz not null default now()
);

create table users (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  -- Leer, bis der Chef sein Passwort über den Einmal-Link setzt.
  password_hash text,
  role text not null check (role in ('provider', 'chef')),
  business_id uuid references businesses (id),
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  -- Ein Chef gehört zu genau einem Betrieb, ein Anbieter zu keinem.
  constraint users_business_by_role check ((role = 'chef') = (business_id is not null))
);
create unique index users_email_lower on users (lower(email));

create table sessions (
  id_hash bytea primary key,
  user_id uuid not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index sessions_user_id on sessions (user_id);

create table used_secrets (
  secret_hash bytea primary key,
  used_at timestamptz not null default now()
);

create table login_failures (
  email_hash bytea not null,
  at timestamptz not null default now()
);
create index login_failures_email_hash_at on login_failures (email_hash, at);

create table audit_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  user_id uuid,
  business_id uuid,
  action text not null,
  detail jsonb not null default '{}'
);

create table releases (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  build int not null,
  file_key text not null,
  sha256 text not null,
  size bigint not null,
  link_secret text not null unique,
  uploaded_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  unique (version, build)
);

-- Tabellen mit Sperre pro Betrieb

create table registers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id),
  name text not null,
  token_hash bytea not null unique,
  paired_at timestamptz not null default now(),
  last_seen_at timestamptz,
  app_version text,
  device_model text,
  blocked_at timestamptz
);
create index registers_business_id on registers (business_id);

create table pairing_codes (
  code_hash bytea primary key,
  business_id uuid not null references businesses (id),
  register_name text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_by uuid references users (id) on delete set null
);
create index pairing_codes_business_id on pairing_codes (business_id);

create table categories (
  business_id uuid not null references businesses (id),
  id text not null,
  name text not null,
  position int not null,
  archived boolean not null default false,
  change_seq bigint not null,
  primary key (business_id, id)
);

create table items (
  business_id uuid not null references businesses (id),
  id text not null,
  name text not null,
  price_cents int not null,
  category_id text not null,
  tax_percent int not null check (tax_percent in (20, 10, 13, 0, 19)),
  deposit_cents int not null default 0,
  tags text not null default '',
  info text,
  template_id text,
  favorite boolean not null default false,
  in_sale boolean not null default true,
  photo_file text,
  position int not null,
  archived boolean not null default false,
  change_seq bigint not null,
  price_changed_at timestamptz not null default now(),
  in_sale_changed_at timestamptz not null default now(),
  favorite_changed_at timestamptz not null default now(),
  deposit_changed_at timestamptz not null default now(),
  tags_changed_at timestamptz not null default now(),
  primary key (business_id, id),
  foreign key (business_id, category_id) references categories (business_id, id)
);

create table modifier_templates (
  business_id uuid not null references businesses (id),
  id text not null,
  name text not null,
  groups jsonb not null,
  archived boolean not null default false,
  change_seq bigint not null,
  primary key (business_id, id)
);

create table staff (
  business_id uuid not null references businesses (id),
  id uuid not null default gen_random_uuid(),
  name text not null,
  role text not null check (role in ('chef', 'staff')),
  pin_salt text not null,
  pin_hash text not null,
  archived boolean not null default false,
  change_seq bigint not null,
  primary key (business_id, id)
);

-- Die Sperre: gilt auch für den Besitzer (FORCE), soweit er nicht Superuser ist.
-- Ohne app.business_id (leer oder nicht gesetzt) ist keine Zeile sichtbar.
do $$
declare
  t text;
begin
  foreach t in array array['registers', 'pairing_codes', 'categories', 'items', 'modifier_templates', 'staff'] loop
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

-- Funktionen, die gebraucht werden, bevor der Betrieb bekannt ist. Sie laufen mit den
-- Rechten des Besitzers und geben nur die eine gesuchte Zeile her.

create function find_register_by_token(hash bytea)
returns table (id uuid, business_id uuid, name text, blocked_at timestamptz)
language sql
stable
security definer
set search_path = pg_catalog, pg_temp
as $$
  select r.id, r.business_id, r.name, r.blocked_at
    from public.registers r
   where r.token_hash = find_register_by_token.hash
$$;

-- Ein einziges UPDATE: von zwei gleichzeitigen Aufrufen bekommt nur einer die Zeile.
create function claim_pairing_code(hash bytea, at timestamptz)
returns table (business_id uuid, register_name text)
language sql
volatile
security definer
set search_path = pg_catalog, pg_temp
as $$
  update public.pairing_codes p
     set used_at = claim_pairing_code.at
   where p.code_hash = claim_pairing_code.hash
     and p.used_at is null
     and p.expires_at > claim_pairing_code.at
  returning p.business_id, p.register_name
$$;

-- Rechte für den Dienst

revoke all on function find_register_by_token(bytea) from public;
revoke all on function claim_pairing_code(bytea, timestamptz) from public;
grant execute on function find_register_by_token(bytea) to kassa_app;
grant execute on function claim_pairing_code(bytea, timestamptz) to kassa_app;

grant select, insert, update, delete on
  businesses, users, sessions, used_secrets, login_failures, releases,
  registers, pairing_codes, categories, items, modifier_templates, staff
  to kassa_app;
-- Den Verlauf darf der Dienst nur ergänzen, nie umschreiben.
grant select, insert on audit_log to kassa_app;
grant usage on sequence change_seq, audit_log_id_seq to kassa_app;
