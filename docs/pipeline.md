# Pipeline Steps

Each step checks for its expected output before running, so the pipeline can be
re-run without repeating completed work.

## Step 1: Conda Environment

Check if the `sharkmer_synth` conda environment exists. If not, create it from
`environment.yml`. The environment provides InSilicoSeq and NCBI Entrez
utilities. sharkmer is assumed to be installed separately (it is a Rust binary).

## Step 2: Download Nuclear Genome

- **Source:** `GCF_958299795.1_jaPorLute2.1_genomic.fna.gz`
- **URL:** <https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/958/299/795/GCF_958299795.1_jaPorLute2.1/GCF_958299795.1_jaPorLute2.1_genomic.fna.gz>
- **Processing:** Download, decompress, extract only sequences whose headers
  start with `>NC_` (chromosomes). Write to `data/Porites_lutea_nuclear.fna`.
- **Checkpoint:** Skip if `data/Porites_lutea_nuclear.fna` exists.

## Step 3: Download Mitochondrial Genome

- **Accession:** OY283138.1
- **Tool:** `efetch -db nucleotide -id OY283138.1 -format fasta`
- **Output:** `data/Porites_lutea_mt.fna`
- **Checkpoint:** Skip if file exists.

## Step 4: Generate Mitochondrial Variants (conditional)

- **Condition:** Only runs if `patch/` directory exists and contains `.patch`
  files.
- For each `patch/<name>.patch`:
  1. Copy `data/Porites_lutea_mt.fna` to `data/Porites_lutea_mt_<name>.fna`
  2. Apply the patch: `patch data/Porites_lutea_mt_<name>.fna patch/<name>.patch`
- **Checkpoint:** Skip each variant if its output file already exists.

## Step 5: Simulate Nuclear Reads

```bash
iss generate \
  --genomes data/Porites_lutea_nuclear.fna \
  --model NovaSeq \
  --n_reads 990000 \
  --output reads/nuclear \
  --cpus <threads>
```

Produces `reads/nuclear_R1.fastq` and `reads/nuclear_R2.fastq`. R2 is deleted.

- **Checkpoint:** Skip if `reads/nuclear_R1.fastq` exists.

## Step 6: Simulate Mitochondrial Reads

For the original mt genome:

```bash
iss generate \
  --genomes data/Porites_lutea_mt.fna \
  --model NovaSeq \
  --n_reads 10000 \
  --output reads/mt_original \
  --cpus <threads>
```

Delete R2. Repeat for each variant genome, outputting to
`reads/mt_<variant>_R1.fastq`.

- **Checkpoint:** Skip each if its R1 file already exists.

## Step 7: Run sharkmer

For each analysis (original + each variant):

```bash
cat reads/nuclear_R1.fastq reads/mt_<source>_R1.fastq \
  | sharkmer --pcr cnidaria -s <sample_name> -o results/<source>/
```

Where `<source>` is `original` or the variant name, and `<sample_name>` matches
`<source>`.

- **Checkpoint:** Skip if `results/<source>/` directory exists and contains
  output files (e.g., `16s.fasta`).

## Implementation Notes

- **Script:** `synthesize.sh` (bash). Each step is a function with a checkpoint
  guard at the top.
- **Conda activation:** The script activates `sharkmer_synth` at the start.
  Steps requiring conda tools (efetch, iss) run inside the environment.
- **Parallelism:** InSilicoSeq `--cpus` is set to available cores. sharkmer
  `-t` is set similarly.
- **Determinism:** Consider setting `--seed` on `iss generate` for
  reproducibility.
- **Error handling:** `set -euo pipefail` at the top of the script. Each step
  logs a message before and after execution.

## Roadmap (Future Extensions)

- Use patch files to apply targeted diffs to the mt genome (e.g., SNPs in the
  16s region) and verify sharkmer detects them.
- Compare assembled amplicon sequences across variants.
