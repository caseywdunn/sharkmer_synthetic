# sharkmer Synthetic Read Test Framework

Synthetic Illumina reads from *Porites lutea* nuclear and mitochondrial genomes
to evaluate [sharkmer](https://github.com/caseywdunn/sharkmer) in silico PCR
with the cnidarian primer panel.

## Setup

[sharkmer](https://github.com/caseywdunn/sharkmer) must be installed
separately and available on `$PATH`.

All other dependencies are managed by conda:

```bash
conda env create -f environment.yml
```

## Usage

```bash
./synthesize.sh
```

The pipeline is checkpointed — each step checks for existing output and skips
if present. Safe to re-run after interruption.

## Mitochondrial variants

To test sharkmer's ability to detect mutations, place patch files in `patch/`.
Each `patch/<name>.patch` is applied to the original mt genome to produce a
variant. Reads are simulated and analyzed independently for each variant.

If no patches are present, only the original mt genome is analyzed.

## Output

Results are in `results/`, with one subdirectory per analysis:

```
results/
├── original/       # nuclear + original mt
└── <variant>/      # nuclear + variant mt (one per patch)
```

Each contains sharkmer amplicon assemblies (e.g., `16s.fasta`, `co1.fasta`)
and kmer histograms.

## Documentation

- [docs/overview.md](docs/overview.md) — project overview and directory layout
- [docs/pipeline.md](docs/pipeline.md) — step-by-step pipeline details
