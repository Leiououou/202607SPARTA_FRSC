# Task Plan: 常复合系数 gamma 计算与 SPARTA 接入设计

## Goal
基于当前 SPARTA 分支，确定常复合系数 gamma 的定义、计算输入输出、代码落点、验证方法，并形成可实施方案。

## Phases
- [complete] 1. 盘点现有表面反应、schu、输入文件与测试结构
- [complete] 2. 明确 Zuppardi/DS2V 中 gamma 与事件概率的关系
- [pending] 3. 设计独立计算模块及 SPARTA 输入接口
- [pending] 4. 设计验证算例、守恒检查与实施顺序
- [pending] 5. 经用户批准后，为 adsorb GS 反应文件增加必填的逐反应化学能（J/真实反应，吸热为正），并接入 `compute surf echem/etot`

## Scope
本轮以架构分析和实施建议为主，不修改求解器行为。

## Errors
- 无
## Adsorb reaction-energy implementation (2026-07-22)
- [completed] Parse a mandatory GS reaction energy after kinetic coefficients.
- [completed] Use positive-exothermic/negative-endothermic convention in `compute surf echem/etot`.
- [completed] Compile the modified translation units and validate representative input syntax.
- [blocked] Full MinGW serial link: existing `memory.cpp` requires POSIX allocation APIs unavailable in this toolchain.

## Compute boundary adsorb reaction heat (2026-07-22)
- [completed] 1. Add an `echem` value to `compute boundary`.
- [completed] 2. Resolve the face reaction model and read the current GS reaction energy.
- [completed] 3. Add reaction heat to `echem` and `etot` with positive-exothermic convention.
- [completed] 4. Verify zero/no-reaction behavior and output-column indexing.
- [completed] 5. Run positive, negative, and zero reaction-energy face tests.
- [completed] 6. Rebuild and validate Linux MPI `spa_mpi` under Ubuntu 20.04.

### Scope
- Only boundary heat tallies for already-read GS reaction energy.
- No changes to reaction probability, coverage evolution, product energy allocation, or PS chemistry.

### Errors
- Two-rank test with a one-cell grid: `Run command before grid ghost cells are defined`; corrected the test to use two grid cells.
- Two cells with the default partition still produced no usable ghost layout; added RCB balancing for a clumped two-rank partition.

## Extend `schu` control to PS reactions (2026-07-27)

### Goal
Extend the existing `surf_react adsorb ... schu yes|no` switch to PS chemistry.
For `gs/ps`, one shared `schu` value controls both pathways:
- `schu yes`: GS uses the existing Schumakova/Molchanova branch, and PS uses the Molchanova number-density form.
- `schu no`: GS and PS retain the current/original behavior.

### Scope
- Included: PS reaction-frequency calculation, backward compatibility, documentation, focused tests, and compilation.
- Excluded: PS reaction-energy parsing/tallying, constant-gamma chemistry, and product-energy redistribution.

### Phases
- [complete] 1. Establish a clean baseline
  - Inspect `git status` and preserve unrelated user changes.
  - Locate the existing `schu` parser, default value, member declaration, GS branch, PS frequency block, docs, examples, and build entry points.
  - Record the exact baseline formulas and compile command before editing.
- [complete] 2. Lock down the PS formula and reaction-order handling
  - Keep `factor = fnum*weight/area` as the model-count to surface-number-density factor.
  - Keep `coverage_factor = factor/max_cover` for coverage and vacant-site terms.
  - For non-SB adsorbed-reactant frequency factors, use:
    - `schu no`: `coverage_factor^(alpha-1)` (existing behavior).
    - `schu yes`: `factor^(alpha-1)` (Molchanova number-density behavior).
  - Reuse the existing `factor_pow = alpha-1`; do not hard-code one multiplication by `max_cover`.
  - Preserve first-order desorption: `factor_pow=0`, so `schu yes/no` gives the same `nu=k*N`.
  - Preserve SB vacant-site coverage as `1-total_state*factor/max_cover`; do not remove `max_cover` from this physical coverage term.
