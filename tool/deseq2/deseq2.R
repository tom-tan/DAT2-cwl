#! /usr/bin/Rscript

args1 <- commandArgs(trailingOnly=TRUE)[1] # sample2condition.txt
args2 <- commandArgs(trailingOnly=TRUE)[2] # target2gene.txt

dir.create('output')

# DESeq2、tximportのインストール・読み込み→Dockerfileへ。
#if (!requireNamespace("BiocManager", quietly = TRUE))
#   install.packages("BiocManager")
#BiocManager::install("DESeq2")
#BiocManager::install("tximport")
library(DESeq2)
library(tximport) # 警告が出るがエラーではないので無視する

# サンプル情報を記載したリストを読み込む
s2c <- read.table(args1, header=T, sep="\t", stringsAsFactors=F)
s2c <- s2c[,c("sample", "group", "path")]
s2c$group <- gsub(" ", "_", s2c$group) # スペースが含まれているので置換する

# RSEMの出力ファイルの読み込み
files <- s2c$path
names(files) <- s2c$sample
# gene-levelの解析では以下コマンド
txi <- tximport(files, type="rsem", txIn=F, txOut=F)
# isoform-levelの解析では以下コマンド
#txi <- tximport(files, type="rsem", txIn=T, txOut=T)

# length=0を1に置換
txi$length[txi$length==0] <- 1

sampleTable <- data.frame(condition=s2c$group)
rownames(sampleTable) <- colnames(txi$counts)
dds <- DESeqDataSetFromTximport(txi, sampleTable, ~condition)

# Wald検定
dds_wt <- DESeq(dds)
res_wt <- results(dds_wt)
res_wt_naomit <- na.omit(res_wt) # NA を除外
# 尤度比検定
dds_lrt <- DESeq(dds, test="LRT", reduced=~1)
res_lrt <- results(dds_lrt)
res_lrt_naomit <- na.omit(res_lrt)

# 遺伝子名の付与（アノテーション）
t2g <- read.table(args2,header=T,stringsAsFactors=F)
res_wt_naomit$ens_gene <- row.names(res_wt_naomit)
res_wt_naomit_annot <- merge(as.data.frame(res_wt_naomit), unique(t2g[,2:3]), by="ens_gene")

# 発現変動のある転写産物を補正済みp値の低い順に並べる
res_wt_naomit_annot_sort <- res_wt_naomit_annot[order(res_wt_naomit_annot$padj),]

# 発現変動の大きな遺伝子、上位20個を表示させる（補正済みp値の低い20遺伝子）
head(res_wt_naomit_annot_sort, 20)

# 各カラムの説明は下記コマンドで表示させる
mcols(res_wt_naomit)

# データフレームの保存
write.table(res_wt_naomit_annot_sort, "output/Wald-test.result.txt", sep="\t", quote=F, row.names=F)

# 作図して表示させるコマンド
plotMA(res_wt, ylim=c(-2, 2))

# 保存するには下記コマンド
png("output/MAplot.png") # EPS形式にしたい場合はpostscript("MAplot.eps")を使う
plotMA(res_wt, ylim=c(-2, 2))
dev.off()

# 発現変動の大きな遺伝子を表示させる
head(res_wt_naomit_annot_sort)
# 上記コマンドで、FASN (ENSG00000169710) という遺伝子の発現変動が大きいことがわかる

# この遺伝子の発現量を図示する
plotCounts(dds, gene="ENSG00000169710", intgroup="condition")

# 保存する際はMA-plotと同様に
png("output/ENSG00000169710.png")
plotCounts(dds, gene="ENSG00000169710", intgroup="condition")
dev.off()

# 自前で作図するためにデータのみを抽出したい場合は returnData=T を加える
d <- plotCounts(dds, gene="ENSG00000169710", intgroup="condition", returnData=T)
