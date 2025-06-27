#!/bin/bash

# Function to process a single genome.fa file
process_genome_file() {
    local file=$1

    # Search for organelle keywords in the headers
    organelle_hits=$(grep -iE "chloroplast|plastid|mitochondrion" "$file" | cut -d' ' -f1 | sort | uniq)
    
    if [ ! -z "$organelle_hits" ]; then
        echo "$organelle_hits"
        return
    fi

    # Fall back to length-based heuristic
    headers=$(grep "^>" "$file" | cut -d' ' -f1)
    header_lengths=$(echo "$headers" | awk '{ print length($0) " " $0 }' | sort -n)
    shortest_length=$(echo "$header_lengths" | awk '{print $1}' | uniq -c | awk '$1 == 2 && NR == 1 { print $2 }')

    if [ ! -z "$shortest_length" ]; then
        two_shortest=$(echo "$header_lengths" | awk -v len="$shortest_length" '$1 == len { print $2 }')
        echo "$two_shortest"
    else
        echo ">MT"
    fi
}

# Check if a file is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <genome.fa>"
    exit 1
fi

# Process the input genome file
process_genome_file "$1"