- [complete] 3. Implement the smallest source change
  - Reuse the existing `schu_flag`; do not add a second PS-only keyword or flag.
  - Modify only the PS frequency-factor selection inside `SurfReactAdsorb::PS_react()`.
  - Ensure `gs`, `ps`, and `gs/ps` modes all accept the same existing keyword semantics.
  - Keep default behavior unchanged when `schu` is omitted or set to `no`.
  - Add concise comments distinguishing number-density and coverage factors.
- [complete] 4. Add focused verification cases
  - Parser/mode matrix: `gs`, `ps`, and `gs/ps`, each with `schu yes` and `schu no`.
  - First-order DS check: identical `nu` behavior for `yes` and `no`.
  - Second-order distinct-species LH check: `nu_yes/nu_no = max_cover`.
  - Second-order same-species LH check: preserve `N(N-1)/2` and verify the same scaling ratio.
  - Mixed PS competition check: confirm the intended absolute frequency change and document that reaction selection can also change when reaction orders differ.
  - SB check: verify vacant-site coverage still uses `max_cover`.
  - `gs/ps` regression: confirm one `schu yes` activates both the existing GS branch and the new PS branch.
- [complete] 5. Update user-facing documentation
  - State explicitly that `schu` controls both GS and PS for `gs/ps`.
  - Define the expected PS rate-constant basis:
    - `schu yes`: surface number-density-based `k`.
    - `schu no`: legacy coverage-based implementation.
  - State the general conversion `k_coverage = k_density * max_cover^(alpha-1)`.
  - Note that first-order desorption is unchanged.
- [complete] 6. Compile and validate
  - Compile the modified translation unit first for fast syntax/type feedback.
  - Build the normal SPARTA executable using the repository's established Linux/MPI build path.
  - Run the focused PS cases and at least one existing `surf_react_adsorb` regression example.
  - Record compiler command, executable path/hash, test inputs, numerical expectations, and actual results.
- [complete] 7. Review and handoff
  - Inspect the final diff to confirm no PS reaction-heat changes were included.
  - Report changed files, formulas before/after, compatibility behavior, compile result, and test evidence.

### Acceptance criteria
- A single existing `schu` flag controls both GS and PS when mode is `gs/ps`.
- `schu no` reproduces the pre-change PS frequency formula.
- `schu yes` uses `factor^(alpha-1)` for Molchanova-style PS number-density kinetics.
- DS remains unchanged and SB vacancy coverage remains physically normalized by `max_cover`.
- The target SPARTA executable builds successfully and focused tests match analytical scaling.

### Result
- Implemented the shared GS/PS `schu` behavior in `PS_react()`.
- Targeted compilation and Windows serial executable link succeeded.
- Second-order LH, first-order DS, and `gs/ps` shared-flag tests passed.
- Rebuilt Linux MPI `src/spa_mpi` under WSL Ubuntu 20.04 with `/usr/bin/mpic++`; the focused PS regression passed.

## Extend `tally_only` to PS reactions (2026-07-27)

### Goal
Make the existing `tally_only yes|no` keyword control PS chemistry as well as
GS chemistry.  In `gs/ps` mode one shared value must apply to both pathways.

### Semantics
- `tally_only no`: preserve normal GS and PS execution.
- `tally_only yes`: continue evaluating, selecting, and counting eligible
  reactions, but do not change physical simulation state.
- For PS reactions, a selected event must still consume its sampled waiting
  time from the selected `tau`; otherwise the unchanged state would repeatedly
  select the same overdue event and could create an infinite loop.
- PS tally-only events must not:
  - change `species_delta`, `species_state`, or `total_state`;
  - create gas particles;
  - apply product collision/scattering models.

### Phases
- [complete] 1. Confirm the PS event-loop insertion point and current GS behavior.
- [complete] 2. Insert the PS tally-only branch after event tally and `tau` update,
  but before reactant/product state changes and particle creation.
- [complete] 3. Make the startup tally-only banner visible for PS-only mode.
- [complete] 4. Add focused `ps` and `gs/ps` tests comparing `tally_only yes/no`.
- [complete] 5. Verify event counts continue while surface state and particle count
  remain unchanged under `tally_only yes`.
