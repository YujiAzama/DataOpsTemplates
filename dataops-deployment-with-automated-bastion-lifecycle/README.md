# Bastion の作成・削除が自動化された DataOps 環境を展開するテンプレート

## 概要

この ARM テンプレートは、Azure Bastion のコストを削減するために Azure Automation を使用して Azure Bastion ホストの生成、及び、削除が自動化された DataOps 環境を展開できます。

## テンプレートの構成要素

- Virtual Machine (Windows Server 2022)
  - Power Automate Desktop
  - Power BI Desktop
- Azure CosmosDB
- Azure Automation
  - Azure Bastion

## 使用方法

### 1. テンプレートのダウンロード

テンプレートファイルをダウンロードします。

```bash
git clone https://github.com/YujiAzama/DataOpsTemplates.git
```

### 2. テンプレートのデプロイ

Azure ポータルからテンプレートをデプロイします。

#### 2.1. Azure ポータルにログイン後、「カスタムテンプレートのデプロイ」サービスを選択します。

![image](https://user-images.githubusercontent.com/8349954/170040227-4a654d6a-dc4d-466f-8fc6-c22a043fab92.png)


#### 2.2. 「エディターで独自のテンプレートを作成する」を選択します。

![image](https://user-images.githubusercontent.com/8349954/170040347-9a288aaa-6f96-4ad4-8fae-fff40b58a9e7.png)

#### 2.3. 「ファイルの読み込み」を選択し、ダウンロードしたテンプレートファイルを読み込み、保存します。

![image](https://user-images.githubusercontent.com/8349954/170040690-67c4dd1f-ce27-42b2-a541-d2a8fee57ca5.png)

#### 2.4. 各種パラメーターを入力し、テンプレートをデプロイします。

![image](https://user-images.githubusercontent.com/8349954/170041759-da65b08c-3234-433b-80f9-c53b75c9f4c9.png)

### 3. アクセス権の付与

Automation で実行される Runbook 内の Azure CLI は Bastion　の ARM テンプレートをデプロイするために Azure リソースの操作が許可されている必要があります。
Azure CLI へ Azure リソースの操作を許可を設定するために、Azure Automation へ割り当てられたマネージド ID へアクセス許可の設定を行います。

#### 3.1. 「サブスクリプション」から「アクセス制御(IAM)」を開き、「追加」から「ロールの割り当て」を選択します。

![image](https://user-images.githubusercontent.com/8349954/170046911-a39eb6e2-692d-49ae-8d36-51394de87450.png)

#### 3.2. 「共同作成者」のロールを選択し、「次へ」を選択します。

![image](https://user-images.githubusercontent.com/8349954/170047312-047a7ec6-dbcb-4301-92b2-9d800407070a.png)

#### 3.3. 「アクセスの割り当て先」に「マネージド ID」を選択し、メンバーに「user-assigned-id-for-automation」と「dataops-bastion-automation」を追加します。

![image](https://user-images.githubusercontent.com/8349954/170048048-9faba563-f0df-49db-95c2-c0915c3378e4.png)

これで設定は完了です。
