#!/data/shared_env/bin/python3
from pybiomart import Server
import pandas as pd
import sys

snp_list_file = sys.argv[1]
output_file_name = sys.argv[2]

snp_list = list(set(line.strip() for line in open(snp_list_file)))


server = Server(host='http://www.ensembl.org')
snpMart = server.marts['ENSEMBL_MART_SNP'].datasets['hsapiens_snp']

def query_ensembl(snp_list):
    query_result = snpMart.query(attributes=['refsnp_id',
                                  'associated_variant_risk_allele','source_name',
                                  'clinical_significance','phenotype_description',
                                  'pmid'],
                      filters={'snp_filter':snp_list})
    return(query_result)


output_data = pd.DataFrame(columns=['Variant name', 
                              'Associated variant risk allele', 
                              'Source name',
                              'Clinical significance',
                              'Phenotype description',
                              'PubMed ID'])
for i in range(0,len(snp_list)):
    print(snp_list[i])
    query_result = query_ensembl(snp_list[i])
    output_data = output_data.append(query_result)

output_data.to_csv(output_file_name,
           sep = '\t',
           index = False)