- [complete] 6. Rebuild Windows serial and WSL Ubuntu MPI executables.
- [complete] 7. Run regression tests, inspect the final diff, and write a dedicated
  modification log.

### Acceptance criteria
- `adsorb ps ... tally_only yes` counts sampled PS events without executing them.
- `adsorb gs/ps ... tally_only yes` suppresses physical execution of both pathways.
- PS `tau` progresses normally and the event loop terminates.
- `tally_only no` retains the pre-change PS behavior.
- Both serial and MPI executables compile and pass focused tests.

### Result
- PS-only and `gs/ps` now use the shared `tally_only_flag`.
- Selected PS events are tallied and advance `tau`, then skip all state and
  product mutations.
- Serial, one-rank MPI, and two-rank MPI focused tests passed.
- Rebuilt `src/spa_serial.exe` and `src/spa_mpi`; hashes are recorded in
  `change_logs/2026-07-27_ps_tally_only.txt`.

## Implement independent constant-`gamma` surface reaction style (2026-07-28)

### Goal
Add a new, independent `surf_react gamma` style for constant recombination
coefficients without changing `surf_react_adsorb.cpp` or
`surf_react_adsorb.h`.

### Frozen user-facing syntax

```text
surf_react ID gamma file_name surf|face Tw n_site
  [init_cover species fraction] ...
  [tally_only yes|no]
  [species gamma] ...
```

- Unlisted gas species have `gamma=0`.
- `init_cover` may be repeated for multiple surface species.
- There is no user-facing `nsync`: this style has no PS chemistry or `tau`.
- Surface coverage deltas are nevertheless synchronized internally at the end
  of every timestep for MPI consistency.

### Frozen reaction-file format
- Reactions occur in pairs of effective lines; blank and comment lines follow
  existing SPARTA reaction-file conventions.
- Line 1: exactly two unordered reactants and exactly one gas product,
  e.g. `O + O --> O2`.
- Line 2: one reaction heat `h` in J per real event.
- Positive `h` heats the wall; negative `h` cools the wall.
- `A + B` and `B + A` are the same key; duplicate unordered pairs are errors.
- A successful event is physically `A(g)+B(s) -> C(g)`: one adsorbed `B` is
  consumed and one gas product `C` leaves the wall.

### Frozen event semantics
- For incident species `A`, first sample the configured constant `gamma_A`.
- Outside the gamma branch, return to the ordinary bound/surface collision
  model without changing chemistry state.
- Inside the gamma branch, sample vacant sites and adsorbed species by their
  current fractions.
- Vacant site: adsorb `A`, remove the incident gas particle, add one `A(s)`.
- Occupied `B` with a defined unordered reaction: consume one `B(s)`, transform
  the incident particle record into outgoing `C(g)`, and fully diffusely
  accommodate it at `Tw`.
- Occupied `B` without a defined channel: return to ordinary scattering.
- Normal reaction tally counts only file-defined recombination events; implicit
  adsorption is a surface-state transition and has no reaction-file tally ID.
- `tally_only yes` samples and counts recombination candidates at fixed state,
  but changes no particle or surface state and contributes no physical heat.

### Heat-flux semantics
- Adsorption: no `echem`; wall particle-energy gain is the incident particle
  energy because there is no gas product.
- Recombination: `echem=h` and
  `etot=E_incident-E_outgoing_product+h`.
- Product translational, rotational, and vibrational modes are fully
  accommodated at `Tw`.
- Existing GS/PS energy and heat-flux behavior remains untouched.

### Phases
- [complete] 1. Audit extension interfaces and preserve the dirty baseline
  - Record existing user changes and confirm adsorb files remain untouched.
  - Inspect style registration, `SurfReact` virtual interfaces, surface/grid
    change notifications, tally calls, diffuse wrappers, and build generation.
  - Decide ID-scoped custom attribute names so multiple reaction instances do
    not collide.
