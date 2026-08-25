# GenX_Robust

This branch of GenX accompanies the paper *Uncertainty-Aware Grid Planning in
the Real World: A Method Enabling Large-Scale, Two-Stage Adaptive Robust
Optimization for Capacity Expansion Planning* (Mantegna, Dimanchev, Pecci,
Patankar, and Jenkins). A research brief for the paper is available at
[zenodo.org/records/18856351](https://zenodo.org/records/18856351). This README
explains how to re-run the planning optimizations behind it.

Some context if you are new to these tools. [GenX](https://github.com/GenXProject/GenX)
is an open-source electricity system planning model written in Julia. Given
assumptions about future demand, technology costs, and policy, it decides what
mix of generation, storage, and transmission to build by solving a large
optimization problem. RESOLVE is the planning model the California Public
Utilities Commission (CPUC) uses for the same purpose in its Integrated
Resource Planning (IRP) process. Our study takes the CPUC's published RESOLVE
inputs for California, translates them into GenX format, and then solves both
a conventional single-forecast ("deterministic") plan and several robust plans
that hedge against a set of adverse futures.

This branch is ordinary GenX plus one commit adding the features the case
study needs, chiefly a representation of the CAISO transmission-deliverability
rules that are central to the paper's findings. The commit message lists the
additions in full.

Two notes on scope. First, the results in the paper were produced with an
earlier vintage of the CPUC's data. The cases here are the same four main
planning cases discussed in the paper, but built from the CPUC's current
dataset: the RESOLVE case published with the
[assumptions for the 2026-2027 transmission planning process (TPP)](https://www.cpuc.ca.gov/industries-and-topics/electrical-energy/electric-power-procurement/long-term-procurement-planning/2024-27-irp-cycle-events-and-materials/assumptions-for-the-2026-2027-tpp).
The expected results quoted below correspond to this newer dataset. Second,
this package covers the paper's standard adaptive robust optimization cases;
its split-budget robust cases are not included.

## What you need

All model inputs, the data-processing code, and expected results are archived
at [doi.org/10.5281/zenodo.22103387](https://doi.org/10.5281/zenodo.22103387).
To run the models you need:

- Julia 1.11.3 and Gurobi 12.0 with a license. This branch's `Manifest.toml`
  pins the exact Julia package versions we used.
- A machine with enough memory. The stress-test cases fit in 50 GB. The
  planning cases are larger: we allocated 128 GB for the deterministic cases,
  160 GB for the smallest robust case, and 350 and 600 GB (48 cores) for the
  two largest. These allocations were sized at roughly 1.3-1.5 times observed
  peak usage.
- Python 3 for everything except the solves themselves, which need no
  Python. The analysis and figure scripts use pandas, numpy, and matplotlib;
  re-running the RESOLVE-to-GenX translation additionally needs h5py and
  PyYAML. The exact versions we used are pinned in `requirements.txt` inside
  the archive's `code.zip`.

## Getting started

```bash
git clone https://github.com/gmantegna/GenX_Robust.git
julia --project=GenX_Robust -e 'using Pkg; Pkg.instantiate()'
unzip first_stage_cases.zip -d cases
cd cases/CPUC_PSP_deterministic_adjusted
julia --project=../../GenX_Robust Run.jl
```

This solves the deterministic planning case, which takes about half an hour on
16 cores. The total objective value, printed at the end and written to
`results/costs_multi_stage.csv`, should equal 387.161 billion dollars to
solver tolerance.

## The planning cases

`first_stage_cases.zip` contains five case directories. Four are the planning
cases discussed in the paper; the fifth, `CPUC_PSP_deterministic`, is a
validation case configured to match RESOLVE's own conventions as closely as
possible, which we used to confirm the translation against the CPUC's results.
Each is a standard GenX multi-stage case (`inputs/inputs_p1`, `inputs_p2`, ...,
`settings/`, `Run.jl`) and runs exactly as in the quick start above.

| Case directory | Name in paper | Objective (B$) | Approx. time |
|---|---|---|---|
| `CPUC_PSP_deterministic` | (RESOLVE validation) | 390.154 | ~30 min |
| `CPUC_PSP_deterministic_adjusted` | Deterministic | 387.161 | ~30 min |
| `CPUC_PSP_aro_gamma1` | Robust – Low (Γ=1) | 453.783 | ~40 min |
| `CPUC_PSP_aro_gamma2` | Robust – Mid (Γ=2) | 497.879 | ~2.5 h |
| `CPUC_PSP_aro_gamma3` | Robust – High (Γ=3) | 526.457 | ~6.5 h |

The robust cases are two-stage problems: one 2031 investment node plus one
2045 node for every combination of Γ of the 7 adverse scenarios (7, 21, and 35
nodes for Γ=1, 2, 3). Transmission, including deliverability upgrades, is a
first-stage decision shared by all nodes, so the first-stage results contain
each plan's complete transmission build.

## The stress tests

The paper evaluates each plan by fixing its 2031 investments and re-solving
2045 under 78 different scenarios. `stress_case_inputs.zip` contains all 312
of these single-stage cases, 78 for each of the four plans, named
`case_<8 downside bits>_<4 upside bits>`. The downside bits are, in order:
high costs, high natural gas price, high gas fixed O&M, high load, low
renewable availability, no offshore wind, low imports, and zero-GHG (always 0
here). The upside bits are: flexible EV charging, enhanced geothermal, Diablo
Canyon extension, and western regionalization.

Every stress case includes an emergency backstop: capacity exempt from
deliverability requirements, available at $2.0M per MW-year, priced above any
resource-adequacy shadow price observed in a feasible case so that it is used
only where the requirement cannot otherwise be met.

Each case runs the same way as the planning cases and needs about 50 GB; they
are independent, so run as many in parallel as your machine allows. Expected
values are in `expected_results.zip`:

- `first_stage_objectives.csv` reproduces the table above.
- `stress_summary_table.csv` gives the 2045 CAISO cost of each plan (billion
  dollars per year, backstop included) in the base year, the worst scenario,
  and on average across downside and upside scenarios. Two checks worth
  making: no case has unserved energy, and the deterministic plan needs
  emergency backstop capacity (up to 3.88 GW) in 22 of its 78 scenarios,
  including every high-load one, while the robust plans never do.

The script that builds these cases, `create_stress_testing_cases_psp.py`, is
included in `code.zip` so the construction can be audited. Building fleets
from scratch requires the full RESOLVE profile dataset (see below), which is
why the archive provides them pre-built.

## Analysis and figures

`code.zip` contains the analysis scripts: `analysis_psp.py` loads solved cases
and builds summary tables, and `make_paper_figures.py` produces the paper's
figures. Every machine-specific path used by the code is collected in one
file, `paths_config.py`; set the paths there before running anything. Only the
first two entries are needed to work with the archived cases. The remaining
entries point at the RESOLVE dataset and matter only if you are re-running the
translation itself.

## How the inputs were made

The chain from public data to the cases in this archive: the CPUC publishes
its RESOLVE model and inputs as part of the IRP proceeding (the vintage used
here is linked above). We converted that dataset into an HDF5 profile store
plus a JSON structure file, and the translator in `code.zip` (`utils_psp.py`,
driven by `create_genx_cases_psp.py`) reads that store and writes the GenX
cases. After setting the RESOLVE paths in `paths_config.py`, the invocation
is:

```
python create_genx_cases_psp.py deterministic adjusted aro1 aro2 aro3
```

with any subset of those targets. Translation is memory-light but reads a
very large file store; on a shared cluster, run it as a batch job. The RESOLVE scenario underlying the temporal settings and the
validation benchmark is `TPP_AB1373_Delayed_OSW`, two-planning-period variant.

The intermediate profile store is about 241 GB, too large to archive here.
Since the GenX cases it produces are archived in full, the solves are exactly
reproducible without it, and the translation itself can be audited by reading
the translator against the archived case inputs.

## License and citation

GenX and this branch are released under GPL-2.0, and the pipeline code in the
archive under the same terms. If you use this material, please cite the paper
and the Zenodo archive (doi.org/10.5281/zenodo.22103387).
