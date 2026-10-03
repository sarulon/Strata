# Strata AVX + V100 port kit

Runs [Niko1221/Strata](https://github.com/Niko1221/Strata) on this PC: a **Tesla V100**
(sm_70, below the ready-made engine's architectures) and a **Xeon E5-2690 v2** (AVX only, no
AVX2/FMA/F16C). Strata upstream refuses both; this kit is the working port.

## Install & run

```sh
./install.sh ~/Strata --yes        # clone + patch + install, then it starts the server
./install.sh ~/Strata --yes --no-start   # install only
```

Server: `http://127.0.0.1:8080/` (web chat), `/v1` (OpenAI), `/v1/messages` (Anthropic).
The model files (`~65 GiB`, Unsloth UD-Q4_K_XL) are taken from the existing `Strata-data`
folder next to the checkout; nothing else needs to be present.

## What the port changes (`strata-port.patch`, against commit `db4f91a`)

- **AVX2-free CPUs**: the CPU expert kernels keep running on machines with AVX2/AVX-512;
  a CPU without AVX2 now falls through to the portable ggml-cpu dots the code already
  had behind environment switches (`src/kernels/cpu/native_expert.cpp`, `pool.cpp`,
  `expert_source.cpp`), with new scalar fallbacks for the two remaining AVX-only helpers
  (`expert_layout.cpp`). The engine's "this CPU has no AVX2 - stop" gate became a warning
  (`src/program/generate.cpp`), and so did setup's (`setup.py`).
- **Pre-main crash fixed**: three of the AVX-compiled files had global tables computed by
  constructors that ran *before* `main` (and before any CPU check) using AVX2/AVX-512
  instructions - an illegal instruction on this CPU. Those tables are now constant-init or
  initialized lazily inside the guarded kernels (`iq_avx2.cpp`, `iq_avx512.cpp`, `expert.cpp`).
- **Router lookahead** (an AVX2-only prefetch) disables itself instead of crashing.
- **V100 (sm_70)**: no source changes - Strata builds it with
  `-DSTRATA_EXPERIMENTAL_SM60=ON` and a CUDA **12.x** toolkit (13 dropped sm_70); the
  script sets `STRATA_EXPERIMENTAL_SM60=1` for setup, which compiles the engine (or reuses
  `engine/strata` here, already built this way with nvcc 12.4).
- Docs updated to match (`docs/AI_SETUP.md`, `INSTALL.md`, `DETAILS.md`).

## Contents

| File | What it is |
| --- | --- |
| `install.sh` | clone → patch → (reuse engine) → setup → start |
| `strata-port.patch` | every in-file change, one patch |
| `engine/strata` + `engine/BUILD.json` | the engine compiled here for sm_70 (41 MB); `setup.py` verifies it against the source and rebuilds if it doesn't match |

## Measured on this PC

Engine 0.1.37, Unsloth UD-Q4_K_XL: ~17 tok/s decode (draft-accepted), ~60-token prompts
in ~3 s, 64 GiB page-locked expert set, ~340 MiB VRAM left over. Correctness: the port
was not bit-diffed against an AVX2 machine - the fallback paths are ggml's own, expected
to differ at most in last-bit rounding.
