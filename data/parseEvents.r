containerNames <- seq(1,16,1)

args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

SANDBOX_IFACE <- "eth0"
DOCKER_IFACE <- "docker0"
HOST_IFACE <- "eno1d1"

#
# Work around to draw intervals around
# points in graph
#
drawArrows <- function(xs, ys, sds, color) {
  arrows(xs, ys - sds,
         xs, ys + sds,
         length=0.01, angle=90, code=3, col=color)
}

#
# Compute confidence intervals
#

confidence <- 0.90
getConfidence <- function(data) {
  a <- confidence + 0.5 * (1.0 - confidence)
  n <- length(data)
  t_an <- qt(a, df=n-1)
  t_an * sd(data) / sqrt(length(data))
}

parseTraceLine <- function(line) {
  linePattern <- ".+ \\[([0-9]+)\\] +([0-9\\.]+): +([a-z_]+): +dev=([a-z0-9]+) .*skbaddr=([x0-9a-f]+) .*"
  matches <- grep(linePattern, line, value=T)
  if (length(matches) != 0) {
    cpu <- as.numeric(sub(linePattern, "\\1", matches))
    ts <- as.numeric(sub(linePattern, "\\2", matches))
    event <- sub(linePattern, "\\3", matches)
    dev <- sub(linePattern, "\\4", matches)
    skbaddr <- sub(linePattern, "\\5", matches)
    list(cpu=cpu, ts=ts, event=event, dev=dev, skbaddr=skbaddr)
  } else {
    NULL
  }
}

getSendto <- function(str) {
  linePattern <- ".+ \\[([0-9]+)\\] +([0-9\\.]+): +sys_enter_sendto: .*"
  matches <- grep(linePattern, str, value=T)
  if (length(matches) != 0) {
    cpu <- as.numeric(sub(linePattern, "\\1", matches))
    ts <- as.numeric(sub(linePattern, "\\2", matches))
    list(cpu=cpu, ts=ts, event="sys_enter_sendto", dev="", skbaddr="")
  } else {
    NULL
  }
}

getRecvmsg <- function(str) {
  linePattern <- ".+ \\[([0-9]+)\\] +([0-9\\.]+): +sys_exit_recvmsg: .*"
  matches <- grep(linePattern, str, value=T)
  if (length(matches) != 0) {
    cpu <- as.numeric(sub(linePattern, "\\1", matches))
    ts <- as.numeric(sub(linePattern, "\\2", matches))
    list(cpu=cpu, ts=ts, event="sys_exit_recvmsg", dev="", skbaddr="")
  } else {
    NULL
  }
}

readNetTrace <- function(filePath) {
  con <- file(filePath, "r")
  file <- readLines(con, n=-1)
  close(con)
  nlines <- length(file)
  recvmsgUsed <- rep(F, nlines) # for keeping track of which sys_exit_recvmsg event's we've used so far
  flows <- new.env()
  i <- 1
  while (i <= nlines) {
    l <- parseTraceLine(file[[i]])
    if (!is.null(l)) {

      k <- l[["skbaddr"]]

      # Backtrack to get sendto
      if (l[["event"]] == "net_dev_queue" && l[["dev"]] == SANDBOX_IFACE) {
        targetCPU <- l[["cpu"]]
        j <- i - 1
        while (j > 0) {
          maybeSendto <- getSendto(file[[j]])
          if (!is.null(maybeSendto) && maybeSendto[["cpu"]] == targetCPU) {
            flows[[k]][[length(flows[[k]])+1]] <- maybeSendto
            break
          }
          j <- j - 1
        }
      }

      flows[[k]][[length(flows[[k]])+1]] <- l

      # Forwardtrack to get recvmsg
      #
      # This stalls because processes may restart on a new CPU!
      # Idea: look for next unmarked temporal sys_exit_recvmsg, use and mark it
      #
      if (l[["event"]] == "netif_receive_skb" && l[["dev"]] == SANDBOX_IFACE) {
        j <- i + 1
        while (j <= nlines) {
          maybeRecv <- getRecvmsg(file[[j]])
          if (!recvmsgUsed[[j]] && !is.null(maybeRecv)) {
            flows[[k]][[length(flows[[k]])+1]] <- maybeRecv
            recvmsgUsed[[j]] <- T
            break
          }
          j <- j + 1
        }
      }
    }
    i <- i + 1
  }
  flows
}

