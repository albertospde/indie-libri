-- INDIE LIBRI: copie della rivista per uffici stampa, giornalisti, influencer, gruppi di lettura e case editrici.
-- Un contatto in distribuzione non si cancella dall'indirizzario: prima va tolto dal numero, cosi' i totali non cambiano da soli.
create table public.indie_rivista_distribuzione_contatti (
  numero_id bigint not null references public.indie_rivista_numeri(id) on delete cascade,
  contatto_id bigint not null references public.indie_indirizzari(id) on delete restrict,
  copie integer not null default 1 check (copie >= 0),
  copie_confermate integer check (copie_confermate >= 0),
  confermata_il timestamptz,
  confermata_da text,
  primary key (numero_id, contatto_id)
);
create index indie_rivista_distribuzione_contatti_contatto on public.indie_rivista_distribuzione_contatti (contatto_id);

alter table public.indie_rivista_distribuzione_contatti enable row level security;
create policy indie_select on public.indie_rivista_distribuzione_contatti for select to authenticated using (public.indie_libri_abilitato());
create policy indie_insert on public.indie_rivista_distribuzione_contatti for insert to authenticated with check (public.indie_libri_abilitato());
create policy indie_update on public.indie_rivista_distribuzione_contatti for update to authenticated using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato());
create policy indie_delete on public.indie_rivista_distribuzione_contatti for delete to authenticated using (public.indie_libri_abilitato());
revoke all on public.indie_rivista_distribuzione_contatti from anon;
grant select, insert, update, delete on public.indie_rivista_distribuzione_contatti to authenticated;

-- Un numero nuovo riparte anche dai contatti e dalle copie del numero di partenza, senza conferme
create or replace function public.indie_rivista_crea_numero(p_titolo text, p_uscita date, p_descrizione text, p_copie_previste integer, p_copia_da bigint)
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
  insert into public.indie_rivista_distribuzione_contatti (numero_id, contatto_id, copie)
  select nuovo, d.contatto_id, d.copie from public.indie_rivista_distribuzione_contatti d where d.numero_id = p_copia_da;
  return nuovo;
end $$;