- [complete] 2. Implement the independent style and input parser
  - Add `src/surf_react_gamma.h` and `src/surf_react_gamma.cpp`.
  - Register `SurfReactStyle(gamma,SurfReactGamma)`.
  - Validate fixed arguments, repeated keywords, species/gamma pairs,
    duplicates, numeric ranges, mode compatibility, and explicit surfaces.
  - Keep gamma values in a species-indexed array with zero defaults.
- [complete] 3. Implement strict reaction-file parsing and lookup
  - Reuse SPARTA's two-effective-line/comment-reading conventions.
  - Validate exactly `A + B --> C` and one numeric heat value.
  - Resolve all species IDs during initialization.
  - Build unordered reactant-pair lookup without file-order bias.
  - Reject duplicate pairs, undefined species, extra tokens, and malformed
    formulas.
- [complete] 4. Implement coverage state and MPI synchronization
  - Build the surface-species set from gamma inputs, initial coverage, and
    reaction reactants.
  - Allocate per-face state/delta arrays and perform `MPI_Allreduce` each step.
  - Allocate ID-scoped per-surf custom state and collate deltas in the same
    style as SPARTA's existing explicit-surface chemistry.
  - Implement grid-change reallocation/spread handling for distributed surfs.
  - Apply `init_cover` consistently from `n_site`, area, `fnum`, and weight.
  - Use current local pending deltas when sampling to avoid same-rank stale
    state and prevent negative local counts.
- [complete] 5. Implement reaction execution and thermal accommodation
  - Sample the gamma gate, vacancy/occupant branch, and unordered channel.
  - Execute adsorption by deleting the incident gas particle and incrementing
    the selected surface count.
  - Execute recombination by consuming one adsorbate and converting the
    incident particle to the sole gas product.
  - Reuse SPARTA diffuse-collision machinery with full accommodation at `Tw`;
    set `velreset` so the outer collision model does not resample the product.
  - Return file reaction indices for standard reaction tallies.
- [complete] 6. Connect tally-only and heat behavior
  - Count only selected file-defined recombination candidates.
  - Under tally-only, return no executed reaction and mutate no physical state.
  - Return per-reaction `h` through `reaction_coeff()` so existing
    `compute surf` and `compute boundary` paths add `echem` once.
  - Verify adsorption contributes incident particle energy but no `echem`.
- [complete] 7. Add documentation and focused tests
  - Document syntax, defaults, file format, state model, heat signs,
    `init_cover`, `tally_only`, and MPI synchronization.
  - Parser/error tests and default-gamma-zero test.
  - Empty-surface adsorption and initialized-coverage recombination tests.
  - Homonuclear and heteronuclear direction-symmetry tests.
  - `gamma=0`, `0.5`, and `1` statistical tests.
  - Positive/zero/negative reaction-heat tests for `echem` and `etot`.
  - `face` and explicit `surf` tests in serial, one-rank MPI, and two-rank MPI.
  - Conservation checks: two reactant atoms produce one gas molecule and no
    surface count becomes negative or exceeds the modeled capacity.
- [complete] 8. Build, regress, and review
  - Compile the new translation unit before a full executable build.
  - Build Windows serial and the established WSL Linux MPI executable when
    available.
  - Run focused gamma tests plus representative existing `prob` and `adsorb`
    regressions.
  - Confirm `src/surf_react_adsorb.cpp/.h` have no new diff from this task.
  - Inspect MPI behavior and final diff; record commands, hashes, expected and
    actual results in a dedicated change log.

### Acceptance criteria
- The exact proposed `surf_react gamma` syntax works without `nsync`.
- Omitted species have zero gamma; repeated `init_cover` and `tally_only` have
  the agreed fixed-state semantics.
- Reaction matching is symmetric and unbiased with respect to file ordering.
- Every executed recombination consumes one surface reactant and emits exactly
  one gas product diffusely at `Tw`.
- Adsorption and recombination heat tallies follow the agreed particle-energy
  and chemical-energy equations.
- `face` and `surf` states remain consistent in two-rank tests.
- Existing adsorb source/header files are not modified by this implementation.
- New code follows nearby SPARTA allocation, MPI, random-number, error, and
  style-registration conventions.

