-- INDIE LIBRI: referenti delle case editrici (commerciale, ufficio stampa, marketing, comunicazione).
-- Fanno parte della scheda della casa editrice: se la casa viene eliminata, spariscono con lei.
create table public.indie_indirizzari_referenti (
  id bigint generated always as identity primary key,
  contatto_id bigint not null references public.indie_indirizzari(id) on delete cascade,
  categoria text not null check (categoria in ('commerciale', 'ufficio_stampa', 'marketing', 'comunicazione')),
  nome text,
  cognome text,
  telefono text,
  email text,
  aggiornato_il timestamptz not null default now(),
  aggiornato_da text,
  constraint indie_indirizzari_referenti_dati check (coalesce(nullif(trim(nome), ''), nullif(trim(cognome), ''), nullif(trim(telefono), ''), nullif(trim(email), '')) is not null)
);
create index indie_indirizzari_referenti_contatto on public.indie_indirizzari_referenti (contatto_id);

alter table public.indie_indirizzari_referenti enable row level security;
create policy indie_select on public.indie_indirizzari_referenti for select to authenticated using (public.indie_libri_abilitato());
create policy indie_insert on public.indie_indirizzari_referenti for insert to authenticated with check (public.indie_libri_abilitato());
create policy indie_update on public.indie_indirizzari_referenti for update to authenticated using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato());
create policy indie_delete on public.indie_indirizzari_referenti for delete to authenticated using (public.indie_libri_abilitato());
revoke all on public.indie_indirizzari_referenti from anon;
grant select, insert, update, delete on public.indie_indirizzari_referenti to authenticated;
