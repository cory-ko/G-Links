# G-Links - an extremely rapid gene-centric data aggregator

All rights reserved. Copyright © 2012 by OSHITA Kazuki and ARAKAWA Kazuharu.


## License
This software is free software for non-commercial use only; you can redistribute it and/or modify it under the terms of the MIT License expect commercial use.


## About
With the availability of numerous curated databases, researchers are nowadays able to efficiently utilize the multitude of biological data by integrating these resources by hyperlinks and cross references. A large proportion of bioinformatics research tasks, however, is comprised of labor-intensive tasks in fetching, parsing, and merging of these datasets and functional annotations from dispersed databases and web-based services. Therefore, data integration is one of the key challenges of bioinformatics. We here present G-Links, a gateway server for querying and retrieving gene annotation data. The system supports rapid querying with numerous gene IDs from multiple databases or nucleotide/amino acid sequences, by internally centralizing gene annotations based on UniProt entries. This system therefore first converts the query into UniProt ID by ID conversion or by sequence similarity search, and returns related annotations and cross references.
Moreover, users are able to run external web-based tools based on the query gene. G-Links is implemented as a RESTful service, so users can easily access this tool from any web browser.

This service and documentations are freely available at http://link.g-language.org/.

## Project page
[http://www.g-language.org/wiki/glinks](http://www.g-language.org/wiki/glinks)

## Usage
### Base URL
[http://link.g-language.org/](http://link.g-language.org/)

### Syntax
[http://link.g-language.org/[GENE ID](/options)](http://link.g-language.org/[GENE ID](/options)

### Standard Quqrifiers
#### [GENE ID]
  * GENE or GENE SET ID (ex: BRCA1_HUMAN)
    - List of available IDs is [http://link.g-language.org/input_list](http://link.g-language.org/input_list)
    - ex: [http://link.g-language.org/BRCA1_HUMAN](http://link.g-language.org/BRCA1_HUMAN)
  * NCBI taxonomy ID    (ex: 9606)
  * RefSeq Genome ID    (ex: NC_000913)

### Optional Qualifiers (options)
  - /format=[FORMAT]
    * available value
      * tsv  (Tabular) <default>
      * nt   (Notation3)
      * rdf  (RDF)
      * html (HTML) <default when accessing via Web browser>
      * json (JSON)
      * slim (Tabular format without URL (URI))

    * Examples
      - [http://link.g-language.org/KO:K03553/format=json](http://link.g-language.org/KO:K03553/format=json)
        * Data sets about KEGG Orthology KO:K03553 in JSON format


   - /filter=[FILTER] (FILTER="DB_NAME:keyrowd" or "DB_NAME" or ":keyword")
     * Filtering genes by database name or keywords.
     * Examples
       - [http://link.g-language.org/NC_000913/filter=GeneID](http://link.g-language.org/NC_000913/filter=GeneID)
         * Genes which has GeneID entry
       - [http://link.g-language.org/NC_000913/filter=:transport](http://link.g-language.org/NC_000913/filter=:transport)
         * Genes which are relate with "transport"
       - [http://link.g-language.org/NC_000913/filter=GO_process:transport](http://link.g-language.org/NC_000913/filter=GO_process:transport)
         * Genes which has GO_process entries which are relate with transport
     * This option is available with multiple-filter ("AND" filtering). Separater is "|".
       - [http://link.g-language.org/NC_000913/filter=GO_process|GOslim_function|KEGG_Brite:replication/](http://link.g-language.org/NC_000913/filter=GO_process|GOslim_function|KEGG_Brite:replication/)

  - /extract=[EXTRACTE]
    * Extract report items by DB or column name       
    * Examples
      - [http://link.g-language.org/hsa:128/extract=Pfam](http://link.g-language.org/hsa:128/extract=Pfam)
        * convert KEGG Gene ID to Pfam ID
      - [http://link.g-language.org/NC_000913/extract=GO_process](http://link.g-language.org/hsa:128/extract=Pfam)
        * report only GO_process
    * This option is available with multiple-filter ("OR" filtering). Separater is "|".
      - [http://link.g-language.org/9606/filter=DISEASE|KEGG_Disease](http://link.g-language.org/9606/filter=DISEASE|KEGG_Disease)
        * report only DISEASE section and KEGG_Disease

   - /evalue=[E-VALUE THRESHOLD]
     * default: /evalue=1e-70
       - E-value threshold for similarity search by BLAT against Swiss-Prot
       - This option is valid only user given sequence data to GENE

   - /identity=[IDENTITY THRESHOLD]
     * default: /identity=0.98
       - Identity threshold for similarity search by BLAT against Swiss-Prot
       - This option is valid only user given sequence data to GENE)

   - /direct="0 or 1"
     * default: direct=0
     * if "/direct=1", this service shows related information about top-hit Uniprot ID (feeling lucky)


## Usage Examples
  - [http://link.g-language.org/GeneID:947170](http://link.g-language.org/GeneID:947170)
    - Related information to GeneID:947170 as tabular format.

  - [http://link.g-language.org/eco:b2699/format=nt/extract=GOslim](http://link.g-language.org/eco:b2699/format=nt/extract=GOslim)
    - GO slim about eco:b2699 (KEGG Gene) as N-Triple format.

  - [http://link.g-language.org/MMQESATETISNSSMNQNGMSTLSSQLDAGSRDG....](http://link.g-language.org/MMQESATETISNSSMNQNGMSTLSSQLDAGSRDGRSSGDTSSEVSTVELLHLQQQQALQAARQLLLQQQTSGLKSPKSSDKQRPLQVPVSVAMMTPQVITPQQMQQILQQQVLSPQQLQALLQQQQAVMLQQQQLQEFYKKQQEQLHLQLLQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQHPGKQAKEQQQQQQQQQQLAAQQLVFQQQLLQMQQLQQQQHLLSLQ)
    - Information table about UniProt IDs which is reported by BLAT search about given AminoSeq against Swiss-Prot.

  - [http://link.g-language.org/9606/format=slim/filter=:cancer|KEGG_Disease/extract=DISEASE|KEGG_Disease](http://link.g-language.org/9606/format=slim/filter=:cancer|KEGG_Disease/extract=DISEASE|KEGG_Disease)
    - DISEASE information which is gene sets related to cancer

  - [https://gist.github.com/1172846](https://gist.github.com/1172846)
    - Perl script to get related information to top-hit UniProt ID by BLAT search against Swiss-Prot.


## REQUIREMENTS
  - jQuery      [http://jquery.com/](http://jquery.com/)
  - tablesorter [http://tablesorter.com/docs/](http://tablesorter.com/docs/)
  - ImageFlow   [http://imageflow.finnrudolph.de/](http://imageflow.finnrudolph.de/)



## Contact
Kazuki Oshita < cory@g-language.org >  
Institute for Advanced Biosciences, Keio University.

