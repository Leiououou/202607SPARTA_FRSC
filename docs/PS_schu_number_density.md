# `schu` control for pure-surface reactions

The existing optional `schu yes|no` keyword of `surf_react adsorb` controls
both gas-surface (GS) and pure-surface (PS) chemistry.

- `schu no` (and the default when the keyword is omitted) preserves the
  legacy SPARTA PS frequency calculation based on surface coverage.
- `schu yes` uses the Molchanova surface-number-density form for PS
  reactions.  When the model is `gs/ps`, the same `schu yes` value also
  enables the existing finite-rate GS implementation.

For a PS reaction of surface order `alpha`, the two conversion factors are:

```text
number_density_factor = fnum * weight / area
coverage_factor       = number_density_factor / max_cover
```

The non-sublimation PS reaction frequency uses:

```text
schu no:  coverage_factor^(alpha-1)
schu yes: number_density_factor^(alpha-1)
```

Thus the two rate-constant conventions are related by:

```text
k_coverage = k_number_density * max_cover^(alpha-1)
```

First-order desorption is unchanged because `alpha-1` is zero.  The vacant
site fraction in sublimation reactions remains a coverage,
`1 - total_state*coverage_factor`, for both settings.

This change does not add reaction energy to the PS reaction-file format.
