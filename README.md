# sharkmer Synthetic Read Test Framework

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19021107.svg)](https://doi.org/10.5281/zenodo.19021107)


Synthetic Illumina reads from *Porites lutea* nuclear and mitochondrial genomes
to evaluate [sharkmer](https://github.com/caseywdunn/sharkmer) in silico PCR (sPCR)
with the cnidarian primer panel.

## Setup

All other dependencies including sharkmer are managed by conda:

```bash
conda env create -f environment.yml
```

## Usage

```bash
conda activate sharkmer_synth
./synthesize.sh
```

The pipeline is checkpointed — each step checks for existing output and skips
if present. Safe to re-run after interruption.

## Mitochondrial variants

To test sharkmer's ability to detect mutations, create a `patches.tsv` file
with three tab-separated columns (no header):

```text
variant_name    ORIGINAL_SEQUENCE    REPLACEMENT_SEQUENCE
```

Each row defines a variant by specifying a sequence to find in the mt genome and
its replacement. Reads are simulated and analyzed independently for each variant.

If `patches.tsv` is absent, only the original mt genome is analyzed.

## Output

Results are in `results/`, with one subdirectory per analysis:

```
results/
├── original/       # nuclear + original mt
└── <variant>/      # nuclear + variant mt (one per patches.tsv row)
```

Each contains sharkmer amplicon assemblies (e.g., `16S.fasta`, `co1.fasta`)
and kmer histograms.

## Documentation

- [docs/overview.md](docs/overview.md) — project overview and directory layout
- [docs/pipeline.md](docs/pipeline.md) — step-by-step pipeline details
