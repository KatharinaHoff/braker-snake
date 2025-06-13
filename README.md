# braker-snake

Simple snakemake workflows for handling BRAKER on large data sets to prepare training data for Tiberius.

Contributors: Clara Pitzschel, Natalia Nenasheva, Stepan Saenko, Katharina J. Hoff

Contact: katharina.hoff@uni-greifswald.de

**Warning:** This is a not a released software package, it comes without support. We use this workflow internally for bulk genome annotation and it was customized to our needs.

Data preparation workflow:

1. Download the available assemblies for taxa from NCBI
2. Prioritize in case of species duplications (first choice: reference genome, second choice: max N50)
3. Separate into annotated and un-annotated genomes
4. Download the respective data sets from NCBI datasets (either genome only, or genome, annotation, proteins)
5. Download OrthoDB partitions
6. Check availability of RNA-Seq data for all downloaded genomes
7. Download at most N RNA-Seq libraries (VARUS idea was discarded)
8. Align RNA-Seq libraries
9. Discard bad libraries with now alignment rate
10. Postprocess the aligned libraries to serve as input for BRAKER (merge, sort, index)
11. Output a csv table per taxon that can be merged over all taxa in order to launch the annotation workflow

Annotation workflow

1. Mask genomes with RepeatModeler/RepeatMasker (since RED does not have diatom/protist data)
2. Run BRAKER depending on the input as BRAKER3 or BRAKER2
3. Run BUSCO on all the protein data sets and compile a summary

## Installation

Go do a directory where you have space for many GBs of data. Clone the repository:

```git clone https://github.com/KatharinaHoff/braker-snake.git```

Python dependencies (this workflow cannot execute with a singularity container of snakemake due to problems with SLURM communication):

```
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc # to activate miniconda
conda install -n base -c conda-forge mamba
mamba create -c conda-forge -c bioconda -n snakemake snakemake
mamba activate snakemake
pip install snakemake-executor-plugin-slurm
```

Bash dependencies (are usually available on the HPC in Greifswald): singularity, curl, zcat, unzip, rm, echo, mkdir, cat, sed, ...

## Configuration

### config_dataprep.ini & config_annotate.ini

Contents of the config files are important, adjust before running! Only execute worklows in a place where you have unlimited space. The output is huge.

### ~/profile/apptainer/config.v8+.yaml

Due to a weird binding issue with current snakemake/SLURM (see Issues), you currently have to create a config file and fill it with the bindings directory for your singularity job. I hope this will be fixed, eventually.

```
mkdir -p ~/profile/apptainer/
touch ~/profile/apptainer/config.v8+.yaml
```

Add the following content to the file (adapt to your own working directory):

```
use-singularity: True
singularity-args: "\"--bind /home/hoffk83/git/braker-snake:/home/hoffk83/git/braker-snake --bind /home/hoffk83/ncbi:/home/hoffk83/ncbi\""
```

## Input data

The input data for dataprep is expected to be in the following format:

```
<taxon> <odb_partition> <busco_lineage>
```

You find a small example in input.csv.  You may want to modify input.csv

The input data for annotate is expected to be in the following format:

```
species,taxon,accession,genome_file,odb_file,rnaseq_file,legacy_prot_file,annotation_file,busco_lineage
Epithemia_pelagica,Rhopalodiales,GCA_946965045.2,data/species/Epithemia_pelagica/genome/genome.fa,data/orthodb/Stramenopiles.fa,,,,stramenopiles_odb10
```

You find a small exampel in the species.csv. You can build one large input file for all taxa after dataprep has finished. Each of the taxa produces a compatible csv file.

**Warning:** specifying a taxon that includes another taxon in the input is dangerous! We are not checking for species duplicates across taxa. Don't do this!

The first workflow, `Snakefile_dataprep` will run all expensive tasks for one taxon in a loop on node. This means if you provide a taxon with extremely many species/genomes to process, this may lead to exceeding the runtime limit of the BRAIN. For example 7 libraries for a single species take ~3 hours for fasterq-dump and gzipping. This means, if you set the threshold to dowload at most 10 libs per species, and if every species in the taxon has RNA-Seq, then a taxon should have at most 16 species in order to have a good chance that the job will not die due to the runtime limit.

## Running

Execute this only in a place where you have space for many GBs of data, output is written to a subdirectory data and will be very, very big! Be patient, at the first execution, large containers are pulled. This takes between 20 minutes and 2 hours, before anything else happens. Best to start in screen. The pipeline automatically submits some tasks via SLURM.

Preparing to run either of the pipelines on login-a or login-b:

```
screen # enter screen before proceeding
mamba activate snakemake
module load singularity
cd braker-snake
```

Run the data download and processing pipeline:

```
snakemake -s Snakefile_dataprep --executor slurm --default-resources slurm_account=none slurm_partition=batch --jobs=10 --use-apptainer
```

Testing the annotation pipeline:

```
snakemake -s Snakefile_annotate --executor slurm --default-resources slurm_account=none slurm_partition=batch --jobs=10 --use-apptainer
```

### Known issues

Everything that relies on download from the web is fragile. For example, the error message `panic: runtime error: invalid memory address or nil pointer dereference` can happen when a ncbi datasets genome data download fails. Simply restart the workflow (do not delete previously obtained data). It will automatically try to fix it.

If a fastqdump was interrupted during gzip (because sth else killed the pipeline), you may have to go to the fastq folders of species and delete the unfinished library files before restarting. Otherwise, hisat2 will fail on the incomplete input

## Current DAGs with example data

(can always be generated with `snakemake -s Snakefile_dataprep --dag | dot -Tpng > dag1.png`, potentially not on BRAIN because dot may not be installed)

## Publications

N. Nenasheva, C. Pitzschel, C. N. Webster, A. J. Hart, J. L. Wegrzyn, M. M. Bengtsson, K. J. Hoff
annotation of protein-coding genesin 49 diatom genomes from the Bacillariophyta clade
Scientific Data 12:985, https://doi.org/10.1038/s41597-025-05306-z

## Funding

This software was funded by the German Research Foundation grant 277249973 to KJH.

![DAG](dag1.png)

(can always be generated with `snakemake -s Snakefile_annotate --dag | dot -Tpng > dag2.png`, potentially not on BRAIN because dot may not be installed)

![DAG](dag2.png)
