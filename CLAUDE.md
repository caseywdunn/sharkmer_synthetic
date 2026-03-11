# sharkmer Synthetic Read Test Framework

Synthetic Illumina reads from *Porites lutea* genomes to test
[sharkmer](https://github.com/caseywdunn/sharkmer) in silico PCR with the
cnidarian primer panel.

## Documentation

- [docs/overview.md](docs/overview.md) — Project overview, reference genomes,
  directory layout
- [docs/pipeline.md](docs/pipeline.md) — Step-by-step pipeline details and
  implementation notes

## Quick Reference

- **Script:** `synthesize.sh` — main pipeline (bash)
- **Conda env:** `sharkmer_synth` — created from `environment.yml`
- **sharkmer** is assumed installed separately (not in conda env)
- Read simulation uses InSilicoSeq NovaSeq model (150 bp); R2 is discarded
- Mitochondrial variants are created by applying patches from `patch/` to the
  original mt genome (if any patches exist)
- Each mt source (original + variants) is analyzed independently with sharkmer

## Key Constants

- `N_NUC=990000` — nuclear read count
- `N_MITO=10000` — mitochondrial read count per variant

## Conventions

- Each pipeline step checks for existing output and skips if present
- `data/` holds reference genomes, `reads/` holds simulated reads,
  `results/` holds sharkmer output
- Use `set -euo pipefail` in bash scripts
