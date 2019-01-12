
args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]
target <- "10.10.1.2"

#n_containers <- c(0, 1, 2, 3, 5, 7, 11, 17, 25, 38, 57, 86, 129, 291, 437, 656, 985)

# n_containers <- c("native", seq(from=0, to=500, by=10))
n_containers <- c("native", seq(0, 100, 1))
# n_containers <- c("Native", "Local", "Same", "Different")


#
# Read trace-cmd report file
#
readTraceCmdFile <- function(filePath) {
  con <- file(filePath, "r")
  times <- c()
  linePattern <- " *ping-[0-9]+ +\\[[0-9]+\\] +([0-9\\.]+): +(sys_enter_sendto|sys_exit_sendto): .*"
  inSend <- F
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

      if (ev == "sys_exit_sendto" && inSend) {
        times <- c(times, (ts - prevTs) * 1000000)
        inSend <- F
      } else if (ev == "sys_enter_sendto") {
        prevTs <- ts
        inSend <- T
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

ybnds <- c(0, max(means + sds))

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
image(seq(0,length(means)-1), seq(ybnds[[1]],ybnds[[2]],0.1), t(num_ecdfs), ylim=ybnds, xaxt="n", xlab="Number of extra containers", ylab=expression(paste("sendto syscall time (",mu,"s)", sep="")), main="")

grid()
axis(1, at=seq(0, length(n_containers) - 1), labels=n_containers, las=2)


dev.off()

