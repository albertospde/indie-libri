-- INDIE LIBRI: indirizzi email degli agenti, per preparare l'invio della distribuzione.
-- Stessi nomi e stessi criteri di indie_rivista_lista_numero (nome dall'anagrafica, ruolo e attivo da agenti_pde).
create function public.indie_rivista_email_agenti()
returns table (nome text, email text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select distinct c.nome, lower(trim(ap.email))
  from public.anagrafiche_clienti x, unnest(x.agenti_codici, x.agenti) c(cod, nome)
  join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
    and ap.ruolo = 'Agente' and ap.attivo and ap.nome is not null
  where c.nome is not null and nullif(trim(ap.email), '') is not null;
end $$;
revoke all on function public.indie_rivista_email_agenti() from public, anon;
grant execute on function public.indie_rivista_email_agenti() to authenticated;
