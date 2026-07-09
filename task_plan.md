# Task Plan: SPARTA Finite-Rate Wall Chemical Reactions

## Goal
Modify `SurfReactAdsorb` to implement finite-rate wall chemical reactions following Molchanova, Kashkovsky, and Bondar (PoF 30, 107105, 2018), focusing on **AA (Adsorption)**, **ER (Eley-Rideal)**, and **LH3 (Langmuir-Hinshelwood type 3)** reactions.

## Approach
- **NOT** following SPARTA's existing probability structure
- Following the paper's classification into **Impact mechanisms** (velocity-dependent, P ∝ 1/Vn) and **Surface mechanisms** (time-based Poisson sampling)
- AA and ER are Impact mechanisms → remain in `react()` but with new formula
- LH3 becomes a Surface mechanism → move to `PS_react()` with frequency/time sampling

## Phases

### Phase 1: Create Planning Files & Deep Code Analysis
**Status:** in_progress
**Description:** Set up planning files and thoroughly read all relevant code sections (react() including normalization, PS_react, PS_chemistry, readfile_gs, readfile_ps)

### Phase 2: Read Remaining Paper Pages
**Status:** pending
**Description:** Complete reading pages 13-18 of the Molchanova et al. PDF for any remaining implementation details

### Phase 3: Data Structure Modifications
**Status:** pending
**Description:** Modify `OneReaction_GS` struct and header file for new parameters. Add Arrhenius parameters (A, b, Ea) for AA/ER/LH3 reactions. Add new style constants if needed.

### Phase 4: Implement AA (Adsorption) — Impact Mechanism
**Status:** pending
**Description:** Replace current AA probability `P = k_react × S(θ)` with `P(Vn) = min(1, 2×Kads(Tw)×NS×FN/(Se×Vn))` in `react()`. Handle NS = Nmax - Ntot dynamically.

### Phase 5: Implement ER (Eley-Rideal) — Impact Mechanism  
**Status:** pending
**Description:** Replace current ER probability with `P(Vn) = min(1, 2×KER(Tw)×NAS×FN/(Se×Vn))`. Fix the hard-coded `dot = 2.0` bug.

### Phase 6: Implement LH3 — Surface Mechanism
**Status:** pending
**Description:** Move LH3 from GS chemistry (`react()`) to surface mechanism. Implement time-based Poisson sampling: ν_LH = (1/2)×KLH×NAS×(NAS-1)×FN/Se, t_LH = -ln(Rn)/ν_LH. Integrate with existing PS chemistry.

### Phase 7: Modify File Parsing (readfile_gs / new readfile)
**Status:** pending
**Description:** Update reaction file parsing to accept paper-format Arrhenius parameters [A, b, Ea] instead of/alongside SPARTA's [prob, n] or [A, b, Ea, n] format.

### Phase 8: Testing & Verification
**Status:** pending
**Description:** Verify compilation, unit tests, and physical correctness of new implementation.

## Key Decisions Needed
1. AA: constant S0 (Warnatz/RCG model) vs Arrhenius Kads(T) (α-Al2O3 model)?
2. LH3: keep in react() as impact mechanism for now, or fully move to surface mechanism?
3. Input file format: keep SPARTA's existing format or define a new style keyword?
4. Keep the normalization/correction logic (`sum_prob > 1.0` → correction) or restructure entirely?

## Files to Modify
- [surf_react_adsorb.h](src/surf_react_adsorb.h)
- [surf_react_adsorb.cpp](src/surf_react_adsorb.cpp)

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| None yet | - | - |
