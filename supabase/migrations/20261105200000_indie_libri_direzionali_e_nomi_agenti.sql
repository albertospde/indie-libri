-- INDIE LIBRI: accesso con modifica a tutti i direzionali, agenti esclusi.
-- _bookup_is_admin() si basa su rpn_credentials, app_metadata e agenti_pde: niente user_metadata, modificabile dall'utente.
create or replace function public.indie_libri_abilitato()
returns boolean language sql stable security definer set search_path = public as $$
  select public._bookup_is_admin();
$$;

-- Agenti di riferimento: nome completo dall'anagrafica; agenti_pde serve solo a riconoscere il ruolo.
-- Esclude le utenze tecniche senza nome in agenti_pde (es. NTTPDE001), che facevano fallire il caricamento.
create or replace function public.indie_rivista_lista_numero(p_numero bigint)
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
         coalesce((select array_agg(distinct c.nome order by c.nome)
                   from unnest(a.agenti_codici, a.agenti) c(cod, nome)
                   join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
                     and ap.ruolo = 'Agente' and ap.attivo and ap.nome is not null
                   where c.nome is not null), '{}')
  from public.indie_rivista_distribuzione d
  join public.indie_rivista_librerie r on r.id = d.libreria_id
  left join public.anagrafiche_clienti a on a.codice_cliente = r.codice_cliente
  where d.numero_id = p_numero
  order by coalesce(a.provincia, r.provincia), coalesce(a.citta, r.citta), coalesce(a.ragione_sociale, r.ragione_sociale), r.id;
end $$;
