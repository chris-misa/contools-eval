args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

SANDBOX_IFACE <- "eth0"
DOCKER_IFACE <- "docker0"
HOST_IFACE <- "eno1d1"

parseTraceLine <- function(line) {
  linePattern <- ".+ \\[([0-9]+)\\] ([0-9\\.]+): ([a-z_]+): +dev=([a-z0-9]+) .*skbaddr=([x0-9a-f]+) .*"
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
  linePattern <- ".+ \\[([0-9]+)\\] ([0-9\\.]+): sys_enter_sendto: .*"
  matches <- grep(linePattern, str, value=T)
  if (length(matches) != 0) {
    cpu <- as.numeric(sub(linePattern, "\\1", matches))
    ts <- as.numeric(sub(linePattern, "\\2", matches))
    list(cpu=cpu, ts=ts, even="sys_enter_sendto", dev=NULL, skbaddr=NULL)
  } else {
    NULL
  }
}

readNetTrace <- function(filePath) {
  con <- file(filePath, "r")
  file <- readLines(con, n=-1)
  close(con)
  nlines <- length(file)
  flows <- new.env()
  i <- 1
  while (i <= nlines) {
    l <- parseTraceLine(file[[i]])
    if (!is.null(l)) {

      k <- l[["skbaddr"]]

      # Backtrack to got send to
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

sendStateMachine <- function(flow) {
  state <- 0
  prevTime <- 0

  sandboxTimes <- c()
  routingTimes <- c()

  for (f in flow) {
    if (state == 0
        && f[["event"]] == "net_dev_queue"
        && f[["dev"]] == SANDBOX_IFACE) {
      prevTime <- f[["ts"]]
      state <- 1
    } else if (state == 1
        && f[["event"]] == "netif_receive_skb"
        && f[["dev"]] == DOCKER_IFACE) {
      sandboxTimes <- c(sandboxTimes, (f[["ts"]] - prevTime) * 1000000)
      prevTime <- f[["ts"]]
      state <- 2
    } else if (state == 2
       && f[["event"]] == "net_dev_queue"
       && f[["dev"]] == HOST_IFACE) {
      routingTimes <- c(routingTimes, (f[["ts"]] - prevTime) * 1000000)
      state <- 0
    }
  }

  # Handle edge case where trace ends in the middle of a cycle
  # by removing the last element
  if (state == 2) {
    sandboxTimes <- sandboxTimes[-length(sandboxTimes)]
  }

  data.frame(sandboxTimes=sandboxTimes, routingTimes=routingTimes)
}

recvStateMachine <- function(flow) {
  state <- 0
  prevTime <- 0

  sandboxTimes <- c()
  routingTimes <- c()

  for (f in flow) {
    if (state == 0
        && f[["event"]] == "napi_gro_frags_entry"
        && f[["dev"]] == HOST_IFACE) {
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
      state <- 0
    }
  }

  # Handle edge case where trace ends in the middle of a cycle
  # by removing the last element
  if (state == 2) {
    routingTimes <- routingTimes[-length(routingTimes)]
  }

  data.frame(sandboxTimes=sandboxTimes, routingTimes=routingTimes)
}


#
# Main work starts here
#


con <- file(paste(data_path, "/manifest", sep=""), "r")
while (T) {
  line <- readLines(con, n=1)
  if (length(line) == 0) {
    break
  }

  sends <- data.frame()
  recvs <- data.frame()

  flows <- readNetTrace(paste(data_path, "/", line, sep=""))
  dumpFlows(flows)
  stop("done")


  for (f in ls(flows)) {
    sends <- rbind(sends, sendStateMachine(flows[[f]]))
    recvs <- rbind(recvs, recvStateMachine(flows[[f]]))
  }

  sendSandboxMean <- mean(sends$sandboxTimes)
  sendRoutingMean <- mean(sends$routingTimes)
  recvSandboxMean <- mean(recvs$sandboxTimes)
  recvRoutingMean <- mean(recvs$routingTimes)

  cat("Saw ", nrow(sends), " sends and ", nrow(recvs), "recvs\n")
  cat("Send means: sandbox: ", sendSandboxMean, " routing: ", sendRoutingMean, "\n")
  cat("Recv means: sandbox: ", recvSandboxMean, " routing: ", recvRoutingMean, "\n")
}
