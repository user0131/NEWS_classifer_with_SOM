# SOM全分類分析スクリプト
# 100個全てのノードのニュースを全件表示する

library(readr)
library(dplyr)

# データの読み込み
data <- read_csv('アラートデータ_SOMクラスター付き.csv', show_col_types = FALSE)

# 分析結果を保存するファイル
output_file <- "SOM分類分析結果.txt"
sink(output_file)

cat("=== SOM分類分析結果（全100ノード） ===\n")
cat("生成日時:", Sys.time(), "\n")
cat("=====================================\n\n")

# 各SOMクラスターの要約統計を作成
cluster_summary <- data %>% 
  group_by(som_cluster) %>% 
  summarise(
    count = n(),
    .groups = 'drop'
  ) %>%
  arrange(som_cluster)

# 各ノードの全ニュースを表示
for (i in 1:nrow(cluster_summary)) {
  cluster_id <- cluster_summary$som_cluster[i]
  count <- cluster_summary$count[i]
  
  # 該当クラスターのデータを取得
  cluster_data <- data %>% 
    filter(som_cluster == cluster_id) %>%
    filter(!is.na(title))
  
  cat("ノード", sprintf("%02d", cluster_id), " [", count, "件]\n")
  cat("----------------------------------------\n")
  
  # 全てのタイトルを表示
  if (nrow(cluster_data) > 0) {
    for (j in 1:nrow(cluster_data)) {
      cat("・", cluster_data$title[j], "\n")
    }
  } else {
    cat("・データなし\n")
  }
  cat("\n")
}

# コンソール出力を元に戻す
sink()

cat("分析結果を", output_file, "に保存しました。\n") 