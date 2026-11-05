-- INDIE LIBRI: agente di riferimento cercato anche per partita IVA.
-- Ordine: agenti del codice cliente; altrimenti stessa P.IVA e stessa provincia; altrimenti stessa P.IVA altrove.
-- La provincia evita che le catene (es. 245 codici con la stessa P.IVA) ricevano tutti gli agenti d'Italia.
drop function public.indie_rivista_lista_numero(bigint);
create function public.indie_rivista_lista_numero(p_numero bigint)
returns table (
  id bigint, codice_cliente text, ragione_sociale text, indirizzo text, cap text, citta text, provincia text,
  regione text, gruppo_desc text, partita_iva text, agenti text[], stato text, motivo text, in_anagrafica boolean,
  copie integer, copie_confermate integer, confermata_il timestamptz, confermata_da text, note text,
  abbinamento text, da_verificare boolean, nome_file text, indirizzo_file text, ordine integer,
  agenti_ruolo_agente text[], agente_da_piva boolean
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  with ag as materialized (
    select distinct nullif(trim(x.partita_iva), '') as p_iva, x.codice_cliente as cod, x.provincia as prov, c.nome as agente
    from public.anagrafiche_clienti x, unnest(x.agenti_codici, x.agenti) c(cod, nome)
    join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
      and ap.ruolo = 'Agente' and ap.attivo and ap.nome is not null
    where c.nome is not null
  )
  select r.id, r.codice_cliente,
         coalesce(a.ragione_sociale, r.ragione_sociale), coalesce(a.indirizzo, r.indirizzo),
         coalesce(a.cap, r.cap), coalesce(a.citta, r.citta), coalesce(a.provincia, r.provincia),
         a.regione, a.gruppo_desc, a.partita_iva, a.agenti, a.stato, a.motivo, a.codice_cliente is not null,
         d.copie, d.copie_confermate, d.confermata_il, d.confermata_da, r.note,
         r.abbinamento, r.da_verificare, r.ragione_sociale, r.indirizzo, r.ordine,
         coalesce(t.nomi, '{}'), coalesce(t.liv > 1, false)
  from public.indie_rivista_distribuzione d
  join public.indie_rivista_librerie r on r.id = d.libreria_id
  left join public.anagrafiche_clienti a on a.codice_cliente = r.codice_cliente
  left join lateral (
    select v.liv, array_agg(distinct v.agente order by v.agente) as nomi
    from (
      select g.agente, case when g.cod = a.codice_cliente then 1 when g.prov = a.provincia then 2 else 3 end as liv
      from ag g
      where g.cod = a.codice_cliente or g.p_iva = nullif(trim(a.partita_iva), '')
    ) v
    group by v.liv
    order by v.liv
    limit 1
  ) t on true
  where d.numero_id = p_numero
  order by coalesce(a.provincia, r.provincia), coalesce(a.citta, r.citta), coalesce(a.ragione_sociale, r.ragione_sociale), r.id;
end $$;
revoke all on function public.indie_rivista_lista_numero(bigint) from public, anon;
grant execute on function public.indie_rivista_lista_numero(bigint) to authenticated;
