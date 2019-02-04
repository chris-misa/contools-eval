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
      rx <- as.numeric(sub(linePattern, "\\2", matches)) / 1000000
      tx <- as.numeric(sub(linePattern, "\\3", matches)) / 1000000

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

rxMeansContainer <- c()
rxSdsContainer <- c()
rxMeansProcess <- c()
rxSdsProcess <- c()
txMeansContainer <- c()
txSdsContainer <- c()
txMeansProcess <- c()
txSdsProcess <- c()

con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  filePath <- paste(data_path, "/", line, sep="")

  trafficData <- readTrafficFile(filePath)

  if (length(grep("container", line)) == 0) {
    rxMeansProcess <- c(rxMeansProcess, mean(trafficData$rx_bps))
    rxSdsProcess <- c(rxSdsProcess, sd(trafficData$rx_bps))
    txMeansProcess <- c(txMeansProcess, mean(trafficData$tx_bps))
    txSdsProcess <- c(txSdsProcess, sd(trafficData$tx_bps))
  } else {
    rxMeansContainer <- c(rxMeansContainer, mean(trafficData$rx_bps))
    rxSdsContainer <- c(rxSdsContainer, sd(trafficData$rx_bps))
    txMeansContainer <- c(txMeansContainer, mean(trafficData$tx_bps))
    txSdsContainer <- c(txSdsContainer, sd(trafficData$tx_bps))
  }
    
  cat("File:", filePath, "\n")
}

pdf(file=paste(data_path, "/rx_summary.pdf", sep=""), width=6.5, height=5)
plot(rxMeansProcess, col="black", type="l", xlab="", ylab="Traffic Rate (Mbps)")
lines(rxSdsProcess, col="gray")
lines(rxMeansContainer, col="blue")
lines(rxSdsContainer, col="lightblue")
dev.off()


pdf(file=paste(data_path, "/tx_summary.pdf", sep=""), width=6.5, height=5)
plot(txMeansProcess, col="black", type="l", xlab="", ylab="Traffic Rate (Mbps)")
lines(txSdsProcess, col="gray")
lines(txMeansContainer, col="blue")
lines(txSdsContainer, col="lightblue")
dev.off()