dumpFlows <- function(flows) {
  for (f in ls(flows)) {
    cat("New skbaddr: ", f, "\n")
    for (l in flows[[f]]) {
      print(l)
    }
  }
}

dumpFlowsToFile <- function(flows, filePath) {
  con <- file(filePath, "wt")
  sink(con)
  for (f in ls(flows)) {
    cat("New skbaddr: ", f, "\n")
    for (l in flows[[f]]) {
      cat(sprintf("%.9f: %s: dev=%s skbaddr=%s\n",l[["ts"]], l[["event"]], l[["dev"]], l[["skbaddr"]]))
    }
  }
  sink()
  close(con)
}

sendStateMachine <- function(flow) {
  state <- 0
  prevTime <- 0

  syscallTimes <- c()
  sandboxTimes <- c()
  routingTimes <- c()

  for (f in flow) {
    # if (state == 0
    #     && f[["event"]] == "sys_enter_sendto") {
    if (f[["event"]] == "sys_enter_sendto") {
    
      # Handle edge case where trace ends in the middle of a cycle
      # by removing the last elements
      if (state >= 2) {
        syscallTimes <- syscallTimes[-length(syscallTimes)]
      }
      if (state == 3) {
        sandboxTimes <- sandboxTimes[-length(sandboxTimes)]
      }

      prevTime <- f[["ts"]]
      state <- 1
    } else if (state == 1
        && f[["event"]] == "net_dev_queue"
        && f[["dev"]] == SANDBOX_IFACE) {
      syscallTimes <- c(syscallTimes, (f[["ts"]] - prevTime) * 1000000)
      prevTime <- f[["ts"]]
      state <- 2
    } else if (state == 2
        && f[["event"]] == "netif_receive_skb"
        && f[["dev"]] == DOCKER_IFACE) {
      sandboxTimes <- c(sandboxTimes, (f[["ts"]] - prevTime) * 1000000)
      prevTime <- f[["ts"]]
      state <- 3
    } else if (state == 3
       && f[["event"]] == "net_dev_queue"
       && f[["dev"]] == HOST_IFACE) {
      routingTimes <- c(routingTimes, (f[["ts"]] - prevTime) * 1000000)
      state <- 0
    }
  }

  # Handle edge case where trace ends in the middle of a cycle
  # by removing the last elements
  if (state >= 2) {
    syscallTimes <- syscallTimes[-length(syscallTimes)]
  }
  if (state == 3) {
    sandboxTimes <- sandboxTimes[-length(sandboxTimes)]
  }

  data.frame(syscallTimes=syscallTimes, sandboxTimes=sandboxTimes, routingTimes=routingTimes)
}

recvStateMachine <- function(flow) {
  state <- 0
  prevTime <- 0

  routingTimes <- c()
  sandboxTimes <- c()
  syscallTimes <- c()

  for (f in flow) {
    #if (state == 0
    if (f[["event"]] == "napi_gro_frags_entry"
        && f[["dev"]] == HOST_IFACE) {

      # Handle edge case where trace ends in the middle of a cycle
      # by removing the last element
      if (state >= 2) {
        routingTimes <- routingTimes[-length(routingTimes)]
      }
      if (state == 3) {
        sandboxTimes <- sandboxTimes[-length(sandboxTimes)]
      }

      prevTime <- f[["ts"]]
      state <- 1
    } else if (state == 1
        && f[["event"]] == "net_dev_start_xmit"
        && f[["dev"]] == DOCKER_IFACE) {
      routingTimes <- c(routingTimes, (f[["ts"]] - prevTime) * 1000000)
      prevTime <- f[["ts"]]
      state <- 2
    } else if (state == 2
       && f[["event"]] == "netif_receive_skb"
       && f[["dev"]] == SANDBOX_IFACE) {
      sandboxTimes <- c(sandboxTimes, (f[["ts"]] - prevTime) * 1000000)
      prevTime <- f[["ts"]]
      state <- 3
    } else if (state == 3
       && f[["event"]] == "sys_exit_recvmsg") {
      syscallTimes <- c(syscallTimes, (f[["ts"]] - prevTime) * 1000000)
      state <- 0
    }
  }

  # Handle edge case where trace ends in the middle of a cycle
  # by removing the last element
  if (state >= 2) {
    routingTimes <- routingTimes[-length(routingTimes)]
  }
  if (state == 3) {
    sandboxTimes <- sandboxTimes[-length(sandboxTimes)]
  }

  data.frame(syscallTimes=syscallTimes, sandboxTimes=sandboxTimes, routingTimes=routingTimes)
}


