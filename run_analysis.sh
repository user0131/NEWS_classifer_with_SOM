#!/bin/bash

# アラートSOM分析 自動実行スクリプト
# 使用方法: ./run_analysis.sh <input_csv_file>

set -e  # エラー時に停止

# 引数チェック
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <input_csv_file>"
    echo "例: $0 input_data.csv"
    exit 1
fi

INPUT_FILE="$1"

# ファイル存在チェック
if [ ! -f "$INPUT_FILE" ]; then
    echo "エラー: ファイル '$INPUT_FILE' が見つかりません"
    exit 1
fi

echo "=== アラートSOM分析を開始します ==="
echo "入力ファイル: $INPUT_FILE"
echo "開始時刻: $(date)"
echo

# 仮想環境の確認・アクティベート
if [ ! -d ".venv" ]; then
    echo "エラー: 仮想環境 (.venv) が見つかりません"
    echo "以下のコマンドで仮想環境を作成してください:"
    echo "python3 -m venv .venv"
    echo "source .venv/bin/activate"
    echo "pip install transformers torch pandas fugashi protobuf ipadic unidic-lite matplotlib seaborn numpy"
    exit 1
fi

source .venv/bin/activate
echo "仮想環境をアクティベートしました"

# 前回の出力ファイルをクリーンアップ
echo
echo "=== 前回の出力ファイルをクリーンアップ中 ==="
rm -f alert_bert_vectors.csv
rm -f アラートデータ_SOMクラスター付き.csv
rm -f SOM分類分析結果_quality_test_id版.txt
rm -f Rplots.pdf
rm -f SOM分類分析結果.txt
rm -rf image/
echo "クリーンアップ完了"

# ステップ1: BERTベクトル化
echo
echo "=== ステップ1: BERTベクトル化を開始 ==="
python detamake.py "$INPUT_FILE"
if [ $? -ne 0 ]; then
    echo "エラー: BERTベクトル化に失敗しました"
    exit 1
fi
echo "BERTベクトル化完了"

# ステップ2: SOM分析
echo
echo "=== ステップ2: SOM分析を開始 ==="
Rscript SOM解析.R
if [ $? -ne 0 ]; then
    echo "エラー: SOM分析に失敗しました"
    echo "Rとkohonen、readr、dplyrパッケージがインストールされているか確認してください"
    exit 1
fi
echo "SOM分析完了"

# ステップ3: 分類分析
echo
echo "=== ステップ3: 分類分析を開始 ==="
Rscript SOM全分類分析.R
if [ $? -ne 0 ]; then
    echo "エラー: 分類分析に失敗しました"
    exit 1
fi
echo "分類分析完了"

# ステップ4: 可視化
echo
echo "=== ステップ4: 可視化を開始 ==="
python SOM_可視化.py
if [ $? -ne 0 ]; then
    echo "エラー: 可視化に失敗しました"
    exit 1
fi
echo "可視化完了"

# 中間ファイルの削除
echo
echo "=== 中間ファイルをクリーンアップ中 ==="
rm -f alert_bert_vectors.csv
rm -f アラートデータ_SOMクラスター付き.csv
rm -f Rplots.pdf
rm -f SOM分類分析結果.txt
echo "中間ファイルのクリーンアップ完了"

# 結果の確認
echo
echo "=== 処理完了 ==="
echo "完了時刻: $(date)"
echo
echo "生成されたファイル:"
if [ -d "image" ]; then
    IMAGE_COUNT=$(ls image/*.png 2>/dev/null | wc -l)
    echo "- image/ フォルダ: ${IMAGE_COUNT}個の画像ファイル"
else
    echo "- 警告: imageフォルダが生成されませんでした"
fi

if [ -f "SOM分類分析結果_quality_test_id版.txt" ]; then
    LINE_COUNT=$(wc -l < "SOM分類分析結果_quality_test_id版.txt")
    echo "- SOM分類分析結果_quality_test_id版.txt: ${LINE_COUNT}行"
else
    echo "- 警告: 分析結果ファイルが生成されませんでした"
fi

echo
echo "分析が正常に完了しました！"
echo "結果画像は image/ フォルダ内を確認してください。" 