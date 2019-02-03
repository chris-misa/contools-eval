args <- commandArgs(trailingOnly=T)
usage <- "rscript volumeReport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

#
# Read and parse a bandwidth dump
#
readTrafficFile <- function(filePath) {
  con <- file(filePath, "r")
  timestamps <- c()
  rxBps <- c()
  txBps <- c()
  linePattern <- "\\[([0-9\\.]+)\\] rx_bps: ([0-9\\.]+) .* tx_bps: ([0-9\\.]+) .*"
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }
    matches <- grep(linePattern, line, value=T)
    if(length(matches) != 0) {
      ts <- as.numeric(sub(linePattern, "\\1", matches))
      rx <- as.numeric(sub(linePattern, "\\2", matches))
      tx <- as.numeric(sub(linePattern, "\\3", matches))

      timestamps <- c(timestamps, ts)
      rxBps <- c(rxBps, rx)
      txBps <- c(txBps, tx)
    }
  }
  close(con)
  data.frame(ts=timestamps, rx_bps=rxBps, tx_bps=txBps)
}

#
# Main work
#

rxMeans <- c()
rxSds <- c()

con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  filePath <- paste(data_path, "/", line, sep="")

  trafficData <- readTrafficFile(filePath)
  rxMeans <- c(rxMeans, mean(trafficData$rx_bps))
  rxSds <- c(rxSds, sd(trafficData$rx_bps))
  
  cat("File:", filePath, "\n")
}

cat("Means:\n")
print(rxMeans)

cat("SDs:\n")
print(rxSds)

pdf(file=paste(data_path, "/summary.pdf", sep=""), width=6.5, height=5)
plot(rxMeans)
lines(rxSds, col="gray")
dev.off()
