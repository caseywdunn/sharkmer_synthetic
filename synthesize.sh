#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Synthetic read generation and sharkmer analysis for Porites lutea
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Constants ---------------------------------------------------------------

N_NUC=990000
N_MITO=10000
SEED=42
THREADS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

NUCLEAR_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/958/299/795/GCF_958299795.1_jaPorLute2.1/GCF_958299795.1_jaPorLute2.1_genomic.fna.gz"
MT_ACCESSION="OY283138.1"

CONDA_ENV="sharkmer_synth"

# --- Helpers -----------------------------------------------------------------

log() {
    echo "==> $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# --- Step 1: Conda environment -----------------------------------------------

ensure_conda_env() {
    if conda info --envs | grep -q "^${CONDA_ENV} "; then
        log "Conda environment '${CONDA_ENV}' already exists, skipping creation"
    else
        log "Creating conda environment '${CONDA_ENV}' from environment.yml"
        conda env create -f environment.yml
    fi

    log "Activating conda environment '${CONDA_ENV}'"
    eval "$(conda shell.bash hook)"
    conda activate "$CONDA_ENV"
}

# --- Step 2: Download nuclear genome -----------------------------------------

download_nuclear_genome() {
    local outfile="data/Porites_lutea_nuclear.fna"
    if [[ -f "$outfile" ]]; then
        log "Nuclear genome already exists, skipping"
        return
    fi

    log "Downloading nuclear genome"
    mkdir -p data
    local tmpfile="data/tmp_genomic.fna.gz"
    curl -o "$tmpfile" "$NUCLEAR_URL"

    log "Extracting chromosome sequences (NC_* headers)"
    # Use awk to extract only records with headers starting with >NC_
    gunzip -c "$tmpfile" \
        | awk '/^>/{keep=/^>NC_/} keep' \
        | awk '/^>/{print; next} {print toupper($0)}' \
        > "$outfile"
    rm "$tmpfile"

    log "Nuclear genome saved to ${outfile}"
}

# --- Step 3: Download mitochondrial genome -----------------------------------

download_mt_genome() {
    local outfile="data/Porites_lutea_mt.fna"
    if [[ -f "$outfile" ]]; then
        log "Mitochondrial genome already exists, skipping"
        return
    fi

    log "Downloading mitochondrial genome (${MT_ACCESSION})"
    mkdir -p data
    efetch -db nucleotide -id "$MT_ACCESSION" -format fasta \
        | awk '/^>/{if(seq)print seq; print; seq=""; next} {seq=seq toupper($0)} END{if(seq)print seq}' \
        > "$outfile"
    log "Mitochondrial genome saved to ${outfile}"
}

# --- Step 4: Generate mitochondrial variants (conditional) -------------------

generate_mt_variants() {
    if [[ ! -f "patches.tsv" ]]; then
        log "No patches.tsv found, skipping variant generation"
        return
    fi

    mkdir -p data
    while IFS=$'\t' read -r name orig_seq replacement_seq; do
        # Skip blank lines and comments
        [[ -z "$name" || "$name" == \#* ]] && continue

        local outfile="data/Porites_lutea_mt_${name}.fna"

        if [[ -f "$outfile" ]]; then
            log "Variant '${name}' already exists, skipping"
            continue
        fi

        log "Generating variant '${name}' via sequence replacement"
        awk -v orig="$orig_seq" -v repl="$replacement_seq" '
            /^>/ { print; next }
            { seq = seq $0 }
            END {
                gsub(orig, repl, seq)
                # Wrap at 80 characters
                for (i = 1; i <= length(seq); i += 80)
                    print substr(seq, i, 80)
            }
        ' data/Porites_lutea_mt.fna > "$outfile"
        log "Variant saved to ${outfile}"
    done < patches.tsv
}

# --- Step 5: Simulate nuclear reads ------------------------------------------

simulate_nuclear_reads() {
    local outprefix="reads/nuclear"
    if [[ -f "${outprefix}_R1.fastq" ]]; then
        log "Nuclear reads already exist, skipping"
        return
    fi

    log "Simulating ${N_NUC} nuclear reads (NovaSeq model)"
    mkdir -p reads
    iss generate \
        --genomes data/Porites_lutea_nuclear.fna \
        --model NovaSeq \
        --n_reads "$N_NUC" \
        --output "$outprefix" \
        --cpus "$THREADS" \
        --seed "$SEED"

    rm -f "${outprefix}_R2.fastq"
    log "Nuclear reads saved to ${outprefix}_R1.fastq"
}

# --- Step 6: Simulate mitochondrial reads ------------------------------------

simulate_mt_reads() {
    # Original mt genome
    _simulate_mt_reads_for "data/Porites_lutea_mt.fna" "mt_original"

    # Variant mt genomes
    if [[ -f "patches.tsv" ]]; then
        while IFS=$'\t' read -r name _ _; do
            [[ -z "$name" || "$name" == \#* ]] && continue
            _simulate_mt_reads_for "data/Porites_lutea_mt_${name}.fna" "mt_${name}"
        done < patches.tsv
    fi
}

_simulate_mt_reads_for() {
    local genome="$1"
    local label="$2"
    local outprefix="reads/${label}"

    if [[ -f "${outprefix}_R1.fastq" ]]; then
        log "Reads for '${label}' already exist, skipping"
        return
    fi

    log "Simulating ${N_MITO} reads from ${genome} (${label})"
    mkdir -p reads
    iss generate \
        --genomes "$genome" \
        --model NovaSeq \
        --n_reads "$N_MITO" \
        --output "$outprefix" \
        --cpus "$THREADS" \
        --seed "$SEED"

    rm -f "${outprefix}_R2.fastq"
    log "Reads saved to ${outprefix}_R1.fastq"
}

# --- Step 7: Run sharkmer ----------------------------------------------------

run_sharkmer() {
    # Original
    _run_sharkmer_for "original" "reads/mt_original_R1.fastq"

    # Variants
    if [[ -f "patches.tsv" ]]; then
        while IFS=$'\t' read -r name _ _; do
            [[ -z "$name" || "$name" == \#* ]] && continue
            _run_sharkmer_for "$name" "reads/mt_${name}_R1.fastq"
        done < patches.tsv
    fi
}

_run_sharkmer_for() {
    local label="$1"
    local mt_reads="$2"
    local outdir="results/${label}"

    if [[ -d "$outdir" ]] && ls "${outdir}"/*.fasta &>/dev/null; then
        log "sharkmer results for '${label}' already exist, skipping"
        return
    fi

    log "Running sharkmer for '${label}'"
    mkdir -p "$outdir"
    cat reads/nuclear_R1.fastq "$mt_reads" \
        | sharkmer --pcr cnidaria -s "$label" -o "$outdir" -t "$THREADS"
    log "sharkmer results saved to ${outdir}/"
}

# --- Step 8: Compare 16S amplicons across variants --------------------------

compare_16s() {
    local outfile="results/compare_16s.fasta"
    if [[ -f "$outfile" ]]; then
        log "16S comparison already exists, skipping"
        return
    fi

    log "Collecting 16S amplicon sequences"
    local combined
    combined=$(mktemp)

    # Collect *_16S.fasta from each result directory, prefixing headers with label
    for dir in results/*/; do
        local label
        label="$(basename "$dir")"
        local fasta
        fasta=$(ls "${dir}"*_16S.fasta 2>/dev/null | head -1)
        if [[ -n "$fasta" ]]; then
            sed "s/^>/>$label /" "$fasta" >> "$combined"
        else
            log "Warning: no 16S fasta in ${dir}, skipping"
        fi
    done

    if [[ ! -s "$combined" ]]; then
        log "No 16S sequences found, skipping comparison"
        rm -f "$combined"
        return
    fi

    log "Aligning 16S sequences with MAFFT"
    mafft --auto "$combined" > "$outfile"
    rm -f "$combined"
    log "16S alignment saved to ${outfile}"
}

# --- Main --------------------------------------------------------------------

main() {
    log "Starting synthetic read pipeline"
    log "Threads: ${THREADS}"

    ensure_conda_env
    download_nuclear_genome
    download_mt_genome
    generate_mt_variants
    simulate_nuclear_reads
    simulate_mt_reads
    run_sharkmer
    compare_16s

    log "Pipeline complete"
}

main "$@"
