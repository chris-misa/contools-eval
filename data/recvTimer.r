
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

#n_containers <- c(0, 1, 2, 3, 5, 7, 11, 17, 25, 38, 57, 86, 129, 291, 437, 656, 985)

# n_containers <- c("native", seq(from=0, to=500, by=10))
n_containers <- seq(0, 10, 1)
x_label_at <- seq(0,10,1)
# n_containers <- c("Native", "Local", "Same", "Different")


#
# Read trace-cmd report file
#
readTraceCmdFile <- function(filePath) {
  con <- file(filePath, "r")
  times <- c()
  linePattern <- " *ping-[0-9]+ +\\[[0-9]+\\] +([0-9\\.]+): +(sys_enter_recvmsg|sys_exit_recvmsg): .*"
  inRecv <- F
  prevTs <- 0

  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }
    matches <- grep(linePattern, line, value=T)

    if (length(matches) != 0) {
      ts <- as.numeric(sub(linePattern, "\\1", matches))
      ev <- sub(linePattern, "\\2", matches)

      if (ev == "sys_exit_recvmsg" && inRecv) {
        times <- c(times, (ts - prevTs) * 1000000)
        inRecv <- F
      } else if (ev == "sys_enter_recvmsg") {
        prevTs <- ts
        inRecv <- T
      }
    }
  }
  close(con)
  times
}


#
# Main work
#

means <- c()
sds <- c()
ecdfs <- c()

con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  times <- readTraceCmdFile(paste(data_path, "/", line, sep=""))

  cat("File:", line, "\n")
  cat("  mean:", mean(times), "(us)\n")

  means <- c(means, mean(times))
  sds <- c(sds, sd(times))
  ecdfs <- c(ecdfs, ecdf(times))
}
close(con)

# ybnds <- c(0, max(means + sds))
ybnds <- c(0, max(means))

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

# image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="", ylab=expression(paste("RTT (",mu,"s)", sep="")), main="")
image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="Number of extra containers", ylab=expression(paste("recvmsg syscall time (",mu,"s)", sep="")), main="")

grid()
axis(1, at=seq(0, length(n_containers)), labels=c("native", n_containers), las=2)


dev.off()

#
# Draw means
#
xbnds <- c(0, length(means) - 1)

pdf(file=paste(data_path, "/means.pdf", sep=""), width=10, height=5)

par(mar=c(5, 5, 1, 3))
plot(0, type="n", ylim=ybnds, xlim=xbnds, xaxt="n", xlab="Number of containers", ylab=expression(paste("Mean time (",mu,"s)", sep="")), main="")

grid()

# Native Min
# abline(mins[[1]], 0, col="gray")

# Plot Mins
# lines(seq(0,length(mins)-2), mins[-1], type="p", ylim=ybnds, col="gray", pch=20)

# Native Mean
abline(means[[1]], 0, col="black", lty=2)
mtext(" Native", 4, at=means[[1]], las=2)

# Plot Means
lines(seq(0,length(means)-2), means[-1], type="p", ylim=ybnds, col="black", pch=20)


# Add x-axis
axis(1, at=x_label_at, labels=n_containers, las=2)

dev.off()

