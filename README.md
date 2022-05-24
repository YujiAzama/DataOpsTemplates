# DataOps テンプレート

## 概要

このリポジトリは、[DataOps](https://www.gartner.com/en/information-technology/glossary/dataops) の環境を簡単に構築するための ARM テンプレートを提供します。

## テンプレートの種類

### - [DataOps deployment](https://github.com/YujiAzama/DataOpsTemplates/tree/main/dataops-deployment)

DataOps deployment は、DataOps の環境に必要な以下のリソースを自動的に展開します。

- Virtual Machine (Windows Server 2022)
- Bastion
- CosmosDB

展開された Windows Server には、Power Automate Desktop と Power BI Desktop が自動的にインストールされます。

### - [DataOps deployment with automated bastion lifecycle](https://github.com/YujiAzama/DataOpsTemplates/tree/main/dataops-deployment-with-automated-bastion-lifecycle)

DataOps deployment with automated bastion lifecycle は、 DataOps deployment の構成に加えて、Azure Bastion を指定した時間に自動的に作成・削除するための Azure Automation の定義が含まれます。

- Virtual Machine (Windows Server 2022)
- Bastion
- CosmosDB
- Automation
