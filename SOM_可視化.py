import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
import numpy as np
from matplotlib import font_manager
import matplotlib as mpl
from matplotlib.patches import Rectangle

# 日本語フォントの設定
def setup_japanese_font():
    """日本語フォントを設定する"""
    # macOS用の日本語フォント候補
    japanese_fonts = [
        'Hiragino Sans',
        'Hiragino Kaku Gothic Pro',
        'Yu Gothic',
        'Noto Sans CJK JP',
        'DejaVu Sans'  # フォールバック
    ]
    
    # 利用可能なフォントを確認
    available_fonts = [f.name for f in font_manager.fontManager.ttflist]
    
    for font in japanese_fonts:
        if font in available_fonts:
            plt.rcParams['font.family'] = font
            print(f"フォントを設定しました: {font}")
            return font
    
    # フォールバック: Unicode文字を適切に処理
    plt.rcParams['font.family'] = 'DejaVu Sans'
    mpl.rcParams['axes.unicode_minus'] = False
    print("警告: 日本語フォントが見つかりません。代替フォントを使用します。")
    return 'DejaVu Sans'

# フォント設定を実行
setup_japanese_font()

def node_to_grid_position(node_number):
    """ノード番号(1-25)を5×5グリッドの(row, col)座標に変換"""
    # ノード番号は1から始まるので、0ベースに変換
    node_index = node_number - 1
    row = node_index // 5
    col = node_index % 5
    return row, col

