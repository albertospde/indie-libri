-- INDIE LIBRI: rubrica degli agenti (indirizzi, telefono, email).
-- agenti_pde resta in sola lettura: governa accessi e ruoli di tutte le app PDE e non va toccata da qui.
-- La rubrica contiene gli agenti aggiunti a mano e quelli di BookUp modificati almeno una volta;
-- gli altri agenti di BookUp si leggono da agenti_pde, cosi' quelli nuovi compaiono da soli.
create table public.indie_agenti_rubrica (
  id bigint generated always as identity primary key,
  agente_pde_id integer unique references public.agenti_pde(id) on delete set null,
  nome text not null check (trim(nome) <> ''),
  codice text,
  email text,
  telefono text,
  indirizzo text,
  note text,
  attivo boolean not null default true,
  aggiornato_il timestamptz not null default now(),
  aggiornato_da text
);
alter table public.indie_agenti_rubrica enable row level security;
create policy indie_select on public.indie_agenti_rubrica for select using (public.indie_libri_abilitato());
create policy indie_insert on public.indie_agenti_rubrica for insert with check (public.indie_libri_abilitato());
create policy indie_update on public.indie_agenti_rubrica for update using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato());
revoke all on public.indie_agenti_rubrica from anon;
grant select, insert, update on public.indie_agenti_rubrica to authenticated;

-- Agenti veri di BookUp: nome completo dall'anagrafica. Fuori le utenze tecniche senza nome e "pde_agente".
create function public._indie_agenti_bookup()
returns table (agente_pde_id integer, nome text, codice text, email text, attivo boolean)
language sql stable security definer set search_path = public as $$
  select distinct on (ap.id) ap.id, c.nome, coalesce(ap.codice_agente, ap.codice_operativo), nullif(lower(trim(ap.email)), ''), ap.attivo
  from public.anagrafiche_clienti x, unnest(x.agenti_codici, x.agenti) c(cod, nome)
  join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
    and ap.ruolo = 'Agente' and ap.attivo and ap.nome is not null
  where c.nome is not null and c.nome <> 'pde_agente'
  order by ap.id, c.nome;
$$;
revoke all on function public._indie_agenti_bookup() from public, anon, authenticated;

create function public.indie_agenti_lista()
returns table (id bigint, agente_pde_id integer, nome text, codice text, email text, telefono text, indirizzo text, note text, attivo boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select r.id, coalesce(r.agente_pde_id, b.agente_pde_id),
         coalesce(r.nome, b.nome), case when r.id is null then b.codice else r.codice end,
         case when r.id is null then b.email else r.email end,
         r.telefono, r.indirizzo, r.note, coalesce(r.attivo, b.attivo)
  from public.indie_agenti_rubrica r
  full join public._indie_agenti_bookup() b on b.agente_pde_id = r.agente_pde_id
  order by 3;
end $$;
revoke all on function public.indie_agenti_lista() from public, anon;
grant execute on function public.indie_agenti_lista() to authenticated;

-- L'invio ora legge la rubrica: l'email corretta li' vale subito, un agente disattivato non riceve piu' nulla.
create or replace function public.indie_rivista_email_agenti()
returns table (nome text, email text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select b.nome, case when r.id is null then b.email else nullif(lower(trim(r.email)), '') end
  from public._indie_agenti_bookup() b
  left join public.indie_agenti_rubrica r on r.agente_pde_id = b.agente_pde_id
  where coalesce(r.attivo, true)
    and case when r.id is null then b.email else nullif(trim(r.email), '') end is not null;
end $$;
