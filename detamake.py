#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日本語BERTを使用してアラートデータをベクトル化するスクリプト
"""

import pandas as pd
import torch
from transformers import BertTokenizer, BertModel
import sys
import os

def main():
    # 引数チェック
    if len(sys.argv) != 2:
        print("使用方法: python detamake.py <input_csv_file>")
        print("例: python detamake.py input_data.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # ファイル存在チェック
    if not os.path.exists(input_file):
        print(f"エラー: ファイル '{input_file}' が見つかりません")
        sys.exit(1)
    
    print(f"入力ファイル: {input_file}")
    
    # データの読み込み
    try:
        data = pd.read_csv(input_file)
        print(f"データ読み込み完了: {len(data)}件")
    except Exception as e:
        print(f"エラー: CSVファイルの読み込みに失敗しました - {e}")
        sys.exit(1)
    
    # 必要な列の確認
    required_columns = ['title', 'url', 'description', 'category']
    missing_columns = [col for col in required_columns if col not in data.columns]
    
    if missing_columns:
        print(f"エラー: 以下の列が不足しています: {missing_columns}")
        print(f"現在の列: {list(data.columns)}")
        sys.exit(1)
    
    print("必要な列の確認完了")
    
    # 日本語BERTモデルの読み込み
    print("日本語BERTモデルを読み込み中...")
    model_name = 'cl-tohoku/bert-base-japanese-whole-word-masking'
    tokenizer = BertTokenizer.from_pretrained(model_name)
    model = BertModel.from_pretrained(model_name)
    
    # GPU使用可能チェック
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model.to(device)
    print(f"使用デバイス: {device}")
    
    # テキストの結合（title + description）
    print("テキストデータを結合中...")
    data['combined_text'] = data['title'].fillna('') + ' ' + data['description'].fillna('')
    
    # BERTベクトル化
    print("BERTベクトル化を開始...")
    vectors = []
    batch_size = 32  # バッチサイズ
    
    total_batches = (len(data) + batch_size - 1) // batch_size
    
    for i in range(0, len(data), batch_size):
        batch_texts = data['combined_text'][i:i+batch_size].tolist()
        
        # バッチトークン化
        inputs = tokenizer(batch_texts, 
                          truncation=True, 
                          padding=True, 
                          max_length=512, 
                          return_tensors='pt')
        
        inputs = {key: value.to(device) for key, value in inputs.items()}
        
        # BERT推論
        with torch.no_grad():
            outputs = model(**inputs)
            # [CLS]トークンの出力を使用
            batch_vectors = outputs.last_hidden_state[:, 0, :].cpu().numpy()
            vectors.extend(batch_vectors)
        
        current_batch = i // batch_size + 1
        print(f"進捗: {current_batch}/{total_batches} バッチ完了")
    
    print("BERTベクトル化完了")
    
    # ベクトルをDataFrameに変換
    vector_df = pd.DataFrame(vectors, columns=[f'bert_dim_{i}' for i in range(768)])
    
    # 元データと結合
    result_df = pd.concat([data[required_columns].reset_index(drop=True), 
                          vector_df.reset_index(drop=True)], axis=1)
    
    # 出力ファイル保存
    output_file = 'alert_bert_vectors.csv'
    result_df.to_csv(output_file, index=False)
    
    print(f"ベクトル化完了: {output_file} に保存")
    print(f"出力データ形状: {result_df.shape}")
    print(f"ファイルサイズ: {os.path.getsize(output_file) / 1024 / 1024:.1f}MB")

if __name__ == "__main__":
    main()