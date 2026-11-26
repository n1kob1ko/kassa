-- Stufe 1a: Ein Bon kann mit mehreren Zahlungen (bar und Karte), Trinkgeld und Rabatt kommen (Bon v: 2).
-- payment_kind kennt dazu 'mixed' (bar und Karte auf einem Bon).
alter table receipts add column cash_cents int not null default 0, add column card_cents int not null default 0,
                     add column tip_cents int not null default 0, add column discount_cents int not null default 0;
alter table receipt_lines add column discount_cents int not null default 0, add column discount jsonb;
-- Alte Bons füllen: receipts ist unveränderlich (Trigger receipts_immutable), darum für diese eine Änderung aus.
alter table receipts disable trigger receipts_immutable;
update receipts set cash_cents = total_cents where kind in ('sale', 'voided') and payment_kind = 'cash';
update receipts set card_cents = total_cents where kind in ('sale', 'voided') and payment_kind is distinct from 'cash';
alter table receipts enable trigger receipts_immutable;
