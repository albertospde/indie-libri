-- INDIE LIBRI: al momento accesso solo ad Alberto. Per aprirlo ad altri basta aggiungere le email qui.
create or replace function public.indie_libri_abilitato()
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (select 1 from auth.users u where u.id = auth.uid() and lower(u.email) in ('alberto.simola@pde.it'));
$$;
revoke all on function public.indie_libri_abilitato() from public, anon;
grant execute on function public.indie_libri_abilitato() to authenticated;

drop policy indie_riv_select on public.indie_rivista_librerie;
drop policy indie_riv_insert on public.indie_rivista_librerie;
drop policy indie_riv_update on public.indie_rivista_librerie;
drop policy indie_riv_delete on public.indie_rivista_librerie;
create policy indie_riv_select on public.indie_rivista_librerie for select to authenticated using (public.indie_libri_abilitato());
create policy indie_riv_insert on public.indie_rivista_librerie for insert to authenticated with check (public.indie_libri_abilitato());
create policy indie_riv_update on public.indie_rivista_librerie for update to authenticated using (public.indie_libri_abilitato()) with check (public.indie_libri_abilitato());
create policy indie_riv_delete on public.indie_rivista_librerie for delete to authenticated using (public.indie_libri_abilitato());

-- indie_rivista_lista e indie_rivista_cerca_anagrafica: stesso corpo della prima migrazione,
-- con il controllo su public.indie_libri_abilitato() al posto di public._bookup_is_admin().
