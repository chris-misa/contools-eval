args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

#n_cpus <- c(0, 1, 3, 7, 15)
n_cpus <- c(16)

n_containers <- seq(0, 100, 1)
container_labels <- seq(0, 100, 10)
x_label_at <- seq(0, 100, 10)
#n_containers <- seq(0, 96, 16)
#container_labels <- seq(0, 96, 16)
#x_label_at <- seq(0, 6, 1)

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

ccContainerMeans <- c()
chContainerMeans <- c()
cnContainerMeans <- c()
ccNativeMeans <- c()
chNativeMeans <- c()
cnNativeMeans <- c()

# Read through top-level (CPU param) manifest
con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  containerMeans <- c()
  containerSds <- c()
  nativeMeans <- c()
  nativeSds <- c()

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

    newMean <- mean(times)
    newSd <- sd(times)


    # Sort based on native / container
    if (length(grep("[0-9]+native.*", line2)) != 0) {
      nativeMeans <- c(nativeMeans, newMean)
      nativeSds <- c(nativeSds, newSd)

      # Sort based on topology
      if (length(grep(".*CC", line)) != 0) {
        ccNativeMeans <- c(ccNativeMeans, newMean)
      } else if (length(grep(".*CH", line)) != 0) {
        chNativeMeans <- c(chNativeMeans, newMean)
      } else if (length(grep(".*CN", line)) != 0) {
        cnNativeMeans <- c(cnNativeMeans, newMean)
      }

    } else if (length(grep("[0-9]+container.*", line2)) != 0) {
      containerMeans <- c(containerMeans, newMean)
      containerSds <- c(containerSds, newSd)

      # Sort based on topology
      if (length(grep(".*CC", line)) != 0) {
        ccContainerMeans <- c(ccContainerMeans, newMean)
      } else if (length(grep(".*CH", line)) != 0) {
        chContainerMeans <- c(chContainerMeans, newMean)
      } else if (length(grep(".*CN", line)) != 0) {
        cnContainerMeans <- c(cnContainerMeans, newMean)
      }

    } else {
      stop("Can't classify", line2)
    }

  }
  close(con2)

  #
  # Draw lines for this CPU setting
  #
  ybnds <- c(0, max(containerMeans))
  xbnds <- c(0, length(containerMeans) - 1)
  pdf(file=paste(data_path, "/", line, "/means.pdf", sep=""), width=6.5, height=5)
  par(mar=c(5, 5, 1, 3))
  plot(0, type="n", ylim=ybnds, xlim=xbnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("Mean RTT (",mu,"s)", sep="")), main="")

  grid()

  # Native Mean
  lines(seq(0, length(nativeMeans)-1), nativeMeans, type="p", pch=20, col="gray")
  # Container Means

  lines(seq(0, length(containerMeans)-1), containerMeans, type="p", pch=20, col="black")

  # Add x-axis
  axis(1, at=x_label_at, labels=container_labels, las=2)

  # Add legend
  legend("bottomright", legend=c("container", "native"), col=c("black", "gray"),
    pch=c(20,20), cex=0.8, bg="white")

  dev.off()


  #
  # Draw difference
  #
  pdf(file=paste(data_path, "/", line, "/mean_diffs.pdf", sep=""), width=6.5, height=5)

  par(mar=c(5, 5, 1, 3))
  plot(0, type="n", ylim=c(0, max(containerMeans - nativeMeans)), xlim=xbnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("Latency Overhead (",mu,"s)", sep="")), main="")

  grid()

  # Container Means
  lines(seq(0, length(containerMeans)-1), containerMeans - nativeMeans, type="p", pch=20, col="black")


  # Add x-axis
  axis(1, at=x_label_at, labels=container_labels, las=2)

  dev.off()
}
close(con)

#
# Fit means into matrices
#
cnContainerMeansMat <- matrix(cnContainerMeans, ncol=length(n_containers), byrow=T)
print(cnContainerMeansMat)
chContainerMeansMat <- matrix(chContainerMeans, ncol=length(n_containers), byrow=T)
print(chContainerMeansMat)
ccContainerMeansMat <- matrix(ccContainerMeans, ncol=length(n_containers), byrow=T)
print(ccContainerMeansMat)

cnNativeMeansMat <- matrix(cnNativeMeans, ncol=length(n_containers), byrow=T)
print(cnNativeMeansMat)
chNativeMeansMat <- matrix(chNativeMeans, ncol=length(n_containers), byrow=T)
print(chNativeMeansMat)
ccNativeMeansMat <- matrix(ccNativeMeans, ncol=length(n_containers), byrow=T)
print(ccNativeMeansMat)


# 
# #
# # Draw heatmaps for Containers
# #
# pdf(file=paste(data_path, "/cnContainerRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# cnDrawMat <- 1 - (cnContainerMeansMat / max(cnContainerMeans))
# image(n_containers, n_cpus, t(cnDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
# 
# pdf(file=paste(data_path, "/chContainerRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# chDrawMat <- 1 - (chContainerMeansMat / max(chContainerMeans))
# image(n_containers, n_cpus, t(chDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
# 
# pdf(file=paste(data_path, "/ccContainerRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# ccDrawMat <- 1 - (ccContainerMeansMat / max(ccContainerMeans))
# image(n_containers, n_cpus, t(ccDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
# #
# # Draw heatmaps for Native
# #
# pdf(file=paste(data_path, "/cnNativeRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# cnDrawMat <- 1 - (cnNativeMeansMat / max(cnNativeMeans))
# image(n_containers, n_cpus, t(cnDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
# 
# pdf(file=paste(data_path, "/chNativeRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# chDrawMat <- 1 - (chNativeMeansMat / max(chNativeMeans))
# image(n_containers, n_cpus, t(chDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
# 
# pdf(file=paste(data_path, "/ccNativeRTTMap.pdf", sep=""), width=10, height=5)
# # Omit the first column (which is the native base line means)
# ccDrawMat <- 1 - (ccNativeMeansMat / max(ccNativeMeans))
# image(n_containers, n_cpus, t(ccDrawMat), xlab="Number of Containers", ylab="Number of CPUs", main="")
# dev.off()
