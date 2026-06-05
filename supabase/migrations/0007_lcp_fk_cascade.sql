-- Sparrow — fix: every foreign key that references profiles needs ON UPDATE CASCADE.
-- The sign-in trigger links a person by rewriting profiles.id to their auth user id.
-- The staff tables in 0001 use `on update cascade` so that rewrite propagates, but later
-- tables (notifications, work_orders, the LCP tables, the Spine's calendar/quick_wins)
-- referenced profiles WITHOUT it — which blocks the id rewrite (and blocks re-linking an
-- account after a reseed). This recreates any such FK with `on update cascade` added.
--
-- Dynamic so it covers every table at once and is safe to re-run (it skips FKs that
-- already declare an ON UPDATE rule). Run AFTER 0006_spine.sql.

do $$
declare r record;
begin
  for r in
    select con.conname                       as name,
           con.conrelid::regclass::text       as child,
           pg_get_constraintdef(con.oid)      as def
    from pg_constraint con
    join pg_class ref on ref.oid = con.confrelid
    where con.contype = 'f'
      and ref.relname = 'profiles'
      and pg_get_constraintdef(con.oid) not ilike '%on update%'   -- needs the cascade
  loop
    execute 'alter table ' || r.child || ' drop constraint ' || quote_ident(r.name);
    execute 'alter table ' || r.child || ' add constraint '  || quote_ident(r.name)
            || ' ' || r.def || ' on update cascade';
    raise notice 'on update cascade -> %.%', r.child, r.name;
  end loop;
end $$;
