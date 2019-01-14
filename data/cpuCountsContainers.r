
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

n_cpus <- seq(0, 4, 1)
n_containers <- seq(0, 100, 1)


#
# Read and parse a dump from ping
#
readPingFile <- function(filePath) {
  con <- file(filePath, "r")
  timestamps <- c()
  rtts <- c()
  linePattern <- "\\[([0-9\\.]+)\\] .* time=([0-9\\.]+) ms"
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }
    matches <- grep(linePattern, line, value=T)

    if (length(matches) != 0) {
      ts <- as.numeric(sub(linePattern, "\\1", matches))
      rtt <- as.numeric(sub(linePattern, "\\2", matches)) * 1000

      timestamps <- c(timestamps, ts)
      rtts <- c(rtts, rtt)
    }
  }
  close(con)
  data.frame(rtt=rtts, ts=timestamps)
}


#
# Main work
#
means <- c()
sds <- c()
ecdfs <- c()

ccMeans <- c()
chMeans <- c()
cnMeans <- c()

# Read through top-level (CPU param) manifest
con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }


  # Read through container param manifest
  con2 <- file(paste(data_path, "/", line, "/manifest", sep=""), "r")
  while (T) {
    line2 <- readLines(con2, n=1)
    if (length(line2) == 0) {
      break
    }
    filePath <- paste(data_path, "/", line, "/", line2, sep="")

    times <- readPingFile(filePath)$rtt

    cat("File:", filePath, "\n")
    cat("  mean:", mean(times), "(us)\n")

    means <- c(means, mean(times))
    sds <- c(sds, sd(times))
    ecdfs <- c(ecdfs, ecdf(times))

    if (length(grep(".+_CC", line)) != 0) {
      ccMeans <- c(ccMeans, mean(times))
    } else if (length(grep(".+_CH", line)) != 0) {
      chMeans <- c(chMeans, mean(times))
    } else if (length(grep(".+_CN", line)) != 0) {
      cnMeans <- c(cnMeans, mean(times))
    }
  }
  close(con2)
}
close(con)

ybnds <- c(0, max(means))
#ybnds <- c(0, 200)

#
# Fit means into matrices
#
cnMeansMat <- matrix(cnMeans, ncol=length(n_containers)+1, byrow=T)
print(cnMeansMat)
chMeansMat <- matrix(chMeans, ncol=length(n_containers)+1, byrow=T)
print(chMeansMat)
ccMeansMat <- matrix(ccMeans, ncol=length(n_containers)+1, byrow=T)
print(ccMeansMat)

#
# Draw heatmaps
#
pdf(file=paste(data_path, "/cnRTTMap.pdf", sep=""), width=10, height=5)
# Omit the first column (which is the native base line means)
cnDrawMat <- 1 - (cnMeansMat[,-1] / max(cnMeans))
image(n_containers, n_cpus, t(cnDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
dev.off()

pdf(file=paste(data_path, "/chRTTMap.pdf", sep=""), width=10, height=5)
# Omit the first column (which is the native base line means)
chDrawMat <- 1 - (chMeansMat[,-1] / max(chMeans))
image(n_containers, n_cpus, t(chDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
dev.off()

pdf(file=paste(data_path, "/ccRTTMap.pdf", sep=""), width=10, height=5)
# Omit the first column (which is the native base line means)
ccDrawMat <- 1 - (ccMeansMat[,-1] / max(ccMeans))
image(n_containers, n_cpus, t(ccDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
dev.off()
