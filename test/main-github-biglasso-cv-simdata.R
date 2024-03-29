###############################################################
# SIMULATED DATA 
#
# Comparing glmnet & the (proposed) biglasso CV outputs
# for penalized Cox models
#
###############################################################
#=======================================#
#====== DATA GENERATING MECHANISM ======#
#=======================================#
sim.surv.weib <- function(n, lambda=0.01, rho=1, beta, rate.cens=0.001, round.times=F, round.digits=0) {
  # generate survival data (Weibull baseline hazard), adapted from
  # https://stats.stackexchange.com/questions/135124/how-to-create-a-toy-survival-time-to-event-data-with-right-censoring
  p <- length(beta)
  X <- matrix(rnorm(n * p), nrow = n)
  
  # Weibull latent event times
  v <- runif(n = n)
  latent.time <- (-log(v)/(lambda * exp(X %*% beta)))^(1/rho)
  
  # censoring times
  cens.time <- rexp(n = n, rate = rate.cens)
  
  # follow-up times and event indicators
  time <- pmin(latent.time, cens.time)
  if (round.times) time <- floor(time * 10^round.digits)/(10^round.digits) + 1#round(time, round.digits)
  status <- as.numeric(latent.time < cens.time)
  
  y <- cbind(time, status)
  colnames(y) <- c("time", "status")
  
  # data set
  return (list(X = X, y = y))
}
sim.surv <- function(n, p, p_nz, seed) {
  if (!missing(seed)) set.seed(seed)
  
  beta <- rnorm(p, 0, 1) * rbinom(p, 1, p_nz)
  dat <- sim.surv.weib(n = n, beta = beta)
  list("beta" = beta, "y" = dat$y, "X" = dat$X)
}
#=======================================#
#================ SETUP ================#
#=======================================#
#remove.packages("biglasso")
#devtools::install_github("dfleis/biglasso")
library(biglasso)
library(glmnet)
library(data.table) # fread() so I can read fewer columns while testing, otherwise read.csv is fine
options(datatable.fread.datatable=FALSE) # format the data as a data.frame instead of a data.table

# load custom R functions (mainly plot tools for the following tests)
source("~/projects/cv-biglasso-cox/R/plot.cv.biglasso.cox.R")
source("~/projects/cv-biglasso-cox/R/getmin.lambda.R")

set.seed(124)
n <- 100
p <- 500
p_nz <- 0.1
beta <- rnorm(p, 0, 1) * rbinom(p, 1, p_nz)

dat <- sim.surv.weib(n = n, beta = beta, rho = 10, rate.cens = 0.05, round.times=T)
y <- dat$y
X <- dat$X
Xbig <- as.big.matrix(X)

table(beta != 0)
table(y[,1], y[,2])
table(y[,2])

#===========================================#
#================ RUN TESTS ================#
#===========================================#

set.seed(124) # necessary for testing as the bigmemory package has an (unintended?) effect on random number generation
penalty  <- "enet"
alpha    <- 0.5 # elastic net penalty (alpha = 0 is ridge and alpha = 1 is lasso)
nfolds   <- 10
lambda   <- exp(seq(0, -6, length.out = 100))
grouped  <- T # grouped = F is 'basic' CV loss, grouped = T is 'V&VH' CV loss. see https://arxiv.org/pdf/1905.10432.pdf
parallel <- T # "use parallel  to fit each fold. Must register parallel before hand, such as doMC or others"
ncores   <- 10
trace.it <- 1
foldid   <- sample(cut(1:nrow(y), breaks = nfolds, labels = F))


pt <- proc.time()
cv.bl <- cv.biglasso(X       = Xbig,                               
                     y       = y,
                     family  = "cox",
                     penalty = penalty,
                     alpha   = alpha,
                     nfolds  = nfolds,
                     lambda  = lambda,
                     grouped = grouped,
                     cv.ind  = foldid,
                     ncores  = ncores,
                     trace   = as.logical(trace.it))
tm.bl <- proc.time() - pt

if (parallel) {doMC::registerDoMC(cores = ncores)}
pt <- proc.time()
cv.gn <- cv.glmnet(x        = X,                               
                   y        = y,
                   family   = "cox",
                   alpha    = alpha,
                   nfolds   = nfolds,
                   lambda   = lambda,
                   grouped  = grouped,
                   parallel = parallel,
                   trace.it = trace.it,
                   foldid   = foldid) 
tm.gn <- proc.time() - pt

#===========================================#
#================= FIGURES =================#
#===========================================#

###
plot(cv.bl)
plot(cv.gn)


beta.bl <- cv.bl$fit$beta
beta.gn <- cv.gn$glmnet.fit$beta
beta.bl.cv <- cv.bl$fit$beta[,which(cv.bl$lambda == cv.bl$lambda.min)]
beta.gn.cv <- cv.gn$glmnet.fit$beta[,which(cv.gn$lambda == cv.gn$lambda.min)]

### PLOT 2
myclrs <- c(rgb(26/255, 133/255, 255/255, 1), 
            rgb(212/255, 17/255, 89/255, 0.6))
plot(NA, xlim = c(1, ncol(X)), ylim = range(beta.bl.cv, beta.gn.cv), 
     ylab = "Coef. Value", xlab = "Covariate Index")
grid(); abline(h = 0, lwd = 2, col = 'gray50')
for (i in 1:ncol(X)) {
  #if (beta[i] != 0) points(x = i, y = beta[i], pch = 19, cex = 0.5, type = 'h')
  if (beta.bl.cv[i] != 0) segments(x0 = i, x1 = i, y0 = 0, y1 = beta.bl.cv[i], lwd = 4, col = myclrs[1])
  if (beta.gn.cv[i] != 0) segments(x0 = i, x1 = i, y0 = 0, y1 = beta.gn.cv[i], lwd = 4, col = myclrs[2])
}
legend("topleft", legend = c("biglasso", "glmnet"), col = myclrs, seg.len = 2, lwd = 4)

# plot(cv.bl$fit)
# plot(cv.gn$glmnet.fit)

### PLOT 3
myclrs2 <- c(rgb(26/255, 133/255, 255/255, 0.5), 
             rgb(212/255, 17/255, 89/255, 0.5))
plot(NA, xlab = expression(log(lambda)), ylab = "Fitted Coef.",
     xlim = range(log(lambda)), ylim = range(as.matrix(beta.gn), as.matrix(beta.bl)),
     main = "Elastic-Net Coefficient Paths")
grid(); abline(h = 0, lwd = 2, col = 'gray50')
for (i in 1:ncol(X)) {
  lines(beta.bl[i,] ~ log(lambda), col = myclrs2[1])
  lines(beta.gn[i,] ~ log(lambda), col = myclrs2[2])
}
legend("topright", legend = c("biglasso", "glmnet"), col = myclrs2, seg.len = 2, lwd = 4)


### PLOT 1
plot.compare.cv2(cv.bl, cv.gn)


tm.bl
tm.gn

