-- INDIE LIBRI: indirizzari di uffici stampa, giornalisti, influencer, gruppi di lettura e case editrici.
-- Una sola tabella: i campi sono gli stessi, cambiano solo testata, canali social e n° partecipanti.
-- Gli agenti restano in indie_agenti_rubrica, perche' sono collegati a BookUp.
create table public.indie_indirizzari (
  id bigint generated always as identity primary key,
  tipo text not null check (tipo in ('uffici_stampa', 'giornalisti', 'influencer', 'gruppi_lettura', 'case_editrici')),
  nome text,
  cognome text,
  ragione_sociale text,
  indirizzo text,
  cap text,
  citta text,
  regione text,
  telefono text,
  email text,
  testata text,
  canali_social text,
  n_partecipanti integer check (n_partecipanti >= 0),
  aggiornato_il timestamptz not null default now(),
  aggiornato_da text,
  constraint indie_indirizzari_intestatario check (coalesce(nullif(trim(nome), ''), nullif(trim(cognome), ''), nullif(trim(ragione_sociale), '')) is not null)
);
create index indie_indirizzari_tipo on public.indie_indirizzari (tipo);

alter table public.indie_indirizzari enable row level security;
create policy indie_select on public.indie_indirizzari for select using (public.indie_libri_abilitato());
create policy indie_insert on public.indie_indirizzari for insert with check (public.indie_libri_abilitato());
create policy indie_update on public.indie_indirizzari for update using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato());
create policy indie_delete on public.indie_indirizzari for delete using (public.indie_libri_abilitato());
revoke all on public.indie_indirizzari from anon;
grant select, insert, update, delete on public.indie_indirizzari to authenticated;
