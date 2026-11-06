-- INDIE LIBRI: regioni di competenza degli agenti, nome e cognome separati.
-- Si calcolano dai clienti attivi di BookUp; regioni in rubrica, se compilato, le sostituisce (null = calcolate).
alter table public.indie_agenti_rubrica add column regioni text[], add column cognome text;

-- Righe gia' salvate con il nome completo: BookUp ha nome e cognome separati, per quelle a mano si divide alla prima parola.
update public.indie_agenti_rubrica r
set nome = trim(ap.nome), cognome = trim(ap.cognome)
from public.agenti_pde ap
where ap.id = r.agente_pde_id and r.nome = trim(ap.nome) || ' ' || trim(ap.cognome);
update public.indie_agenti_rubrica
set cognome = nullif(trim(substr(trim(nome), length(split_part(trim(nome), ' ', 1)) + 1)), ''), nome = split_part(trim(nome), ' ', 1)
where cognome is null and agente_pde_id is null;

create function public._indie_agenti_regioni()
returns table (agente_pde_id integer, regioni jsonb)
language sql stable security definer set search_path = public as $$
  select t.id, jsonb_agg(jsonb_build_object('regione', t.regione, 'n', t.n) order by t.n desc, t.regione)
  from (
    select ap.id, trim(x.regione) as regione, count(distinct x.codice_cliente)::int as n
    from public.anagrafiche_clienti x, unnest(x.agenti_codici, x.agenti) c(cod, nome)
    join public.agenti_pde ap on (ap.codice_agente = c.cod or ap.codice_operativo = c.cod)
      and ap.ruolo = 'Agente' and ap.attivo and ap.nome is not null
    where c.nome is not null and x.stato = 'A' and nullif(trim(x.regione), '') is not null
    group by 1, 2
  ) t
  group by t.id;
$$;
revoke all on function public._indie_agenti_regioni() from public, anon, authenticated;

drop function public.indie_agenti_lista();
create function public.indie_agenti_lista()
returns table (id bigint, agente_pde_id integer, nome text, cognome text, codice text, email text, telefono text, indirizzo text, note text, attivo boolean, regioni text[], regioni_clienti jsonb)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.indie_libri_abilitato() then
    raise exception 'Non autorizzato' using errcode = '42501';
  end if;
  return query
  select r.id, coalesce(r.agente_pde_id, b.agente_pde_id),
         coalesce(r.nome, trim(ap.nome)), case when r.id is null then trim(ap.cognome) else r.cognome end,
         case when r.id is null then b.codice else r.codice end,
         case when r.id is null then b.email else r.email end,
         r.telefono, r.indirizzo, r.note, coalesce(r.attivo, b.attivo),
         r.regioni, coalesce(g.regioni, '[]'::jsonb)
  from public.indie_agenti_rubrica r
  full join public._indie_agenti_bookup() b on b.agente_pde_id = r.agente_pde_id
  left join public.agenti_pde ap on ap.id = b.agente_pde_id
  left join public._indie_agenti_regioni() g on g.agente_pde_id = coalesce(r.agente_pde_id, b.agente_pde_id)
  order by 4, 3;
end $$;
revoke all on function public.indie_agenti_lista() from public, anon;
grant execute on function public.indie_agenti_lista() to authenticated;
