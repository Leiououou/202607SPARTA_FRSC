# Constant-gamma focused tests

Run inputs from this directory so their relative species, surface, and
reaction-file paths resolve.

Deterministic serial cases:

- `in.face_adsorb`: gamma-one impact on a vacant face; particle is absorbed.
- `in.face_recombine`: full O(s) face; O becomes O2.
- `in.face_tally_only`: candidate counted without chemistry.
- `in.face_default_zero`: omitted O coefficient defaults to zero.
- `in.face_unmatched_double_scatter`: O impacts O2(s) with no O+O2 reaction;
  O and O2 leave separately, the stored site becomes vacant, and a following
  O impact adsorbs.
- `in.face_unmatched_tally_only`: the same unmatched pair in `tally_only`
  mode creates no second particle and does not change coverage.
- `in.face_unmatched_reallocate`: emits enough O2 particles to force growth
  of particle storage and exercise `ip` repointing after reallocation.
- `in.face_hetero_n_incident` and `in.face_hetero_o_incident`: unordered
  `N + O --> NO` matching in both incident directions.
- `in.face_heat`: run with `-var RXNFILE ... -var OUTFILE ...` to test heat
  sign.
- `in.face_gamma_half`: fixed-state statistical gamma-0.5 test.
- `in.surf_recombine`: replicated explicit-surface state test.
- `in.surf_unmatched_double_scatter`: replicated explicit-surface unmatched
  pairs emit one O2 for each O impact without a reaction tally.

MPI cases:

- `in.mpi_face_gamma_half`: two-cell/two-rank fixed-state gamma test.
- `in.mpi_face_recombine`: two-cell/two-rank mutating state and conservation.
- `in.mpi_surf_distributed`: distributed explicit-surface owner/ghost state.
- `in.mpi_surf_unmatched_distributed`: distributed explicit-surface
  unmatched-pair emission and owner/ghost coverage synchronization.

Parser cases:

```text
spa_serial -var RXNFILE gamma_comments.surf -in in.parser
spa_serial -var RXNFILE gamma_duplicate.surf -in in.parser
spa_serial -var RXNFILE gamma_missing_heat.surf -in in.parser
spa_serial -var RXNFILE gamma_bad_formula.surf -in in.parser
```

Only the comments case should succeed; the other three are expected failures.
