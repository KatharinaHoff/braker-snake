"""
braker-snake

Katharina J. Hoff, Stepan Saenko, Clara Pitzschel

University of Greifswald

A joint effort to automated bulk genome annotation
"""

__author__ = "Katharina J. Hoff, Stepan Saenko, Clara Pitzschel"

import configparser
import pandas as pd
from pathlib import Path
import json
import re
import glob
from snakemake.io import expand

# Load and parse the config file
config = configparser.ConfigParser()
config.read('config.ini')
input_csv = config['INPUT']['input_csv']

# define local rules that are not submitted via SLURM
# some of them are local because they are fast, others because there bottleneck is i/o, not CPU
localrules: all, \
            download_assembly_info, assembly_json_to_tbl, classify_species, prepare_download_assemblies_from_ncbi, run_genome_download_commands, \
            download_orthodb_partitions, \
            retrieve_rnaseq_info_from_sra, download_fastq

# Read the input CSV file to get taxon and odb partition names
# Assuming the CSV file is tab-separated
data = pd.read_csv(input_csv, header=None, sep=' ', names=['taxa', 'odb_partition'])

# Create separate lists for taxa and unique odb partitions
taxa_list = data['taxa'].tolist()
unique_odb_partitions = data['odb_partition'].unique().tolist()

# Create the checkpoint file directory for both workflows if it does not exist yet
checkptdir = "data/checkpoints_dataprep"
if not Path(checkptdir).exists():
    Path(checkptdir).mkdir(parents=True, exist_ok=True)

# Include other rule files (assuming they define their own targets without using wildcards inappropriately)
include: "rules_dataprep/genome_download.smk"
include: "rules_dataprep/odb_download.smk"
include: "rules_dataprep/rnaseq_download.smk"

# Main rule to process each taxon
rule all:
    input:
        expand("data/checkpoints_dataprep/{taxon}_download.done", taxon=taxa_list),
        expand(config['BRAKER']['orthodb_path'] + "/{odb_partition}.fa", odb_partition=unique_odb_partitions),
        expand("data/checkpoints_dataprep/{taxon}_rnaseq_info.done", taxon=taxa_list),
        expand("data/checkpoints_dataprep/{taxon}_hisat2_index.done", taxon=taxa_list)
        # This is the place where you have to expand when you are waiting for more targets! For example,
        # we will implement RNA-Seq download, and this is where you have to add the RNA-Seq targets.

