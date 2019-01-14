
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

n_cpus <- c(seq(0, 15, 1))
n_containers <- 10


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

# Read through top-level manifest
con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }


  # Search lower level manifests for the number of containers
  con2 <- file(paste(data_path, "/", line, "/manifest", sep=""), "r")
  linePattern <- paste(n_containers, "containers_.*", sep="")
  while (T) {
    line2 <- readLines(con2, n=1)
    if (length(line2) == 0) {
      stop(paste("Ran out of lines in manifest for", line))
    }
    if (length(grep(linePattern, line2)) != 0) {
      filePath <- paste(data_path, "/", line, "/", line2, sep="")
      break
    }
  }
  close(con2)

  times <- readPingFile(filePath)$rtt

  cat("File:", filePath, "\n")
  cat("  mean:", mean(times), "(us)\n")

  means <- c(means, mean(times))
  sds <- c(sds, sd(times))
  ecdfs <- c(ecdfs, ecdf(times))
}
close(con)

ybnds <- c(0, max(means))
#ybnds <- c(0, 200)

#
# Evaluate ecdfs into matrix for heatmap
#
num_ecdfs <- cbind()
for (new_ecdf in ecdfs) {
    num_ecdfs <- cbind(num_ecdfs, new_ecdf(seq(ybnds[[1]],ybnds[[2]], 0.1)))
}


#
# Draw heatmap
#
pdf(file=paste(data_path, "/cdf_map.pdf", sep=""), width=10, height=5)

image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="Number of CPUs", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")

grid()
axis(1, at=seq(0, (length(n_cpus) - 1) * 3, 3), labels=n_cpus, las=2)

dev.off()

#
# Draw Means
#


