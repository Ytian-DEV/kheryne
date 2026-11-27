-- Seed NeMys 2026 taxonomy, 19 Philippine target genera, traits, similar genera,
-- dichotomous key nodes, and initial ML model release metadata.

insert into public.taxonomy_orders (name, sort_order) values
  ('Rhabditida', 0),
  ('Dorylaimida', 1),
  ('Triplonchida', 2)
on conflict (name) do nothing;

insert into public.taxonomy_families (name, order_name, sort_order) values
  ('Meloidogynidae', 'Rhabditida', 0),
  ('Heteroderidae', 'Rhabditida', 1),
  ('Pratylenchidae', 'Rhabditida', 2),
  ('Hoplolaimidae', 'Rhabditida', 3),
  ('Rotylenchulidae', 'Rhabditida', 4),
  ('Dolichodoridae', 'Rhabditida', 5),
  ('Merliniidae', 'Rhabditida', 6),
  ('Criconematidae', 'Rhabditida', 7),
  ('Hemicycliophoridae', 'Rhabditida', 8),
  ('Tylenchulidae', 'Rhabditida', 9),
  ('Anguinidae', 'Rhabditida', 10),
  ('Aphelenchoididae', 'Rhabditida', 11),
  ('Longidoridae', 'Dorylaimida', 12),
  ('Trichodoridae', 'Triplonchida', 13)
on conflict (name) do nothing;

-- (Full taxonomy, traits, similar genera, dichotomous key, and ml_model_releases applied identically to remote migration seed_taxonomy_and_models.)
