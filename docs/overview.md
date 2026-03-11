# Synthetic Read Test Framework for sharkmer

## Purpose

Generate a synthetic dataset of Illumina-like reads from the *Porites lutea*
nuclear and mitochondrial genomes to evaluate
[sharkmer](https://github.com/caseywdunn/sharkmer)'s in silico PCR performance
with the cnidarian primer panel.

## Reference Genomes

| Genome | Source | Local file |
|---|---|---|
| Nuclear | [GCF_958299795.1](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/958/299/795/GCF_958299795.1_jaPorLute2.1/GCF_958299795.1_jaPorLute2.1_genomic.fna.gz) | `data/Porites_lutea_nuclear.fna` |
| Mitochondrial | GenBank [OY283138.1](https://www.ncbi.nlm.nih.gov/nuccore/OY283138.1) | `data/Porites_lutea_mt.fna` |

The nuclear genome file is subset to chromosomes only (headers starting with
`NC_`); scaffolds and unplaced contigs are excluded.

## Read Simulation

Reads are generated with [InSilicoSeq](https://github.com/HadrienG/InSilicoSeq)
using the NovaSeq error model (150 bp paired-end). Only R1 is retained to
produce single-end reads.

| Source | Read count (`-n`) | Notes |
|---|---|---|
| Nuclear | 990,000 | From `Porites_lutea_nuclear.fna` |
| Mitochondrial (original) | 10,000 | From `Porites_lutea_mt.fna` |
| Mitochondrial (each variant) | 10,000 | From patched mt genomes, if patches exist |

## Mitochondrial Variants

If patch files are present in `patch/`, each is applied to the original mt
genome to produce a variant. Each variant's reads are analyzed independently
against sharkmer (see `docs/pipeline.md` for details).

## sharkmer Analysis

Each read set (nuclear + one mt source) is piped to sharkmer with the cnidarian
primer panel:

```
cat nuclear_R1.fastq mt_R1.fastq | sharkmer --pcr cnidaria -s <sample_name> -o <outdir>
```

The cnidarian panel targets five loci: 16s, co1, 18s, 28s, ITSfull.

## Directory Layout

```
sharkmer_synthetic/
├── CLAUDE.md
├── environment.yml
├── synthesize.sh
├── docs/
│   ├── overview.md          # this file
│   └── pipeline.md          # step-by-step pipeline details
├── patch/                   # optional: mt genome patch files
├── data/                    # downloaded/derived reference genomes
│   ├── Porites_lutea_nuclear.fna
│   ├── Porites_lutea_mt.fna
│   └── Porites_lutea_mt_<variant>.fna
├── reads/                   # simulated reads
│   ├── nuclear_R1.fastq
│   ├── mt_original_R1.fastq
│   └── mt_<variant>_R1.fastq
└── results/                 # sharkmer output
    ├── original/            # nuclear + original mt
    └── <variant>/           # nuclear + variant mt
```
