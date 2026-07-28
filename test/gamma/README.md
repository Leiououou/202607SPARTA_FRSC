# Constant-gamma focused tests

Run inputs from this directory so their relative species, surface, and
reaction-file paths resolve.

Deterministic serial cases:

- `in.face_adsorb`: gamma-one impact on a vacant face; particle is absorbed.
- `in.face_recombine`: full O(s) face; O becomes O2.
- `in.face_tally_only`: candidate counted without chemistry.
- `in.face_default_zero`: omitted O coefficient defaults to zero.
- `in.face_hetero_n_incident` and `in.face_hetero_o_incident`: unordered
  `N + O --> NO` matching in both incident directions.
- `in.face_heat`: run with `-var RXNFILE ... -var OUTFILE ...` to test heat
  sign.
- `in.face_gamma_half`: fixed-state statistical gamma-0.5 test.
- `in.surf_recombine`: replicated explicit-surface state test.

MPI cases:

- `in.mpi_face_gamma_half`: two-cell/two-rank fixed-state gamma test.
- `in.mpi_face_recombine`: two-cell/two-rank mutating state and conservation.
- `in.mpi_surf_distributed`: distributed explicit-surface owner/ghost state.

Parser cases:

```text
spa_serial -var RXNFILE gamma_comments.surf -in in.parser
spa_serial -var RXNFILE gamma_duplicate.surf -in in.parser
spa_serial -var RXNFILE gamma_missing_heat.surf -in in.parser
spa_serial -var RXNFILE gamma_bad_formula.surf -in in.parser
```

Only the comments case should succeed; the other three are expected failures.