### Errors
- PowerShell `rg` calls using Unix-style wildcard path operands such as
  `src/*.h` and queries against a missing top-level `cmake` directory returned
  path errors during phase-1 discovery. Resolution: use explicit file paths,
  `rg -g` filters, and `Get-ChildItem -Filter` on Windows; no source state was
  changed by the failed read-only command.
- A later read-only CMake search repeated the missing top-level `cmake`
  operand once. Resolution remains to search only discovered paths such as
  `src/CMakeLists.txt`; the useful query results were unaffected.
- First standalone compilation of `surf_react_gamma.cpp` failed because
  `update.h` only forward-declares `RanMars`, while the constructor calls
  `update->ranmaster->uniform()`. Resolution: include `random_mars.h`, matching
  nearby SPARTA reaction implementations, then recompile.
- The second standalone compile passed C++ compilation but MinGW's assembler
  could not create `../tmp/surf_react_gamma.o` (`Permission denied`) from the
  Unicode workspace path. Resolution: emit the temporary object in the current
  `src` directory, which is the normal build-output location, instead of
  repeating the failing relative output path.
- Native PowerShell invocation of `mingw32-make serial -j4` failed in the
  top-level Makefile shell condition with `serial was unexpected at this
  time`; the Makefile declares `/bin/bash` and is not cmd.exe-compatible.
  Resolution: drive the same target through MSYS2 Bash, or use the established
  WSL build path if Unicode-path translation prevents MSYS2 use.
- First MSYS2 Bash retry reached the translated workspace but the login-shell
  PATH did not contain `mingw32-make`; first-run setup also printed a harmless
  sandbox-home permission warning. Resolution: call
  `/mingw64/bin/mingw32-make.exe` explicitly without changing system HOME.
- Explicit MSYS2 make started the correct dependency build, but sub-make
  `/usr/bin/sh` could not find `g++`; the short diagnostic command also timed
  out after the build had already reported the error. Resolution: export an
  MSYS-local PATH containing `/mingw64/bin:/usr/bin` for make and all
  sub-shells, then use a normal build timeout.
- With the compiler PATH fixed, full build compilation reached
  `compute_boundary.cpp` but MinGW could not create compiler temporaries in
  sandboxed `D:\msys64\tmp`. Resolution: point compiler temporary variables
  at the current writable `Obj_serial` build directory; do not request access
  to or modify the system MSYS directory.
- Workspace-local compiler temporaries allowed the complete Windows serial
  compile and link, including `surf_react_gamma.o`, to finish. Make returned
  nonzero only because its Unix `size ../spa_serial` post-link command omitted
  MinGW's automatic `.exe` suffix; `src/spa_serial.exe` was successfully
  regenerated. Resolution: treat the post-link `size` mismatch as an
  environment-specific reporting failure and verify the `.exe` directly.
- A read-only search included a nonexistent top-level `examples` operand while
  locating reusable test inputs. Resolution: use the repository's discovered
  `test` directories and explicit paths; no files were changed by the failed
  search.
- The first deterministic input reached `create_particles` but failed because
  defining species does not implicitly create the `air` mixture. Resolution:
  add `mixture air O O2` to every compact O/O2 test before particle creation.
- The next runtime reached stats setup but rejected `sr_grxn[3]`: the new
  model had allocated per-reaction tallies but had not expanded the inherited
  `size_vector` beyond its default two aggregate entries. Resolution: set
  `size_vector = 2 + 2*nlist`, matching `prob` and `adsorb`; the same review
  also added the standard derived-destructor `if (copy) return` guard.
- The first explicit-cylinder test placed its particle outside the file's
  classified flow region and `create_particles single` correctly rejected it.
  The imported circle defines its interior as flow volume, so the fixture was
  corrected to start at `x=0.0004` and move outward toward the `x=0.0005`
  surface from inside.
- That corrected point still lay in a coarse-grid split cell on the symmetry
  axis and was not uniquely assignable by `create_particles single`.
  Resolution: move the start off both axes to `(0.0001,0.0001)` and use a
  radial `(100,100)` velocity, avoiding split-boundary ambiguity.
