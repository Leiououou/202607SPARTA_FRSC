# `tally_only` control for pure-surface reactions

The optional `tally_only yes|no` keyword of `surf_react adsorb` applies to
both gas-surface (GS) and pure-surface (PS) chemistry.  In `gs/ps` mode the
single value controls both pathways.

With `tally_only no`, reactions are counted and executed normally.

With `tally_only yes`, eligible PS events are still selected by the normal
multiple-time-counter algorithm and are included in the reaction tallies.
The selected reaction's sampled waiting time is subtracted from its `tau`,
which allows the event loop to progress normally.  The event is then treated
as hypothetical:

- adsorbed reactants are not removed;
- adsorbed products are not added;
- gas products are not created;
- product scattering/collision models are not invoked.

Consequently, PS tally-only counts describe events predicted at the unchanged
current surface state.  They are not depletion-limited.  This is intentional
and mirrors the GS tally-only principle of counting candidate reactions
without modifying the simulation state.

The `init_cover` keyword remains active in `ps` and `gs/ps` modes and can be
used to define the fixed surface state sampled by `tally_only yes`.
