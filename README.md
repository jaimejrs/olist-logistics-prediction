# Olist Logistics Prediction (Projeto Data Fullstack)

> **Tema do projeto:** Análise e predição de performance logística e satisfação de clientes em um marketplace brasileiro.

## Estrutura do Projeto
- `data/`: Arquivos originais e processados (não versionados)
- `notebooks/`: EDA, Análise Estatística e Modelagem
- `src/`: Scripts Python de orquestração e configuração (Ingestão, Staging, Analytics)
- `sql/`: Schemas, visões, DDL para a camada Analytics e consultas de negócios
- `models/`: Modelos persistidos em PKL
- `powerbi/`: Arquivo de BI (.pbix)
- `reports/`: Exportação de análises visuais e relatórios

## Arquitetura Medallion
- **Raw:** Dados brutos provenientes de CSV
- **Staging:** Tipagem e tratativas essenciais
- **Analytics:** Dados modelados para BI e Ciência de Dados (Fato e Dimensões)
