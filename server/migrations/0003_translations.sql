-- Wörterbuch der Speisekarte: je Name der Speisekarte die Übersetzungen nach Sprache.
-- values = {} heißt gelöscht; die Zeile bleibt, damit Tablets die Löschung beim Abgleich erfahren.
create table translations (
  business_id uuid not null references businesses (id),
  source text not null,
  values jsonb not null,
  change_seq bigint not null,
  primary key (business_id, source)
);

-- Die Sperre pro Betrieb, wie in 0001.
alter table translations enable row level security;
alter table translations force row level security;
create policy business_isolation on translations for all
  using (business_id = nullif(current_setting('app.business_id', true), '')::uuid)
  with check (business_id = nullif(current_setting('app.business_id', true), '')::uuid);

grant select, insert, update, delete on translations to kassa_app;
