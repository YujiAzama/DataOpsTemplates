# DataOps 環境を展開するテンプレート

## 概要

この ARM テンプレートは、Microsoft Azure 上に DataOps 環境を展開するものです。

## テンプレートの構成要素

- Virtual Machine (Windows Server 2022)
  - Power Automate Desktop
  - Power BI Desktop
- Azure CosmosDB
- Azure Bastion

![image](https://user-images.githubusercontent.com/8349954/170065753-a30fe769-e0c2-4aea-aacf-133eecdbbf3b.png)

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

![image](https://user-images.githubusercontent.com/8349954/170057354-9f1b383d-aaae-44a5-b333-a2e7b8de8476.png)

これで設定は完了です。
