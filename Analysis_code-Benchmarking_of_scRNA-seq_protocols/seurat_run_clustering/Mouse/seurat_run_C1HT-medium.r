dir.create("out_Seurat/")

load(file="mmus_filt.RData")

pd <- colData(mmus_filt)
counts <- counts(mmus_filt)


library(Seurat)
library(Matrix)
cd.sparse=Matrix(data=round(as.matrix(counts),digits = 0),sparse=T)

summary(Matrix::colSums(cd.sparse[,]>0))
# Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#893    2050    2686    3464    4191   12891 
plot(density(Matrix::colSums(cd.sparse[,]>0)))
 




y <- Matrix::colSums(cd.sparse[,]>0)

q <- quantile(y,probs=0.05) 

data <- CreateSeuratObject(raw.data = cd.sparse, min.cells = 5, min.genes = q, project = "C1HT-medium")
dim(data@data)
#26701  1060

mito.genes <- grep(pattern = "^Mt", x = rownames(x = data@data), value = TRUE)
percent.mito <- Matrix::colSums(data@raw.data[mito.genes, ])/Matrix::colSums(data@raw.data)
ribo.genes <- grep(pattern = "^RP|RB", x = rownames(x = data@data), value = TRUE)
percent.ribo <- Matrix::colSums(data@raw.data[ribo.genes, ])/Matrix::colSums(data@raw.data)
# AddMetaData adds columns to object@meta.data, and is a great place to
# stash QC stats
data <- AddMetaData(object = data, metadata = pd, col.name = colnames(pd))
data <- AddMetaData(object = data, metadata = percent.mito, col.name = "percent.mito")
data <- AddMetaData(object = data, metadata = percent.ribo, col.name = "percent.ribo")


data <- NormalizeData(object = data, normalization.method = "LogNormalize", scale.factor = 10000)

data <- FindVariableGenes(object = data, mean.function = ExpMean, dispersion.function = LogVMR, x.low.cutoff = 0.18, 
                          x.high.cutoff = 3, y.cutoff = 0.5)


data <- ScaleData(object = data,vars.to.regress = c("nUMI"))

data <- RunPCA(object = data, pc.genes = data@var.genes, do.print = TRUE, pcs.print = 1:16, genes.print = 5)
data <- ProjectPCA(object = data, do.print = F)

PCElbowPlot(object = data)
data <- FindClusters(object = data, reduction.type = "pca", dims.use = 1:11, resolution = 0.3, print.output = 0, save.SNN = TRUE,force.recalc=TRUE)
table(data@ident)
0   1   2   3   4 
401 297 294  50  18 

data <- RunTSNE(object = data, dims.use = 1:11, do.fast = TRUE,force.recalc=T)


library(ggplot2)


tsne1<-TSNEPlot(object = data)
tsne<-tsne1+ ggtitle("Clusters") +scale_color_manual(values=col)+ theme(legend.text = element_text(size = 14),axis.text =element_text(size = 16),text = element_text(size = 20)) + theme(plot.margin = unit(c(0.3,1,1,0), "lines"))
tsne

dir.create("out_Seurat/plots")
png(file="out_Seurat/plots/TSNE_clusters.png",width = 6, height = 6,units = 'in', res = 300)
tsne
dev.off()


dir.create("out_Seurat/plots")
png(file="out_Seurat/plots/TSNE_clusters.png",width = 8, height = 8,units = 'in', res = 300)
tsne
dev.off()



png(file="out_Seurat/plots/TSNE_Known_markers2.png",width = 12, height = 12, units = 'in', res = 600)
FeaturePlot(object = data, features.plot = c("Polr1b","Slc26a3", "Ceacam1","Reg4","Muc2","Agr2","Pcna","Chga","Chgb"), cols.use = c("lightgray", "blue"), 
            reduction.use = "tsne")
dev.off()



markers=FindAllMarkers(data,test.use = "wilcox",only.pos = T)

