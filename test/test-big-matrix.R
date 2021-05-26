##
# Testing how to use bigmemory's functions and data structures in order to
#   1) load data without using a data.frame/matrix (via read.csv, read.table, etc.) 
#      as an intermediate,
#   2) take full advantage of biglasso's memory efficiency, and
#   3) subset a big.matrix object in such a way to construct training and
#      testing cross-validation sets.
# 
# For these tests I assume that the data has already been preprocessed so that 
# the predictors (X) and responses (Y, survival times and censor indicator) 
# are in separate files and that the factor predictors have already been mapped
# to sets of indicators (i.e. X is already the correct design matrix).
##
library(bigmemory)
library(biglasso)

set.seed(124)

# #### TEST 1 ####
# # generate an arbitrary set of data
# n <- 11
# p <- 7
# X <- matrix(rnorm(n * p), nrow = n)
# colnames(X) <- paste0("Var", 1:p)
# # write to disk
# write.csv(X, "data/bigmemory_test_data.csv", row.names = F)
# # remove existing objects from memory
# remove(X, n, p)
# 
# # load data as big.matrix object
# filename <- "data/bigmemory_test_data.csv"
# Xbig <- read.big.matrix(file.path(filename), header = T)

##### TEST 2 ####
#
filename <- "data/sample_SRTR_cleaned_X.csv"
pt <- proc.time()
Xbig.raw <- read.big.matrix(file.path(filename), header = T)
proc.time() - pt

xdesc <- bigmemory::describe(Xbig.raw)
#XX <- bigmemory::attach.big.matrix(xdesc)


Xdesc <- describe(Xbig.raw)
XX <- attach.big.matrix(Xbig.raw)
Xdesc@description$nrow
Xdesc@description$ncol

col.idx <- 1:Xdesc@description$nrow %in% 1:14
col.idx


Xdesc@address
str(Xdesc)
  
  
  
  
  