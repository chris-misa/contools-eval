filterOutliers <- T

args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

#n_containers <- c(0, 1, 2, 3, 5, 7, 11, 17, 25, 38, 57, 86, 129, 291, 437, 656, 985)

# n_containers <- c("native", seq(from=0, to=500, by=10))
n_containers <- c(seq(0, 100, 5))
x_label_at <- c(seq(0, 20, 1))
# n_containers <- c("Native", "Local", "Same", "Different")


#
# Computes the max of distribution
#
mode <- function(data) {
  df <- hist(data, plot=F, breaks=1000)
  df$mids[which.max(df$counts)]
}

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
modes <- c()
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

  if (length(pings$rtt) != 0) {
    means <- c(means, mean(pings$rtt))
    modes <- c(modes, mode(pings$rtt))
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

ybnds <- c(0, max(means))
xbnds <- c(0, length(means) - 1)

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

par(mar=c(5, 5, 1, 3))
plot(0, type="n", ylim=ybnds, xlim=xbnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("Mean RTT (",mu,"s)", sep="")), main="")

grid()

# Native Mean
abline(means[[1]], 0, col="black", lty=2)
mtext(" Native", 4, at=means[[1]], las=2)

# Plot Means
lines(seq(0,length(means)-2), means[-1], type="p", ylim=ybnds, col="black", pch=20)


# Add x-axis
axis(1, at=x_label_at, labels=n_containers, las=2)

dev.off()

#
# Draw modes line-graph
#
pdf(file=paste(data_path, "/modes.pdf", sep=""), width=6.5, height=5)

par(mar=c(5, 5, 1, 3))
plot(0, type="n", ylim=ybnds, xlim=xbnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("RTT mode (",mu,"s)", sep="")), main="")

grid()

# Native Mode
abline(modes[[1]], 0, col="black", lty=2)
mtext(" Native", 4, at=modes[[1]], las=2)

# Plot Modes
lines(seq(0,length(modes)-2), modes[-1], type="p", ylim=ybnds, col="black", pch=20)


# Add x-axis
axis(1, at=x_label_at, labels=n_containers, las=2)

dev.off()



#
# Draw heatmap
#
pdf(file=paste(data_path, "/cdf_map.pdf", sep=""), width=6.5, height=5)

# image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")
image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=c(0,500), xaxt="n", xlab="Number of extra containers", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")

grid()
axis(1, at=seq(0, length(n_containers) - 1), labels=n_containers, las=2)


dev.off()
