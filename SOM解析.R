# 必要なパッケージのインストール (初回のみ)
# install.packages("kohonen") # SOMの実装
# install.packages("readr")   # CSV読み込みを効率化
# install.packages("dplyr")   # データ操作

# パッケージの読み込み
library(kohonen)
library(readr)
library(dplyr)

# 1. BERTベクトル化されたデータの読み込み
# 事前にPythonスクリプトで'alert_bert_vectors.csv'が生成されていることを前提とします。
# このファイルのパスを適切に設定してください。
bert_vectors_file <- "alert_bert_vectors.csv"

if (!file.exists(bert_vectors_file)) {
  stop(paste("エラー: BERTベクトルファイルが見つかりません。", bert_vectors_file, "が存在することを確認してください。"))
}

# CSVファイルを読み込む
bert_data <- read_csv(bert_vectors_file, col_names = TRUE)

# データフレームの最初の数行を確認
print("BERTベクトルの最初の数行:")
print(head(bert_data))
print(paste("データセットの次元:", dim(bert_data)[1], "行", dim(bert_data)[2], "列"))

# 元のデータ部分とBERTベクトル部分を分離
original_columns <- c("title", "url", "description", "category")
original_data <- bert_data[, original_columns]

# BERTベクトル部分のみを抽出（bert_dim_0からbert_dim_767）
bert_columns <- grep("^bert_dim_", names(bert_data), value = TRUE)
bert_vectors_only <- bert_data[, bert_columns]

print(paste("BERTベクトル部分の次元:", dim(bert_vectors_only)[1], "行", dim(bert_vectors_only)[2], "列"))

# データが数値であることを確認し、必要に応じてNAを処理
# 通常、BERTベクトルにはNAは含まれませんが、念のため確認
if (any(is.na(bert_vectors_only))) {
  print("データにNAが含まれています。SOM分析の前にNAを処理します。")
  # 例: NAを含む行を削除
  bert_vectors_only <- na.omit(bert_vectors_only)
  print(paste("NA処理後のデータセットの次元:", dim(bert_vectors_only)[1], "行", dim(bert_vectors_only)[2], "列"))
}

# SOMモデルのトレーニングにはデータフレームではなく行列形式が必要
data_matrix <- as.matrix(bert_vectors_only)

# 2. SOMモデルの作成とトレーニング
# SOMのグリッドサイズを設定
# データが少ない場合はグリッドサイズを調整
data_size <- nrow(data_matrix)
if (data_size < 10) {
  # データが非常に少ない場合は1×データ数のグリッドを使用
  grid_x <- data_size
  grid_y <- 1
  print(paste("データサイズが非常に小さいため、グリッドサイズを", grid_x, "x", grid_y, "に調整しました"))
} else if (data_size < 100) {
  # データが少ない場合はより小さなグリッドを使用
  grid_size <- min(5, floor(sqrt(data_size)))
  grid_x <- grid_size
  grid_y <- grid_size
  print(paste("データサイズが小さいため、グリッドサイズを", grid_x, "x", grid_y, "に調整しました"))
} else {
  # 5x5のグリッドを使用（25ノード）
  grid_x <- 5
  grid_y <- 5
  print(paste("グリッドサイズを", grid_x, "x", grid_y, "に設定しました"))
}

# SOMモデルのトレーニング
set.seed(123) # 再現性のためのシード設定
som_model <- som(
  data_matrix,
  grid = somgrid(grid_x, grid_y, topo = "rectangular"), # 長方形グリッド
  rlen = min(100, data_size * 10), # データが少ない場合は反復数も調整
  alpha = c(0.05, 0.01), # 学習率の初期値と最終値
  radius = c(max(grid_x, grid_y), 0), # 近傍半径の初期値と最終値を調整
  normalizeData = TRUE # データを正規化してトレーニング (重要)
)

print("SOMモデルのトレーニングが完了しました。")

# 3. SOMの結果の可視化と解釈

# 訓練誤差のプロット (収束の確認)
plot(som_model, type = "changes", main = "SOM Training Progress (Quantization Error)")

# ノードのマップ (データの分布の確認)
# 各ノードにどれだけのデータポイントがマッピングされたか
plot(som_model, type = "counts", main = "Node Counts")

# ノード間の距離（U-matrix）
# 暗い色は似ているノード、明るい色は異なるノードを示す
plot(som_model, type = "dist.neighbours", main = "U-Matrix (Distances between Nodes)")

# 4. SOMクラスタリング結果の取得と元のデータへの紐付け

# 各データポイントがどのノードにマッピングされたかを取得
cluster_assignment <- som_model$unit.classif

# 元のデータにクラスター情報を追加
original_data$som_cluster <- cluster_assignment
print("クラスタリング結果を元のデータに追加しました。最初の数行:")
print(head(original_data))

# クラスター情報を追加したデータをCSVファイルとして保存
output_filename <- "アラートデータ_SOMクラスター付き.csv"
write_csv(original_data, output_filename)
print(paste("クラスター情報を追加したデータを", output_filename, "として保存しました。"))

# 各クラスターの代表的なデータポイント（または平均ベクトル）の分析
# 各ノードの平均ベクトル (コードブックベクトル)
codebook_vectors <- som_model$codes[[1]]
print("SOMコードブックベクトルの最初の数行 (各ノードの代表ベクトル):")
print(head(codebook_vectors))

# 特定のクラスタリング結果の分析 (例: 各クラスターに属するアラートのタイトルを調べる)
# 例えば、クラスター1に属するアラートのタイトルを表示
cluster_id_to_examine <- 1
if (cluster_id_to_examine %in% original_data$som_cluster) {
  cluster_alerts <- original_data %>%
    filter(som_cluster == cluster_id_to_examine) %>%
    select(title, description, category)
  
  print(paste0("SOMクラスター ", cluster_id_to_examine, " に属するアラートの例:"))
  print(cluster_alerts)
} else {
  print(paste0("クラスターID ", cluster_id_to_examine, " は存在しません。"))
}

# クラスタリング結果の可視化 (k-meansを重ねる)
# SOMのコードブックベクトルに対してk-meansを行い、ノードをさらにクラスタリングする
if (nrow(codebook_vectors) >= 5) {
  num_clusters_kmeans <- 5 # 識別したいクラスターの数
} else {
  num_clusters_kmeans <- max(1, nrow(codebook_vectors) - 1) # ノード数が少ない場合は適切な数に調整
}

if (num_clusters_kmeans > 1) {
  som_cluster_kmeans <- kmeans(codebook_vectors, centers = num_clusters_kmeans, iter.max = 100)

  # SOMマップ上にk-meansの結果をプロット
  plot(som_model, type = "mapping",
       bg = som_cluster_kmeans$cluster[som_model$unit.classif], # 各データポイントの背景色をk-meansクラスターで着色
       main = "SOM Clusters based on K-means of Codebook Vectors")

  # k-meansクラスタリングの結果をSOMマップのノードに割り当てる
  # 各ノードがどのk-meansクラスターに属するか
  node_kmeans_clusters <- som_cluster_kmeans$cluster

  # SOMマップ上の各ノードに割り当てられたk-meansクラスターで色付け
  plot(som_model, type = "quality", property = node_kmeans_clusters,
       palette.name = rainbow, main = "K-means Clusters on SOM Nodes")
} else {
  print("ノード数が少ないため、k-meansクラスタリングをスキップします。")
}