- The off-axis interior point was also rejected, showing the circle's actual
  accepted gas side is its exterior despite the diagnostic volume wording.
  The fixture was therefore moved to off-axis exterior flow at
  `(0.001,0.0001)` with an inward radial velocity.
- Deterministic `single` insertion remained unsuitable for this legacy
  cylinder because all gas volume is represented by split cells and the
  command requires one ordinary OUTSIDE cell. Resolution: use the established
  `create_particles ... n` path to populate 1,000 O atoms in the valid split
  volume, then assert O-to-O2 conversion with `compute count`; this tests the
  explicit-surface state path without relying on ambiguous insertion geometry.
- A read-only `rg` invocation used an unclosed regular expression while
  locating the global distributed-surface keyword. Resolution: repeat with
  literal/simpler patterns. The required syntax was found as
  `global ... surfs explicit/distributed`; no repository state was affected.

### Runtime-test preparation notes
- `create_particles MIX single SPECIES x y z vx vy vz` provides deterministic
  one-impact tests for a `face` boundary.
- Existing compact test inputs use `boundary oo oo so`, so `zlo` is a surface
  face and `zhi` is outflow; a particle at `z=0.1` with `vz=-1` and a
  sufficiently large single timestep gives one controlled wall impact.
- Initial runtime cases will isolate: empty-site adsorption, full-coverage
  recombination, `tally_only`, omitted-gamma default zero, and both orders of a
  heteronuclear reaction. Statistical, explicit-surface, and MPI cases follow
  after these deterministic checks pass.

Completion note (2026-07-29): all Zuppardi supplemental literature-review
phases are complete.

## 2026-07-29 DS2V-style unmatched-pair double scattering

### Goal
Change only the constant-gamma occupied-site/no-reaction-map event so that
the incident particle and stored surface particle both leave the wall, matching
the Zuppardi/Mongelluzzo description of DS2V.

### Frozen event semantics
- Gamma trial fails: incident particle scatters normally; surface state is unchanged.
- Gamma trial passes and selects a vacancy: preserve current adsorption behavior.
- Gamma trial passes, selects an occupied site, and finds a mapped reaction:
  preserve current recombination, reaction tally, reaction heat, and product emission.
- Gamma trial passes, selects an occupied site, but finds no mapped reaction:
  remove one stored surface particle; preserve the incident species; create one gas
  particle with the stored species at the collision point; diffusely and fully
  accommodate both at the gamma wall temperature; return reaction ID zero and add
  no reaction tally or chemical heat.
- `tally_only yes`: do not mutate coverage and do not create the second particle.
- State synchronization remains deferred to the existing per-step delta reduction.

### Execution phases
- [complete] 1. Audit worktree and existing particle-creation conventions.
- [complete] 2. Freeze state, velocity, tally, heat, and `tally_only` semantics.
- [complete] 3. Implement the smallest source change in `surf_react_gamma.cpp`.
- [complete] 4. Add deterministic tests for both species, coverage decrement,
  reaction tally zero, and two-particle emission.
- [complete] 5. Add guard tests for gamma failure, mapped reaction, vacancy adsorption,
  and `tally_only`.
- [complete] 6. Compile and run serial face and explicit-surface cases.
- [complete] 7. Run statistical and two-rank MPI conservation/regression cases.
- [complete] 8. Review the final diff, update documentation, and record all results.

### Acceptance criteria
- One unmatched occupied-site impact changes gas model-particle count by +1 and
  stored coverage count by -1, conserving the total represented particle count.
- Outgoing species are exactly the incident species and the former stored species.
- Both outgoing normal velocities point away from the wall after diffuse reset.
- Surface reaction count and `echem` remain zero for the unmatched event.
- Existing mapped recombination results and gamma statistics remain unchanged.
- No stale pointer occurs when `add_particle()` reallocates particle storage.

## 2026-07-29 Zuppardi 文献补充核查
- [in_progress] 遍历 `D:\博一\气固相互作用\Zupparid` 中的论文并建立书目信息
- [pending] 检索并复核壁面催化反应、DS2V 实现、反射/复合与未定义反应相关原文
- [pending] 对照当前 constant-gamma 实现，形成有页码依据的结论与修改建议
