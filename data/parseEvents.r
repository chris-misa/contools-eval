args <- commandArgs(trailingOnly=T)
usage <- "rscript genreport.r <path to data folder>"
if (length(args) != 1) {
  stop(usage)
}

data_path <- args[1]

SANDBOX_IFACE <- "eth0"
DOCKER_IFACE <- "docker0"
HOST_IFACE <- "eno1d1"


readNetTrace <- function(filePath) {
  con <- file(filePath, "r")
  flows <- new.env()
  linePattern <- ".* skbaddr=([x0-9a-f]+) .*"
  while (T) {
    line <- readLines(con, n=1)
    if (length(line) == 0) {
      break
    }
    matches <- grep(linePattern, line, value=T)

    if (length(matches)) {
      k <- sub(linePattern, "\\1", matches)
      flows[[k]] <- c(flows[[k]], line)
    }
  }
  close(con)
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

parseTraceLine <- function(line) {
  linePattern <- ".+ \\[[0-9]+\\] ([0-9\\.]+): ([a-z_]+): +dev=([a-z0-9]+) .*"
  matches <- grep(linePattern, line, value=T)
  ts <- as.numeric(sub(linePattern, "\\1", matches))
  event <- sub(linePattern, "\\2", matches)
  dev <- sub(linePattern, "\\3", matches)
  list(ts=ts, event=event, dev=dev)
}

sendStateMachine <- function(flow) {
  state <- 0
  prevTime <- 0

  sandboxTimes <- c()
  routingTimes <- c()

  for (line in flow) {
    f <- parseTraceLine(line)
    if (state == 0
        && f[["event"]] == "net_dev_queue"
        && f[["dev"]] == SANDBOX_IFACE) {
      prevTime <- f[["ts"]]
      state <- 1
    } else if (state == 1
        && f[["event"]] == "netif_receive_skb"
        && f[["dev"]] == DOCKER_IFACE) {
      sandboxTimes <- c(sandboxTimes, f[["ts"]] - prevTime)
      prevTime <- f[["ts"]]
      state <- 2
    } else if (state == 2
       && f[["event"]] == "net_dev_queue"
       && f[["dev"]] == HOST_IFACE) {
      routingTimes <- c(routingTimes, f[["ts"]] - prevTime)
      state <- 0
    }
  }

  data.frame(sandboxTimes=sandboxTimes, routingTimes=routingTimes)
}

recvStateMachine <- function(flow) {
}

flows <- readNetTrace(data_path)
for (f in ls(flows)) {
  print(sendStateMachine(flows[[f]]))
}

dumpFlows(flows)
