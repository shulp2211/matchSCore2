#' Integration of different datasets
#'
#' @param dataset_list A named list of annotated SingleCellExperiments objects.
#' The cell annotations are in the `cluster` slots.
#' @param marker_list A list of `cluster` specific markers from the input dataset.
#' @param ref The name of the reference dataset from the dataset_list. It has to
#' be the first in the `dataset_list`.
#' @param verbose Logical, controls the displaying of additional messages while
#' running the function. Defaults to `TRUE`.
#'
#' @return A list containing:
#' - `sce`: the integrated SingleCellExperiment object.
#' - `integrated`: the integrated scaled matrix.
#' - `counts`: the combined count matrix.
#' - `annotation_label`: the cell annotations.
#' - `dataset_label`: a vector indicating the dataset of origin for each cell.
#' - `genes`: the set of common genes used.
#'
#' @export
#'
#' @examples
#' # TODO
align_run <- function(dataset_list,
                      marker_list,
                      ref,
                      verbose = TRUE) {
  if (names(dataset_list)[1] != ref) {
    stop("The reference dataset is not the first of the dataset list")
  }

  if (ncol(dataset_list[[ref]]) > 2000) {
    prop <- round(2000 / (ncol(dataset_list[[ref]])), digits = 2)
  } else {
    prop <- 0.9
  }

  original <- dataset_list

  if (verbose) message("Defining the set of common genes")

  total <- 10
  # create progress bar
  pb <- txtProgressBar(min = 0, max = total, style = 3)

  Sys.sleep(0.1)
  # update progress bar
  progress <- 1
  setTxtProgressBar(pb, progress)

  start.time <- Sys.time()

  genes <- unique(unlist(marker_list))

  bg <- lapply(dataset_list, function(x) intersect(rownames(x), genes))
  l <- length(bg)
  t <- table(unlist(bg))
  genes <- names(t)[which(t == l)]

  progress <- 2
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  ref.p <- which(names(dataset_list) == ref)
  ref.cl <- factor(colData(dataset_list[[ref]])$cluster)
  sizes <- unlist(lapply(
    levels(ref.cl),
    function(x) length(ref.cl[which(ref.cl %in% x)])
  ))
  names(sizes) <- levels(ref.cl)

  train.sample <- unlist(
    sapply(
      levels(ref.cl),
      function(x) sample(x = which(ref.cl %in% x), size = sizes[names(sizes) == x] * prop)
    )
  )
  s <- colnames(dataset_list[[ref]])[train.sample]
  train.data <- logcounts(dataset_list[[ref]])[, train.sample]

  test.sample <- which(!colnames(dataset_list[[ref]]) %in% s)
  test.data <- logcounts(dataset_list[[ref]])[, test.sample]

  len <- length(dataset_list)
  dataset_list$ref <- dataset_list[[ref]][, train.sample]
  dataset_list$test <- dataset_list[[ref]][, test.sample]
  dataset_list <- dataset_list[-ref.p]

  d_list <- lapply(dataset_list, function(x) logcounts(x)[genes, ])
  d_list <- lapply(d_list, function(x) (x - min(x)) / (max(x) - min(x)))
  cl <- lapply(dataset_list, function(x) factor(colData(x)$cluster))

  progress <- 3
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  to_rm <- lapply(
    dataset_list,
    function(x) names(table(colData(x)$cluster))[which(as.vector(table(colData(x)$cluster)) < 10)]
  )

  cl1 <- cl
  for (i in c(1:length(to_rm))) {
    cl1[[i]][which(cl1[[i]] %in% to_rm[[i]])] <- NA
    cl1[[i]] <- factor(cl1[[i]])
  }


  cc <- lapply(seq(1:length(d_list)), function(x) sapply(levels(cl1[[x]]), function(y) rowMeans(d_list[[x]][genes, which(colData(dataset_list[[x]])$cluster == y)])))
  cc <- lapply(cc, function(x) apply(x, 1, function(y) median(y, na.rm = TRUE)))

  progress <- 4
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  len <- length(dataset_list)
  sequence <- c(1:len)
  pos <- which(names(dataset_list) == "ref")
  sequence <- sequence[-pos]

  H <- lapply(c(1:len), function(x) d_list[[x]] - cc[[x]])

  if (verbose) message(" Computing covariance matrixes... ")
  cov <- lapply(sequence, function(x) cov(H[[pos]], H[[x]]))

  if (verbose) message(" Single Value Decomposition of covariance matrixes ... ")
  svd_out <- lapply(cov, function(x) fast.svd(x))

  progress <- 5
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  Ropt <- lapply(svd_out, function(x) x$v %*% t(x$u))
  new_coord <- lapply(Ropt, function(x) x %*% t(H[[pos]]))

  progress <- 6
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  integrated <- cbind(H[[pos]], t(new_coord[[pos]]))

  for (i in 1:(length(new_coord) - 1)) {
    integrated <- cbind(integrated, t(new_coord[[i]]))
  }

  cells <- unlist(lapply(original, function(x) colnames(x)))
  colnames(integrated) <- cells

  counts_list <- lapply(original, function(x) counts(x)[genes, colnames(x)])

  progress <- 7
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  for (i in seq(1, l)) {
    if (i > 1) {
      counts <- cbind(counts, counts_list[[i]])
    } else {
      counts <- counts_list[[1]]
    }
  }

  progress <- 8
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  annotation <- unlist(lapply(original, function(x) colData(x)$cluster))

  progress <- 9
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)

  dataset <- unlist(lapply(seq(1:length(original)), function(x) rep(names(original)[x], ncol(original[[x]]))))

  progress <- 10
  Sys.sleep(0.1)
  setTxtProgressBar(pb, progress)
  close(pb)
  end.time <- Sys.time()
  time <- difftime(end.time, start.time, units = "mins")

  if (verbose) message(paste("The runtime is:", time, "min", sep = " "))

  sce <- SingleCellExperiment(assays = list(counts = counts))
  minx <- 0
  maxx <- max(as.vector(log10(counts + 1)), na.rm = TRUE)
  integrated <- t(apply(integrated, 1, function(x) (x - min(x)) / (max(x) - min(x))))
  assay(sce, "integrated") <- integrated
  colData(sce) <- DataFrame(cluster = annotation, batch = dataset)
  colnames(sce) <- cells

  return(
    list(
      sce = sce,
      counts = counts,    # TODOELI: I do not think it is required to return this, it is included in the sce itself (the counts assay)
      integrated = integrated,   # TODOELI: I do not think it is required to return this, it is included in the sce itself (the corresponding slot)
      annotation_label = annotation, # TODOELI: I do not think it is required to return this, it is included in the sce itself (the colData)
      dataset_label = dataset,
      genes = genes # TODOELI: I do not think it is required to return this - could this be simply the list of all genes included in the final object anyway
    )
  )
}