def create_visualizations():
    # データの読み込み
    data = pd.read_csv('アラートデータ_SOMクラスター付き.csv')
    
    # imageディレクトリを作成（存在しない場合）
    os.makedirs('image', exist_ok=True)
    
    # 全SOMノード（1-25）を作成
    all_som_nodes = list(range(1, 26))
    
    # カテゴリごとのSOM分布を計算（全ノードを含む）
    category_data = data.groupby(['category', 'som_cluster']).size().unstack(fill_value=0)
    
    print(f"全体の統計:")
    print(f"- 総データ数: {len(data)}")
    print(f"- カテゴリ数: {len(data['category'].unique())}")
    print(f"- SOMクラスター数: {len(data['som_cluster'].unique())}")
    
    # 各カテゴリの統計
    category_stats = data['category'].value_counts()
    print(f"\nカテゴリ別統計（上位10個）:")
    for cat, count in category_stats.head(10).items():
        print(f"- {cat}: {count}件")
    
    # 各カテゴリごとに個別のグリッド画像を作成
    for category in category_data.index:
        fig, ax = plt.subplots(figsize=(10, 10))
        
        # 該当カテゴリのデータを全ノード（1-25）に拡張
        cat_data_series = category_data.loc[category]
        
        # 5×5のグリッドデータを作成
        grid_data = np.zeros((5, 5))
        node_counts = {}
        
        for node in all_som_nodes:
            if node in cat_data_series.index:
                count = cat_data_series[node]
            else:
                count = 0
            node_counts[node] = count
            
            # ノード番号をグリッド座標に変換
            row, col = node_to_grid_position(node)
            grid_data[row, col] = count
        
        # 最大値を取得
        max_count = int(grid_data.max())
        total_count = int(grid_data.sum())
        
        # カラーマップの設定（件数に応じた色の濃度）
        if max_count > 0:
            # 薄い青から濃い青のカラーマップ
            cmap = plt.cm.Blues
            # 正規化（最大値を1.0とする）
            norm = plt.Normalize(vmin=0, vmax=max_count)
        else:
            cmap = plt.cm.Blues
            norm = plt.Normalize(vmin=0, vmax=1)
        
        # グリッドを描画
        for row in range(5):
            for col in range(5):
                # ノード番号を計算
                node_number = row * 5 + col + 1
                count = int(grid_data[row, col])
                
                # マスの色を決定
                if max_count > 0:
                    color_intensity = count / max_count
                    color = cmap(color_intensity)
                else:
                    color = cmap(0)
                
                # 最大値の場合は赤色で強調
                if count == max_count and max_count > 0:
                    color = 'red'
                
                # 長方形（マス）を描画
                rect = Rectangle((col, 4-row), 1, 1, 
                               facecolor=color, 
                               edgecolor='black', 
                               linewidth=2)
                ax.add_patch(rect)
                
                # マスの中央に件数とノード番号を表示
                text_color = 'white' if (count > max_count * 0.5 and max_count > 0) else 'black'
                
                # ノード番号（小さく表示）
                ax.text(col + 0.15, 4-row + 0.8, f'N{node_number}', 
                       ha='left', va='top', fontsize=8, 
                       color=text_color, weight='bold')
                
                # 件数（大きく表示）
                ax.text(col + 0.5, 4-row + 0.4, f'{count}', 
                       ha='center', va='center', fontsize=16, 
                       color=text_color, weight='bold')
        
        # グラフの設定
        ax.set_xlim(0, 5)
        ax.set_ylim(0, 5)
        ax.set_aspect('equal')
        
        # 軸の設定
        ax.set_xticks(np.arange(0.5, 5.5, 1))
        ax.set_yticks(np.arange(0.5, 5.5, 1))
        ax.set_xticklabels([f'列{i+1}' for i in range(5)])
        ax.set_yticklabels([f'行{5-i}' for i in range(5)])
        
        # タイトルを日本語で設定
        title_text = f'カテゴリ: {category}\n合計: {total_count}件, 最大: {max_count}件/ノード'
        ax.set_title(title_text, fontsize=16, fontweight='bold', pad=20)
        
        # カラーバーを追加
        if max_count > 0:
            sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
            sm.set_array([])
            cbar = plt.colorbar(sm, ax=ax, shrink=0.8)
            cbar.set_label('アラート件数', fontsize=12)
        
        # 最大値ノードの情報を追加
        if max_count > 0:
            max_nodes = []
            for node in range(1, 26):
                if node_counts[node] == max_count:
                    max_nodes.append(f"ノード{node}")
            
            if max_nodes:
                max_info = f"最大値ノード: {', '.join(max_nodes)}"
                ax.text(0.02, 0.98, max_info, transform=ax.transAxes, 
                       fontsize=12, verticalalignment='top',
                       bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.8))
        
        # グリッドの説明を追加
        grid_info = "5×5 SOMグリッド\n各マス = 1ノード\nN数字 = ノード番号\n数字 = アラート件数"
        ax.text(0.98, 0.02, grid_info, transform=ax.transAxes, 
               fontsize=10, verticalalignment='bottom', horizontalalignment='right',
               bbox=dict(boxstyle='round', facecolor='lightgray', alpha=0.8))
        
        # レイアウトの調整
        plt.tight_layout()
        
        # ファイル名を安全にする（特殊文字を除去）
        safe_filename = "".join(c for c in category if c.isalnum() or c in (' ', '-', '_')).rstrip()
        safe_filename = safe_filename.replace(' ', '_')
        
        # 画像を保存
        output_path = f'image/{safe_filename}_grid.png'
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"グリッド画像を保存しました: {output_path}")
        
        # 該当カテゴリの主な情報を表示
        if total_count > 0:
            print(f"  - カテゴリ '{category}': 合計{total_count}件")
            print(f"    最多ノード: {max_nodes[0] if max_nodes else 'なし'} ({max_count}件)")
            
            # 上位3ノードの情報
            top_nodes = sorted([(node, count) for node, count in node_counts.items()], 
                             key=lambda x: x[1], reverse=True)[:3]
            top_info = [f"ノード{node}({count}件)" for node, count in top_nodes if count > 0]
            if len(top_info) > 1:
                print(f"    上位ノード: {', '.join(top_info)}")

    print(f"\n全てのグリッド可視化が完了しました。imageフォルダに{len(category_data)}個の画像が保存されています。")

if __name__ == "__main__":
    create_visualizations() 