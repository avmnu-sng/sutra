sutra (migration): Change a live schema by expand, migrate, contract. The
previous release must keep working against the new schema, an applied
migration is never edited (write a new one), and a backfill runs in bounded
batches that can pause and resume. Depth: /sutra:data-migration.
