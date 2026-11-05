-- INDIE LIBRI: ogni numero della rivista e' un evento con la sua distribuzione e le sue copie interne.
-- Non cancella nulla: le colonne copie/conferma su indie_rivista_librerie restano, ma l'app non le usa piu'.
create table public.indie_rivista_numeri (
  id bigint generated always as identity primary key,
  titolo text not null,
  uscita date,
  descrizione text,
  copie_previste integer check (copie_previste >= 0),
  created_at timestamptz not null default now()
);

create table public.indie_rivista_distribuzione (
  numero_id bigint not null references public.indie_rivista_numeri(id) on delete cascade,
  libreria_id bigint not null references public.indie_rivista_librerie(id) on delete cascade,
  copie integer not null default 50 check (copie >= 0),
  copie_confermate integer check (copie_confermate >= 0),
  confermata_il timestamptz,
  confermata_da text,
  primary key (numero_id, libreria_id)
);

create table public.indie_rivista_copie_interne (
  id bigint generated always as identity primary key,
  numero_id bigint not null references public.indie_rivista_numeri(id) on delete cascade,
  destinazione text not null,
  data_evento date,
  copie integer not null check (copie >= 0),
  note text,
  inserita_da text,
  created_at timestamptz not null default now()
);
create index indie_rivista_copie_interne_numero_idx on public.indie_rivista_copie_interne (numero_id);

do $$
declare t text;
begin
  foreach t in array array['indie_rivista_numeri','indie_rivista_distribuzione','indie_rivista_copie_interne'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy indie_select on public.%I for select to authenticated using (public.indie_libri_abilitato())', t);
    execute format('create policy indie_insert on public.%I for insert to authenticated with check (public.indie_libri_abilitato())', t);
    execute format('create policy indie_update on public.%I for update to authenticated using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato())', t);
    execute format('create policy indie_delete on public.%I for delete to authenticated using (public.indie_libri_abilitato())', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- L'elenco gia' caricato diventa il primo numero, con quantita' e conferme attuali
with n as (
  insert into public.indie_rivista_numeri (titolo, copie_previste)
  select 'N° 1', coalesce(sum(copie), 0) from public.indie_rivista_librerie
  returning id
)
insert into public.indie_rivista_distribuzione (numero_id, libreria_id, copie, copie_confermate, confermata_il, confermata_da)
select n.id, r.id, r.copie, r.copie_confermate, r.confermata_il, r.confermata_da
from public.indie_rivista_librerie r, n;

-- Elenco di un numero, con dati e stato sempre aggiornati dall'anagrafica BookUp
create function public.indie_rivista_lista_numero(p_numero bigint)
returns table (
  id bigint, codice_cliente text, ragione_sociale text, indirizzo text, cap text, citta text, provincia text,
  regione text, gruppo_desc text, partita_iva text, agenti text[], stato text, motivo text, in_anagrafica boolean,
  copie integer, copie_confermate integer, confermata_il timestamptz, confermata_da text, note text,
  abbinamento text, da_verificare boolean, nome_file text, indirizzo_file text, ordine integer,
  agenti_ruolo_agente text[]
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select r.id, r.codice_cliente,
         coalesce(a.ragione_sociale, r.ragione_sociale), coalesce(a.indirizzo, r.indirizzo),
         coalesce(a.cap, r.cap), coalesce(a.citta, r.citta), coalesce(a.provincia, r.provincia),
         a.regione, a.gruppo_desc, a.partita_iva, a.agenti, a.stato, a.motivo, a.codice_cliente is not null,
         d.copie, d.copie_confermate, d.confermata_il, d.confermata_da, r.note,
         r.abbinamento, r.da_verificare, r.ragione_sociale, r.indirizzo, r.ordine,
         coalesce((select array_agg(distinct ap.nome order by ap.nome)
                   from unnest(a.agenti_codici) c(cod)
                   join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
                     and ap.ruolo = 'Agente' and ap.attivo), '{}')
  from public.indie_rivista_distribuzione d
  join public.indie_rivista_librerie r on r.id = d.libreria_id
  left join public.anagrafiche_clienti a on a.codice_cliente = r.codice_cliente
  where d.numero_id = p_numero
  order by coalesce(a.provincia, r.provincia), coalesce(a.citta, r.citta), coalesce(a.ragione_sociale, r.ragione_sociale), r.id;
end $$;

-- Nuovo numero: riparte dall'elenco e dalle quantita' di un numero esistente, senza conferme
create function public.indie_rivista_crea_numero(p_titolo text, p_uscita date, p_descrizione text, p_copie_previste integer, p_copia_da bigint)
returns bigint
language plpgsql security definer set search_path = public as $$
declare nuovo bigint;
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  insert into public.indie_rivista_numeri (titolo, uscita, descrizione, copie_previste)
  values (p_titolo, p_uscita, p_descrizione, p_copie_previste)
  returning id into nuovo;
  insert into public.indie_rivista_distribuzione (numero_id, libreria_id, copie)
  select nuovo, d.libreria_id, d.copie from public.indie_rivista_distribuzione d where d.numero_id = p_copia_da;
  return nuovo;
end $$;

-- Ricerca in anagrafica: "gia' in elenco" vale per il numero aperto
drop function public.indie_rivista_cerca_anagrafica(text);
create function public.indie_rivista_cerca_anagrafica(q text, p_numero bigint default null)
returns table (codice_cliente text, ragione_sociale text, indirizzo text, cap text, citta text, provincia text, stato text, motivo text, gia_in_elenco boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  parole text[];
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  parole := array(select p from unnest(regexp_split_to_array(trim(coalesce(q,'')), '\s+')) p where length(p) > 0);
  if coalesce(array_length(parole,1),0) = 0 then return; end if;
  return query
  select a.codice_cliente, a.ragione_sociale, a.indirizzo, a.cap, a.citta, a.provincia, a.stato, a.motivo,
         exists (select 1 from public.indie_rivista_librerie r
                 join public.indie_rivista_distribuzione d on d.libreria_id = r.id
                 where r.codice_cliente = a.codice_cliente and d.numero_id = p_numero)
  from public.anagrafiche_clienti a
  where not exists (
    select 1 from unnest(parole) p
    where concat_ws(' ', a.codice_cliente, a.ragione_sociale, a.indirizzo, a.citta, a.provincia, a.cap, a.partita_iva)
          not ilike '%' || replace(replace(replace(p,'\','\\'),'%','\%'),'_','\_') || '%'
  )
  order by (a.stato = 'A') desc, a.ragione_sociale
  limit 40;
end $$;

revoke all on function public.indie_rivista_lista_numero(bigint) from public, anon;
revoke all on function public.indie_rivista_crea_numero(text, date, text, integer, bigint) from public, anon;
revoke all on function public.indie_rivista_cerca_anagrafica(text, bigint) from public, anon;
grant execute on function public.indie_rivista_lista_numero(bigint) to authenticated;
grant execute on function public.indie_rivista_crea_numero(text, date, text, integer, bigint) to authenticated;
grant execute on function public.indie_rivista_cerca_anagrafica(text, bigint) to authenticated;
