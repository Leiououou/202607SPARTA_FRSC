# Constant-gamma focused tests

Run inputs from this directory so their relative species, surface, and
reaction-file paths resolve.

Deterministic serial cases:

- `in.face_nsite_noleave`: a legacy nsite resident survives two incompatible
  impacts; only the incident particles remain in the gas.
- `in.face_only_one_noleave`: the globally unique one-site resident survives
  two incompatible impacts.
- `in.face_gank_noallow_noleave`: a full noallow inventory remains full after
  an incompatible arrival and is then consumed by two compatible arrivals.

- `in.face_gank_allow`: `every_n=2 allow` retains five C simulator particles
  and then completes five C+O reactions, proving compatible matching beyond
  the first logical capacity chunk.
- `in.face_gank_noallow`: two C particles fill their inventory; a third C
  triggers same-species double scattering and leaves one stored C, which a
  following O consumes.
- `in.face_gank_no`: explicit `gank no` retains the legacy `nsite` parser and
  behavior. Omitting both `gank` and `only_one` remains the same legacy path.
- `in.surf_gank_inventory_dump`: writes the four gank inventory columns to an
  independent `dump surf` file. Its final bottom-surface state is
  `C=1, O=0, N=1, CO=1`, and the other three surfaces remain empty. Supply the
  output path with, for example,
  `-var OUTFILE '/tmp/gank_inventory.*.dat'`.
- `in.face_only_one_cycle`: `only_one yes` omits `nsite`; an empty-face
  adsorption followed by a matching impact completes one reaction cycle.
- `in.face_only_one_unmatched`: an unmatched occupied single site emits both
  particles and becomes vacant when `noleave` is omitted.
- `in.face_only_one_no`: explicit `only_one no` retains the legacy
  `nsite`-based parser and behavior.
- `in.surf_only_one`: replicated explicit surfaces use one site per element.
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

- `in.surf_gank_inventory_dump` can also be run on 2 and 4 ranks; its final
  per-ID inventory must match the serial result even if MPI changes row order.

- `in.mpi_face_gank_stress`: x-partitioned ranks update the same global box
  face inventory and stress atomic vector read/modify/write arbitration.
- `in.mpi_surf_gank_coarse`: coarse explicit surfaces spanning several grid
  partitions stress unique-owner per-species inventories.
- `in.mpi_surf_only_one_distributed`: distributed explicit surfaces stress
  one-site owner/ghost state consistency.
- `in.mpi_face_only_one_stress`: x-partitioned ranks collide with the same
  global box faces and stress strict cross-rank one-site arbitration.
- `in.mpi_surf_only_one_coarse`: four coarse explicit elements span multiple
  MPI grid partitions and stress strict global one-site ownership.
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
`in.gank_invalid_capacity` and `in.gank_inactive_partner` are also expected
failures: `every_n` must be positive, and each positive-gamma gank species must
have a mapped partner whose gamma is also positive.
