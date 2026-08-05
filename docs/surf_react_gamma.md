# `surf_react gamma`

## Purpose

The `gamma` style implements gas/surface recombination with a prescribed,
temperature-independent recombination coefficient for each incident gas
species. It contains no particle-surface (PS) reaction clock and therefore has
no user-facing `nsync` argument.

## Command syntax

```text
surf_react ID gamma [noleave] file_name surf|face Tw n_site [init_cover species fraction] ... [tally_only yes|no] [species gamma] ...
surf_react ID gamma only_one no [noleave] file_name surf|face Tw n_site [init_cover species fraction] ... [tally_only yes|no] [species gamma] ...
surf_react ID gamma only_one yes [noleave] file_name surf|face Tw [tally_only yes|no] [species gamma] ...
surf_react ID gamma gank no [noleave] file_name surf|face Tw n_site [init_cover species fraction] ... [tally_only yes|no] [species gamma] ...
surf_react ID gamma gank yes every_n N allow|noallow [noleave] file_name surf|face Tw [tally_only yes|no] [species gamma] ...
```

- `ID` is the user-defined surface-reaction model ID.
- `file_name` contains the allowed two-reactant/one-product reactions.
- `surf` applies the model to explicit surface elements; `face` applies it to
  box faces.
- `Tw` is the wall temperature in K and must be positive.
- `only_one` must immediately follow `gamma`. It accepts `yes` or `no` and
  defaults to `no` when omitted.
- With `only_one no`, `n_site` is the site number density and must be
  positive. This is the original, backward-compatible behavior.
- With `only_one yes`, `n_site` is omitted and every box face or explicit
  surface element has exactly one globally shared site. `init_cover` is not
  accepted; every site starts vacant.
- `gank` must immediately follow `gamma`. Omitting both `gank` and `only_one`,
  or specifying `gank no`, selects the original `n_site` mode.
- `gank yes` omits `n_site` and requires `every_n N allow|noallow`. `N` is a
  positive integer number of DSMC simulator particles and is an independent
  capacity for every storable species on every face/element. `init_cover` is
  not accepted and all inventories start empty.
- `noleave` is an optional bare keyword placed after the selected site-mode
  clause and before `file_name`. If an incident particle passes its gamma gate
  but no reaction executes, already stored particles remain on the surface and
  only the incident particle undergoes the configured ordinary scattering.
  Omitting `noleave` preserves the original release behavior.
- `init_cover species fraction` may be repeated for different species.
  Fractions must lie in `[0,1]` and their sum may not exceed one.
- `tally_only` defaults to `no`.
- Remaining arguments are gas-species/coefficient pairs. Coefficients must lie
  in `[0,1]`. Any defined gas species omitted from the command has gamma zero.

Species may not be repeated in the coefficient list or in `init_cover`.
`init_cover` and `tally_only` are reserved option words. Unlike the `adsorb`
style, this command intentionally does not accept `nsync` or `schu`.

Example:

```text
surf_react recomb gamma gamma.surf face 1000.0 6.022e18 init_cover O 0.25 init_cover N 0.10 tally_only no O 0.5 N 0.2
bound_modify zlo react recomb
```

Single-site example:

```text
surf_react recomb gamma only_one yes gamma.surf surf 1000.0 O 1.0
surf_modify all react recomb
```

Keep the single resident after an incompatible impact:

```text
surf_react recomb gamma only_one yes noleave gamma.surf surf 1000.0 O 1.0 C 1.0
surf_modify all react recomb
```

Well-mixed per-species inventory example:

```text
surf_react recomb gamma gank yes every_n 10 noallow gamma.surf surf 300.0 O 1.0 N 1.0 C 1.0 CO 1.0
surf_modify all react recomb
```

## Reaction file

Each reaction consists of two effective lines:

```text
A + B --> C
h
```

`A` and `B` are an unordered pair of reactants and `C` is the single gas
product. All three names must already be defined by the `species` command.
The heat `h` is the physical heat of one reaction event in J:

- `h > 0`: heat released to the wall;
- `h < 0`: heat absorbed from the wall;
- `h = 0`: no chemical heat.

Blank lines, full-line comments, and inline text after `#` are ignored on both
formula and heat lines. A missing heat line, extra formula token, extra heat
value, undefined species, or duplicate unordered reactant pair is an error.
Thus defining both `A + B --> C` and `B + A --> C` is not allowed.

