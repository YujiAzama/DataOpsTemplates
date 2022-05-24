# Bastion の作成・削除が自動化された DataOps 環境を展開するテンプレート

## 概要

この ARM テンプレートは、Azure Bastion のコストを削減するために Azure Automation を使用して Azure Bastion ホストの生成、及び、削除が自動化された DataOps 環境を展開できます。

## テンプレートの構成要素

- Windows Server 2022
  - Power Automate Desktop
  - Power BI Desktop
- Azure CosmosDB
- Azure Automation
  - Azure Bastion

## 使用方法

1. Azure ポータルにログイン後、「カスタムテンプレートのデプロイ」サービスを選択します。

2. 「エディターで独自のテンプレートを作成する」を選択します。

3. 「ファイルの読み込み」を選択し、ダウンロードしたテンプレートファイルを読み込み、保存します。

4. 各種パラメーターを入力し、作成します。

5. マネージド ID にアクセス権を付与します。

