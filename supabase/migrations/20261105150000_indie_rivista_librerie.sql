-- INDIE LIBRI - sezione Distribuzione Rivista
create table if not exists public.indie_rivista_librerie (
  id bigint generated always as identity primary key,
  codice_cliente text,                       -- collegamento a anagrafiche_clienti (null = non abbinata)
  ragione_sociale text not null,             -- dati del file / inseriti a mano: usati se non abbinata
  indirizzo text,
  cap text,
  citta text,
  provincia text,
  copie integer not null default 50 check (copie >= 0),
  copie_confermate integer check (copie_confermate >= 0),  -- null = non ancora confermata
  confermata_il timestamptz,
  confermata_da text,
  note text,
  abbinamento text,                          -- come e' stata collegata all'anagrafica
  da_verificare boolean not null default false,
  ordine integer,                            -- riga del file di partenza
  created_at timestamptz not null default now()
);
create index if not exists indie_rivista_librerie_codice_idx on public.indie_rivista_librerie (codice_cliente);

alter table public.indie_rivista_librerie enable row level security;
create policy indie_riv_select on public.indie_rivista_librerie for select to authenticated using (public._bookup_is_admin());
create policy indie_riv_insert on public.indie_rivista_librerie for insert to authenticated with check (public._bookup_is_admin());
create policy indie_riv_update on public.indie_rivista_librerie for update to authenticated using (public._bookup_is_admin()) with check (public._bookup_is_admin());
create policy indie_riv_delete on public.indie_rivista_librerie for delete to authenticated using (public._bookup_is_admin());
revoke all on public.indie_rivista_librerie from anon;
grant select, insert, update, delete on public.indie_rivista_librerie to authenticated;

-- Elenco con i dati sempre aggiornati dell'anagrafica BookUp (stato compreso)
create or replace function public.indie_rivista_lista()
returns table (
  id bigint, codice_cliente text, ragione_sociale text, indirizzo text, cap text, citta text, provincia text,
  regione text, gruppo_desc text, partita_iva text, agenti text[], stato text, motivo text, in_anagrafica boolean,
  copie integer, copie_confermate integer, confermata_il timestamptz, confermata_da text, note text,
  abbinamento text, da_verificare boolean, nome_file text, indirizzo_file text, ordine integer
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._bookup_is_admin() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select r.id, r.codice_cliente,
         coalesce(a.ragione_sociale, r.ragione_sociale), coalesce(a.indirizzo, r.indirizzo),
         coalesce(a.cap, r.cap), coalesce(a.citta, r.citta), coalesce(a.provincia, r.provincia),
         a.regione, a.gruppo_desc, a.partita_iva, a.agenti, a.stato, a.motivo, a.codice_cliente is not null,
         r.copie, r.copie_confermate, r.confermata_il, r.confermata_da, r.note,
         r.abbinamento, r.da_verificare, r.ragione_sociale, r.indirizzo, r.ordine
  from public.indie_rivista_librerie r
  left join public.anagrafiche_clienti a on a.codice_cliente = r.codice_cliente
  order by coalesce(a.provincia, r.provincia), coalesce(a.citta, r.citta), coalesce(a.ragione_sociale, r.ragione_sociale), r.id;
end $$;

-- Ricerca nelle anagrafiche per aggiungere o collegare una libreria
create or replace function public.indie_rivista_cerca_anagrafica(q text)
returns table (codice_cliente text, ragione_sociale text, indirizzo text, cap text, citta text, provincia text, stato text, motivo text, gia_in_elenco boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  parole text[];
begin
  if not public._bookup_is_admin() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  parole := array(select p from unnest(regexp_split_to_array(trim(coalesce(q,'')), '\s+')) p where length(p) > 0);
  if coalesce(array_length(parole,1),0) = 0 then return; end if;
  return query
  select a.codice_cliente, a.ragione_sociale, a.indirizzo, a.cap, a.citta, a.provincia, a.stato, a.motivo,
         exists (select 1 from public.indie_rivista_librerie r where r.codice_cliente = a.codice_cliente)
  from public.anagrafiche_clienti a
  where not exists (
    select 1 from unnest(parole) p
    where concat_ws(' ', a.codice_cliente, a.ragione_sociale, a.indirizzo, a.citta, a.provincia, a.cap, a.partita_iva)
          not ilike '%' || replace(replace(replace(p,'\','\\'),'%','\%'),'_','\_') || '%'
  )
  order by (a.stato = 'A') desc, a.ragione_sociale
  limit 40;
end $$;

revoke all on function public.indie_rivista_lista() from public, anon;
revoke all on function public.indie_rivista_cerca_anagrafica(text) from public, anon;
grant execute on function public.indie_rivista_lista() to authenticated;
grant execute on function public.indie_rivista_cerca_anagrafica(text) to authenticated;