Example:

```text
# Oxygen recombination
O + O --> O2
8.19e-19

N + O --> NO     # reactant order is immaterial
5.20e-19
```

## Event algorithm

For an incident gas particle of species `A`:

1. The chemistry gate succeeds with probability `gamma_A`. A failed gate
   leaves the event to the configured ordinary surface-collision model.
2. On success, one site is sampled uniformly from the element/face capacity.
   With `only_one yes`, this is the element/face's sole global site.
3. If the sampled site is vacant, `A` adsorbs: the gas particle is removed and
   one `A(s)` site is added. This implicit adsorption is not a file reaction
   and does not increment surface-reaction tallies.
4. If the site contains `B(s)` and the file defines `A + B --> C` in either
   reactant order, one `B(s)` is consumed and the incident particle record is
   changed to the sole gas product `C`.
5. If the occupied species has no matching file reaction, the default behavior
   releases the stored particle and scatters both particles diffusely at `Tw`,
   leaving the site vacant. With `noleave`, the stored particle and coverage
   are unchanged and only the incident particle scatters.

The emitted product is internally scattered by a fully accommodating diffuse
model at `Tw`. Translational energy is sampled at `Tw`; rotational and
vibrational energy use SPARTA's standard particle samplers and are active when
the corresponding gas collision energy styles are active.

With `only_one no`, the site capacity used for a face or explicit element is

```text
Ncapacity = ceil(n_site * area / (fnum * weight))
```

which follows the existing `adsorb` storage convention.

With `only_one yes`, the capacity is exactly one and is independent of area,
`fnum`, particle weight, and MPI process count.

## `gank yes`: compatible well-mixed inventories

`gank yes` replaces spatial site sampling with an independent inventory count
for every surface reactant species on every face/element. Counts are numbers
of DSMC simulator particles, not physical molecules and not coverages derived
from `n_site`.

After the incident particle passes its species gamma gate, all stored species
that have a mapped reaction with the incident species form the compatible set.
If their counts are `n_B`, partner `B` is selected with probability

```text
P(B | A) = n_B / sum_j(n_j)
```

over compatible species only. One selected `B` is consumed, the mapped gas
product is emitted at `Tw`, and the normal reaction and heat tallies apply.
Partner matching always precedes capacity handling, including when an
inventory is full.

If no compatible partner exists:

- with `allow`, the incident species adsorbs. Its logical capacity begins at
  `N` and grows in chunks of `N`; the implementation stores a 64-bit count, so
  logical expansion does not reallocate or rebuild the MPI window;
- with `noallow`, the incident species adsorbs while its own inventory count is
  below `N`. At `N`, one stored particle of the same species is removed and it
  and the incident particle both scatter diffusely at `Tw`, leaving count
  `N-1` and producing no reaction heat. With `noleave`, a full inventory
  remains at `N` and only the incident particle scatters.

Different species do not share a capacity. A positive-gamma species must have
at least one mapped reaction partner that also has positive gamma; otherwise
the command is rejected to prevent a permanently non-consumable inventory.

## Outputting per-species inventories

For explicit surfaces (`surf` mode), the current inventory is already mirrored
to the per-surface custom array

```text
gamma_ID_species
```

where `ID` is the `surf_react` ID. It can be written to a separate file without
adding inventory state to the collision-tally columns produced by `compute
surf`. For example, if the reaction ID is `gamma`:

```text
dump inventory surf all 10000 data/adsorbed_species.*.dat id s_gamma_gamma_species[*]
```

The wildcard expands to one column per surface species. At initialization,
rank zero prints the exact mapping, for example:

```text
Gank inventory dump fields:
  s_gamma_gamma_species[1] = C
  s_gamma_gamma_species[2] = O
  s_gamma_gamma_species[3] = N
  s_gamma_gamma_species[4] = CO
```

Column order follows the order of the selected species in the SPARTA species
list, so input scripts and post-processing should use the printed mapping
rather than infer the order from the gamma coefficient list or reaction file.
The values are instantaneous, dimensionless counts of adsorbed DSMC simulator
particles. They are not divided by area or time and are not multiplied by
`fnum` or particle weight. The optional total count is available as
`s_gamma_ID_total`.

