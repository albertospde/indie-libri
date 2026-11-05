-- INDIE LIBRI: agenti di riferimento, solo quelli con ruolo Agente attivi (niente amministratori/responsabili)
drop function public.indie_rivista_lista();
create function public.indie_rivista_lista()
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
         r.copie, r.copie_confermate, r.confermata_il, r.confermata_da, r.note,
         r.abbinamento, r.da_verificare, r.ragione_sociale, r.indirizzo, r.ordine,
         coalesce((select array_agg(distinct ap.nome order by ap.nome)
                   from unnest(a.agenti_codici) c(cod)
                   join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
                     and ap.ruolo = 'Agente' and ap.attivo), '{}')
  from public.indie_rivista_librerie r
  left join public.anagrafiche_clienti a on a.codice_cliente = r.codice_cliente
  order by coalesce(a.provincia, r.provincia), coalesce(a.citta, r.citta), coalesce(a.ragione_sociale, r.ragione_sociale), r.id;
end $$;
revoke all on function public.indie_rivista_lista() from public, anon;
grant execute on function public.indie_rivista_lista() to authenticated;