#
# Main work starts here
#

SAVED_DATA_PATH <- paste(data_path, "/saved_r_data", sep="")
if (file.exists(SAVED_DATA_PATH)) {

  data <- dget(SAVED_DATA_PATH)

  sendData <- data$savedSendData
  recvData <- data$savedRecvData

  sendDataError <- data$savedSendDataError
  recvDataError <- data$savedRecvDataError

  cat("Read saved data\n");
} else {

  sendData <- matrix(,nrow=3,ncol=0)
  recvData <- matrix(,nrow=3,ncol=0)

  sendDataError <- matrix(,nrow=3,ncol=0)
  recvDataError <- matrix(,nrow=3,ncol=0)

  con <- file(paste(data_path, "/manifest", sep=""), "r")
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }

    cat("File: ", line, ":\n")

    sends <- data.frame()
    recvs <- data.frame()

    flows <- readNetTrace(paste(data_path, "/", line, sep=""))

    dumpFlowsToFile(flows, paste(data_path, "flows", line, sep=""))

    for (f in ls(flows)) {
      sends <- rbind(sends, sendStateMachine(flows[[f]]))
      recvs <- rbind(recvs, recvStateMachine(flows[[f]]))
    }

    sendSyscallMean <- mean(sends$syscallTimes)
    sendSandboxMean <- mean(sends$sandboxTimes)
    sendRoutingMean <- mean(sends$routingTimes)
    recvSyscallMean <- mean(recvs$syscallTimes)
    recvSandboxMean <- mean(recvs$sandboxTimes)
    recvRoutingMean <- mean(recvs$routingTimes)

    sendSyscallError <- getConfidence(sends$syscallTimes)
    sendSandboxError <- getConfidence(sends$sandboxTimes)
    sendRoutingError <- getConfidence(sends$routingTimes)
    recvSyscallError <- getConfidence(recvs$syscallTimes)
    recvSandboxError <- getConfidence(recvs$sandboxTimes)
    recvRoutingError <- getConfidence(recvs$routingTimes)

    sendData <- cbind(sendData, c(sendSyscallMean, sendSandboxMean, sendRoutingMean))
    recvData <- cbind(recvData, c(recvSyscallMean, recvSandboxMean, recvRoutingMean))

    sendDataError <- cbind(sendDataError, c(sendSyscallError, sendSandboxError, sendRoutingError))
    recvDataError <- cbind(recvDataError, c(recvSyscallError, recvSandboxError, recvRoutingError))

    cat("Saw ", nrow(sends), " sends and ", nrow(recvs), "recvs\n")
    cat("Send means: syscalls: ", sendSyscallMean, " sandbox: ", sendSandboxMean, " routing: ", sendRoutingMean, "\n")
    cat("Recv means: syscalls: ", recvSyscallMean, " sandbox: ", recvSandboxMean, " routing: ", recvRoutingMean, "\n")
  }

  dput(list(savedSendData=sendData,
            savedRecvData=recvData,
            savedSendDataError=sendDataError,
            savedRecvDataError=recvDataError), file=SAVED_DATA_PATH)
  cat("Saved parseing results for next time.\n")
}

print(sendDataError)
print(recvDataError)


pdf(file=paste(data_path, "/sendMeans.pdf", sep=""), width=6.5, height=5)
barCenters <- barplot(sendData, beside=T,
    ylab=expression(paste("Time (",mu,"s)", sep="")),
    xlab="Number of containers",
    names.arg=containerNames,
    legend=c("syscall", "sandbox", "routing"),
    col=c("#bd0000", "#2e97ff", "#99ff99"),
    ylim=c(0,max(as.vector(sendData) + as.vector(sendDataError))),
    args.legend=list(x="topleft"))

drawArrows(barCenters, as.vector(sendData), as.vector(sendDataError), "black")

dev.off()


pdf(file=paste(data_path, "/recvMeans.pdf", sep=""), width=6.5, height=5)
barCenters <- barplot(recvData, beside=T,
    ylab=expression(paste("Time (",mu,"s)", sep="")),
    xlab="Number of containers",
    names.arg=containerNames,
    legend=c("syscall", "sandbox", "routing"),
    col=c("#bd0000", "#2e97ff", "#99ff99"),
    ylim=c(0,max(as.vector(recvData) + as.vector(recvDataError))),
    args.legend=list(x="topleft"))

drawArrows(barCenters, as.vector(recvData), as.vector(recvDataError), "black")

dev.off()
