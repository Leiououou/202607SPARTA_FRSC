# `surf_react gamma`

## Purpose

The `gamma` style implements gas/surface recombination with a prescribed,
temperature-independent recombination coefficient for each incident gas
species. It contains no particle-surface (PS) reaction clock and therefore has
no user-facing `nsync` argument.

## Command syntax

```text
surf_react ID gamma file_name surf|face Tw n_site [init_cover species fraction] ... [tally_only yes|no] [species gamma] ...
```

- `ID` is the user-defined surface-reaction model ID.
- `file_name` contains the allowed two-reactant/one-product reactions.
- `surf` applies the model to explicit surface elements; `face` applies it to
  box faces.
- `Tw` is the wall temperature in K and must be positive.
- `n_site` is the site number density and must be positive.
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
3. If the sampled site is vacant, `A` adsorbs: the gas particle is removed and
   one `A(s)` site is added. This implicit adsorption is not a file reaction
   and does not increment surface-reaction tallies.
4. If the site contains `B(s)` and the file defines `A + B --> C` in either
   reactant order, one `B(s)` is consumed and the incident particle record is
   changed to the sole gas product `C`.
5. If the occupied species has no matching file reaction, the particle
   receives the configured ordinary surface collision.

The emitted product is internally scattered by a fully accommodating diffuse
model at `Tw`. Translational energy is sampled at `Tw`; rotational and
vibrational energy use SPARTA's standard particle samplers and are active when
the corresponding gas collision energy styles are active.

The site capacity used for a face or explicit element is

```text
Ncapacity = ceil(n_site * area / (fnum * weight))
```

which follows the existing `adsorb` storage convention.

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

## MPI behavior

There is no PS time evolution and no `nsync` setting. Coverage changes are
committed every timestep:

- `face` mode sums per-rank species deltas with `MPI_Allreduce`;
- replicated explicit surfaces collate deltas by surface ID and spread the
  owned state;
- `global surfs explicit/distributed` uses the corresponding distributed
  owner/ghost collate and spread paths.

Per-explicit-surface custom attributes are namespaced by reaction ID
(`gamma_ID_*`) so independent gamma models do not share coverage storage.
State bounds are checked after synchronization; negative counts or capacity
overflow are fatal errors rather than silently breaking conservation.

The current implementation is the standard CPU/MPI path and is not a new
Kokkos reaction kernel.
