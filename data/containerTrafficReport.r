args <- commandArgs(trailingOnly=T)
usage <- "rscript containerTrafficReport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

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
# Read and parse an iperf dump
# Assumes we had run with -P flag so just look for the [SUM] line
# and -f m so we convert from Mbits/sec
#
readIperfFile <- function(filePath) {
  con <- file(filePath, "r")
  linePattern <- "\\[SUM\\] .* ([0-9\\.]+) Mbits/sec"
  bw <- 0
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      cat("Failed to find '[SUM]' line in", filePath, "\n")
      break
    }
    matches <- grep(linePattern, line, value=T)
    if (length(matches) != 0) {
      bw <- as.numeric(sub(linePattern, "\\1", matches)) / 1000
      break
    }
  }
  close(con)
  bw
}

preproc_path <- paste(data_path, "/preproc", sep="")
if (file.exists(preproc_path)) {
  cat("Found preproc file\n")
  data <- read.table(preproc_path)
  rttMeans <- data$means
  rttSds <- data$sds
  bws <- data$bws
} else {

  cat("Preprocessing. . .\n")

  rttMeans <- c()
  rttSds <- c()
  bws <- c()

  con <- file(paste(data_path, "/manifest", sep=""), "r")
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }

    # Handle ping files
    if (length(grep("ping", line)) != 0) {
      pingData <- readPingFile(paste(data_path, "/", line, sep=""))

      mean <- mean(pingData$rtt)
      sd <- sd(pingData$rtt)

      rttMeans <- c(rttMeans, mean)
      rttSds <- c(rttSds, sd)

      cat("File:", line, "mean:", mean, "sd:", sd, "\n")
    }

    # Handle iperf files
    if (length(grep("iperf", line)) != 0) {
      bw <- readIperfFile(paste(data_path, "/", line, sep=""))

      bws <- c(bws, bw)

      cat("File:", line, "bandwidth:", bw, "\n")
    }
  }
  close(con)

  write.table(data.frame(means=rttMeans, sds=rttSds, bws=bws),
      file=preproc_path)
}

#
# Draw the graphs
#
ybnds <- c(0, max(rttMeans, rttSds))
xbnds <- c(0, max(bws))
pdf(file=paste(data_path, "/summary.pdf", sep=""), width=6.5, height=5)
par(mar=c(5, 5, 1, 1))
plot(0, type="n", xlab="Traffic (Gbps)", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="", ylim=ybnds, xlim=xbnds)

grid()

lines(bws, rttMeans, col="black", ylim=ybnds, type="l")
lines(bws, rttSds, col="gray", ylim=ybnds, type="l")

legend("topleft", legend=c("mean", "standard deviation"),
      col=c("black", "gray"),
      lty=1, cex=0.8, bg="white")

dev.off()

