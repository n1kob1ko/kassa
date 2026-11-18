-- Rolle, mit der der Dienst arbeitet. Rollen gelten für den ganzen Cluster,
-- darum wird sie nur angelegt, wenn es sie noch nicht gibt.
-- Das Passwort setzt `migrate` danach aus der Umgebung.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'kassa_app') then
    create role kassa_app login nosuperuser nobypassrls nocreatedb nocreaterole;
  end if;
end
$$;
