-- Promote Criconema (Criconematidae) to a primary Philippine target genus
-- with diagnostic traits, similar-genus comparisons, and dichotomous key couplet.

insert into public.genera (
  name,
  family_name,
  order_name,
  common_name,
  summary,
  crops,
  image_seeds,
  recorded_in_philippines,
  typical_morphometrics
) values (
  'Criconema',
  'Criconematidae',
  'Rhabditida',
  'Spine / scaly ring nematode',
  'Short, stout ectoparasite with coarse retrorse body rings bearing cuticular scales, spines, or posterior fringes.',
  array['Coconut', 'Banana', 'Citrus', 'Forest & fruit trees'],
  array[204, 205, 206],
  true,
  '{"length_um": 460, "a": 10, "b": 4.1, "c": 20, "vulva_pct": 91, "stylet_um": 62}'::jsonb
)
on conflict (name) do update set
  family_name = excluded.family_name,
  order_name = excluded.order_name,
  common_name = excluded.common_name,
  summary = excluded.summary,
  crops = excluded.crops,
  image_seeds = excluded.image_seeds,
  recorded_in_philippines = true,
  typical_morphometrics = excluded.typical_morphometrics;

insert into public.genus_traits (genus_name, sort_order, name, value, why, region, illustration)
select 'Criconema', 0, 'Cuticle', 'Coarse retrorse annules with scales or fringes',
  'Cuticular spines, scales, or posterior fringes along the coarse rings separate Criconema from plain-ringed Criconemoides.',
  'vulva', 'annulatedRetrorse'
where not exists (
  select 1 from public.genus_traits where genus_name = 'Criconema' and name = 'Cuticle'
);

insert into public.genus_traits (genus_name, sort_order, name, value, why, region, illustration)
select 'Criconema', 1, 'Stylet', '50–85 µm, robust anchor-shaped knobs',
  'A long, stout stomatostylet with anteriorly cupped or anchor-shaped knobs supports ectoparasitic root feeding.',
  'stylet', 'styletKnobbed'
where not exists (
  select 1 from public.genus_traits where genus_name = 'Criconema' and name = 'Stylet'
);

insert into public.genus_traits (genus_name, sort_order, name, value, why, region, illustration)
select 'Criconema', 2, 'Vulva position', '~90–93% (far posterior)',
  'A strongly posterior, closed or overhanging vulva is characteristic of Criconematidae females.',
  'vulva', 'vulvaPosterior'
where not exists (
  select 1 from public.genus_traits where genus_name = 'Criconema' and name = 'Vulva position'
);

insert into public.similar_genera (genus_name, similar_genus_name, how_to_tell)
select 'Criconema', 'Criconemoides', 'Criconemoides has retrorse rings with smooth/plain posterior margins rather than spines, scales, or fringes.'
where not exists (
  select 1 from public.similar_genera where genus_name = 'Criconema' and similar_genus_name = 'Criconemoides'
);

insert into public.similar_genera (genus_name, similar_genus_name, how_to_tell)
select 'Criconema', 'Mesocriconema', 'Mesocriconema annules are smooth or crenated without cuticular scales or spines, with submedian lip lobes.'
where not exists (
  select 1 from public.similar_genera where genus_name = 'Criconema' and similar_genus_name = 'Mesocriconema'
);

update public.dichotomous_key_nodes
set yes_target = 'ringFringe'
where id = 'retrorse';

insert into public.dichotomous_key_nodes (
  id,
  sort_order,
  question,
  hint,
  yes_target,
  no_target,
  yes_illustration,
  no_illustration,
  yes_label,
  no_label,
  is_start
) values (
  'ringFringe',
  8,
  'Do the retrorse rings bear cuticular spines, scales, or fringes?',
  'Adult Criconema females have spiny, scaly, or fringed posterior ring margins, whereas Criconemoides rings have plain retrorse edges.',
  '=Criconema',
  '=Criconemoides',
  'annulatedRetrorse',
  'annulated',
  'Spines, scales or fringes',
  'Plain retrorse edges',
  false
)
on conflict (id) do update set
  question = excluded.question,
  hint = excluded.hint,
  yes_target = excluded.yes_target,
  no_target = excluded.no_target,
  yes_illustration = excluded.yes_illustration,
  no_illustration = excluded.no_illustration,
  yes_label = excluded.yes_label,
  no_label = excluded.no_label;
