
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

#n_containers <- c(0, 1, 2, 3, 5, 7, 11, 17, 25, 38, 57, 86, 129, 291, 437, 656, 985)

n_containers <- c("native", seq(from=0, to=500, by=10))
# n_containers <- c("native", seq(0, 60, 5))
# n_containers <- c("Native", "Local", "Same", "Different")

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

drawArrowsCenters <- function(ys, belows, aboves, color, centers) {
  arrows(centers, ys - belows,
         centers, ys + aboves,
         length=0.05, angle=90, code=3, col=color)
}


#
# Main Work: read files from manifest
#

means <- c()
sds <- c()
mins <- c()
maxs <- c()
files <- c()
ecdfs <- c()

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
    sds <- c(sds, sd(pings$rtt))
    mins <- c(mins, min(pings$rtt))
    maxs <- c(maxs, max(pings$rtt))
    files <- c(files, line)
    new_ecdf <- ecdf(pings$rtt)
    ecdfs <- c(ecdfs, new_ecdf)

    #
    # Make cdfs for reference
    #
    # pdf(file=paste(data_path, "/", line, "_cdf.pdf", sep=""))
    # fn <- ecdf(pings$rtt)
    # plot(fn)
    # dev.off()
  }
}
close(con)

ybnds <- c(0, max(means + sds))

#
# Evaluate ecdfs into matrix for heatmap
#
num_ecdfs <- cbind()
for (new_ecdf in ecdfs) {
    num_ecdfs <- cbind(num_ecdfs, new_ecdf(seq(ybnds[[1]],ybnds[[2]], 0.1)))
}

#
# Draw means line-graph
#
pdf(file=paste(data_path, "/means.pdf", sep=""), width=6.5, height=5)

# image(seq(0,30), seq(0,500,0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")

# plot(seq(0,length(means)-1), means, type="b", ylim=ybnds, xaxt="n", xlab="", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")
plot(seq(0,length(means)-1), means, type="b", ylim=ybnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")

grid()

lines(seq(0,length(means)-1), mins, type="b", ylim=ybnds, lty=2, col="gray")
axis(1, at=seq(0, length(n_containers) - 1), labels=n_containers, las=2)

dev.off()

#
# Draw heatmap
#
pdf(file=paste(data_path, "/cdf_map.pdf", sep=""), width=6.5, height=5)

# image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")
image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="Number of extra containers", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")

grid()
axis(1, at=seq(0, length(n_containers) - 1), labels=n_containers, las=2)


dev.off()
