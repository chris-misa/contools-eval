
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

n_containers <- c(0, 1, 2, 3, 5, 7, 11, 17, 25, 38, 57, 86, 129, 291, 437, 656, 985)

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
# Read files from manifest
#

means <- c()
files <- c()

con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  pings <- readPingFile(paste(data_path, "/", line, sep=""))

  cat("File:", line, "\n")
  cat("  mean:", mean(pings$rtt), "(us)\n")

  if (length(pings$rtt) != 0) {
    means <- c(means, mean(pings$rtt))
    files <- c(files, line)
  }
}
close(con)

pdf(file=paste(data_path, "/means.pdf", sep=""), width=5, height=5)
plot(means, type="b", ylim=c(0, max(means)), xaxt="n", xlab="Number of containers", ylab=expression(paste("RTT (",mu,"s)", sep="")))
axis(1, at=seq(1,length(n_containers)), labels=n_containers, las=2)
dev.off()
