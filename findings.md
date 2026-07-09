# Findings: SPARTA GS Chemistry Analysis & Paper Comparison

## 1. SPARTA's Current AA Implementation

**Location:** `surf_react_adsorb.cpp` lines 687-711

```cpp
case AA:
    double surf_cover = total_state[isurf] * ms_inv;
    double S_theta = 0.0;
    // Kisliuk or simple (1-θ)^n coverage dependence
    prob_value[i] = r->k_react * S_theta;
    // ip → NULL (particle disappears into surface)
```

**Key characteristics:**
- Probability is velocity-independent
- Coverage dependence S(θ) uses Kisliuk or (1-θ)^n models
- k_react precomputed at file read time using Twall
- Particle fate: ip = NULL (always adsorbed)

## 2. SPARTA's Current ER Implementation

**Location:** lines 804-817

```cpp
case ER:
    double dot = MathExtra::dot3(ip->v, norm);
    dot = 2.0;  // BUG: hard-coded, overwrites actual Vn!
    prob_value[i] = 2.0 * r->k_react * (maxstick - total_state[isurf]) * ms_inv / fabs(dot);
```

**Key characteristics:**
- `dot = 2.0` hard-coded — always overwrites actual normal velocity
- Particle fate: ip→ispecies = products[0] (becomes product gas particle)
- Uses (Nmax - Ntot) factor for co-reactant surface species

## 3. SPARTA's Current LH3 Implementation

**Location:** lines 764-782

```cpp
case LH3:
    // Same as AA: S(θ) based probability
    prob_value[i] = r->k_react * S_theta;
    // ip → NULL (particle disappears, surface reaction consumes it)
```

**Key characteristics:**
- Treated as GS impact mechanism (gas particle must hit wall)
- Same formula as AA but different particle fate and semantics
- The reaction is: A(g) + B(s) → AB(g) or similar — gas particle recombines with adsorbed species

## 4. Paper's Framework (Molchanova et al. 2018)

### Impact Mechanisms (AA, ER)
- **Core formula (Eq.35):** P(Vn) = 2 × K(Tw) × ζ / Vn
- **Recommended T = Tw** (wall temperature), not Tg (avoids unphysical energy threshold)
- **ζ (surface species density):**
  - AA: ζ = NS × FN / Se (free sites)
  - ER: ζ = NAS × FN / Se (adsorbed species of co-reactant)
- min(1, ...) truncation when probability exceeds 1

### Surface Mechanisms (LH, Desorption)
- Poisson process time sampling
- LH for same species (Eq.13): ν = (1/2) × KLH × NAS × (NAS-1) × FN / Se
- Time between events (Eq.14): t = -ln(Rn) / ν
- Desorption (Eq.8): τ = -ln(Rn) / Kdes

### Two Surface Models
1. **RCG (Warnatz, Table II):** S0 = 0.1 for AA, Arrhenius for others
2. **α-Al2O3 (Table III):** Full Arrhenius for all

## 5. Critical Differences Summary

| Feature | SPARTA Current | Paper Method |
|---------|---------------|--------------|
| AA probability | k_react × S(θ), no Vn dependence | 2×Kads(Tw)×NS×FN/(Se×Vn), ∝ 1/Vn |
| ER probability | k × (1-θ), dot=2.0 hard-coded | 2×KER(Tw)×NAS×FN/(Se×Vn), actual Vn |
| LH3 mechanism | Impact (GS) | Surface mechanism (time-based) |
| Coverage dependence | Explicit S(θ) function | Via ζ factor (NS or NAS) |
| K(T) evaluation | Once at file read | Dynamic (could recompute with Tw) |

## 6. Code Bugs Found
- **Line 806-807**: `dot` computed then immediately overwritten to 2.0 — actual normal velocity never used in ER
- **Line 658**: `coeff_val` initialized to 1 but not reset in for-loop — if prior reaction is ARRHENIUS, subsequent SIMPLE reactions get coeff_val=3