MPI output row order is not guaranteed to follow surface ID order. Always
include the `id` field and join or sort rows by that ID in post-processing. The
inventory custom array is created by `surf_react gamma`, so the `dump` command
must appear after the corresponding `surf_react` command. This custom-array
output applies to explicit surfaces; `face` mode does not create dumpable
per-surface custom attributes.

## Energy and heat tallies

For executed recombination,

```text
echem = h
etot  = E_incident - E_product + h
```

where each particle energy contains the translational, rotational, and
vibrational components enabled by SPARTA. Positive values heat the wall.

For vacancy adsorption there is no file reaction, so `echem=0`; removal of the
incident particle contributes its full incident particle energy to `etot`.
For monatomic O this is its translational energy because its rotational and
vibrational energies are zero.

SPARTA's `compute boundary` and `compute surf` outputs apply their normal
particle-weight, area, and timestep normalization to these per-event values.
The stored reaction-file `h` itself remains J per physical event.

## `tally_only`

With `tally_only yes`, a gamma-gated occupied-site match increments the
`sr_ID` candidate counters but:

- does not consume coverage;
- does not change the gas species;
- does not execute chemical heat;
- returns control to the configured ordinary surface-collision model.

Therefore `nsreact` stays unchanged, while `sr_ID` records candidates. The
ordinary nonreactive wall collision can still contribute its normal
particle/wall energy exchange to `etot`; `echem` remains zero.

Vacancy samples do not adsorb and do not count as reaction candidates in this
mode.

## Occupied sites without a mapped reaction

After a successful gamma trial, if the selected site is occupied but the
unordered incident/adsorbed species pair is not defined in the reaction file,
the event follows the DS2V separate-emission rule:

- one stored surface particle is removed from the selected site;
- the incident particle keeps its species;
- a second gas particle is created with the stored particle's species;
- both particles are diffusely, fully accommodated at `Tw`;
- the event has reaction number zero, increments no reaction counter, and
  contributes no `echem`.

The ordinary particle-energy exchange of both emitted particles remains
visible in the standard surface or boundary energy tally. With
`tally_only yes`, neither the coverage removal nor second-particle creation is
performed.

## MPI behavior

There is no PS time evolution and no `nsync` setting. Coverage changes are
committed every timestep. With `only_one no`:

- `face` mode sums per-rank species deltas with `MPI_Allreduce`;
- replicated explicit surfaces collate deltas by surface ID and spread the
  owned state;
- `global surfs explicit/distributed` uses the corresponding distributed
  owner/ghost collate and spread paths.

Per-explicit-surface custom attributes are namespaced by reaction ID
(`gamma_ID_*`) so independent gamma models do not share coverage storage.
State bounds are checked after synchronization; negative counts or capacity
overflow are fatal errors rather than silently breaking conservation.

With `only_one yes`, each global surface ID has one state slot on a unique MPI
owner. After a successful gamma trial, the collision rank acquires an
exclusive passive-target MPI lock on that slot, reads and updates the occupied
species as one serialized operation, and then performs the particle changes
locally. Thus a surface spanning several grid partitions still has one site,
not one site per rank. The owner state is mirrored to the existing output
attributes at the end of each timestep. This strict arbitration adds one-sided
MPI communication to each gamma-gated event and can cost more than the
batched-delta path used by `only_one no`.

With `gank yes`, each global surface ID instead owns one 64-bit inventory
vector. Every gamma-gated collision locks the unique owner, fetches the entire
vector, performs weighted compatible selection and the count update as one
atomic read/modify/write transaction, then unlocks it. At the end of each
timestep the authoritative counts are mirrored into the existing
`gamma_ID_total` and `gamma_ID_species` output attributes. This provides strict
cross-rank capacity and consumption semantics for faces, replicated surfaces,
and explicit/distributed surfaces.

The owner window is initialized through a self-target `MPI_Put` enclosed by
`MPI_Win_lock`/`MPI_Win_unlock`. All `MPI_Get`, `MPI_Put`, and
`MPI_Win_flush` calls are therefore executed within a passive-target epoch;
the implementation does not use `MPI_Win_sync` outside an epoch.

The current implementation is the standard CPU/MPI path and is not a new
Kokkos reaction kernel.
