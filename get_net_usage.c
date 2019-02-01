//
// Simple program to report the network usage from /proc/net/dev
//

#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <ctype.h>
#include <string.h>
#include <sys/time.h>
#include <stdlib.h>

#define MAX_DEV_FILE_SIZE 1024

struct net_dev_counters {
  uint64_t rx_bytes;
  uint64_t rx_packets;
  uint64_t tx_bytes;
  uint64_t tx_packets;
};

static int running = 1;

void
usage(const char *name)
{
  printf("Usage: %s <device> [-t <interval>] [-X <timeout>]\n", name);
  printf("  Outputs statistics from /proc/net/dev every <interval> seconds.\n");
  printf("  If <interval> is not given, defaults to 2.\n");
  printf("  If no traffic is seen for <timeout> seconds, exits.\n");
  printf("  The default <timeout> value is 120.\n");
}

//
// Fills in the given counters struct by reading from the provided filepath
//
int
read_proc_net_dev(struct net_dev_counters *counters, const char *filepath, const char *dev_name)
{
  char buf[MAX_DEV_FILE_SIZE];
  char *buf_ptr;
  const char *buf_end = buf + MAX_DEV_FILE_SIZE;
  const int dev_name_len = strlen(dev_name);
  int fd;
  ssize_t len;

  fd = open(filepath, O_RDONLY);
  if (fd < 0) {
    fprintf(stderr, "Failed to open %s\n", filepath);
    return -1;
  }

  // Read the whole file
  if ((len = read(fd, buf, MAX_DEV_FILE_SIZE)) <= 0) {
    fprintf(stderr, "Failed to read from proc file\n");
    close(fd);
    return -1;
  }

  close(fd);

  // Skip first two lines
  buf_ptr = buf;
  while (*buf_ptr != '\n') {
    buf_ptr++;
    if (buf_ptr == buf_end) {
      goto format_err_out;
    }
  }
  buf_ptr++;
  while (*buf_ptr != '\n' && buf_ptr != buf_end) {
    buf_ptr++;
    if (buf_ptr == buf_end) {
      goto format_err_out;
    }
  }

  // Go through each interface
  while (buf_ptr != buf_end) {

    // Skip alignment space
    while (isspace(*buf_ptr)) {
      buf_ptr++;
      if (buf_ptr == buf_end) {
        goto format_err_out;
      }
    }

    // If this is the target device, parse the line and return, otherwise go on
    if (!strncmp(buf_ptr, dev_name, dev_name_len)) {
      if (sscanf(buf_ptr, "%*s %ld %ld %*d %*d %*d %*d %*d %*d %ld %ld", 
            &counters->rx_bytes,
            &counters->rx_packets,
            &counters->tx_bytes,
            &counters->tx_packets) == 4) {
        return 0;
      } else {
        goto format_err_out;
      }

    } else {
      while (*buf_ptr != '\n' && buf_ptr != buf_end) {
        buf_ptr++;
        if (buf_ptr == buf_end) {
          goto format_err_out;
        }
      }
    }
  }

  // Device not found
  return 1;

format_err_out:

  fprintf(stderr, "Proc file is not formated as expected\n");
  return -1;
}

//
// timeval subtraction
// returns the difference in seconds as a double
//
double
tv_diff(struct timeval *t1, struct timeval *t2)
{
  double res = 0;
  res = t1->tv_usec - t2->tv_usec;
  res /= 1000000;
  res += t1->tv_sec - t2->tv_sec;
  return res;
}

int
main(int argc, char *argv[])
{
  char *proc_net_dev_filepath = "/proc/net/dev";
  char *dev_name;
  struct net_dev_counters old_counters;
  struct net_dev_counters new_counters;
  double rx_bits_per_sec;
  double rx_packets_per_sec;
  double tx_bits_per_sec;
  double tx_packets_per_sec;
  struct timeval old_ts;
  struct timeval new_ts;
  double dt;
  int res;
  int i;

  int interval_sec = 2;
  int timeout_sec = 120;

  // Parse arguments
  if (argc < 2) {
    usage(argv[0]);
    return 0;
  }
  dev_name = argv[1];
  for (i = 2; i + 1 < argc && argv[i][0] == '-'; i++) {
    switch (argv[i][1]) {
      case 't':
        interval_sec = atoi(argv[i+1]);
        i++;
        break;
      case 'X':
        timeout_sec = atoi(argv[i+1]);
        i++;
        break;
      default:
        usage(argv[0]);
        return 0;
    }
  }

  printf("Running with interval: %d, timeout: %d\n",
      interval_sec,
      timeout_sec); 

  // Main loop
  while (running) {

    // Get a dumb timestamp and print
    gettimeofday(&new_ts, NULL);

    // Read proc net dev file
    res = read_proc_net_dev(&new_counters, proc_net_dev_filepath, dev_name);
    if (res == 1) {
      printf("Failed to find device named %s\n", dev_name);
    } else if (res == -1) {
      printf("Failed to read from proc file\n");
    }

    // Compute rates
    dt = tv_diff(&new_ts, &old_ts);
    rx_bits_per_sec = (double)((new_counters.rx_bytes - old_counters.rx_bytes) * 8) / dt;
    rx_packets_per_sec = (double)(new_counters.rx_packets - old_counters.rx_packets) / dt;
    tx_bits_per_sec = (double)((new_counters.tx_bytes - old_counters.tx_bytes) * 8) / dt;
    tx_packets_per_sec = (double)(new_counters.tx_packets - old_counters.tx_packets) / dt;


    printf("[%ld.%06ld] rx_bps: %f rx_pps: %f tx_bps: %f tx_pps: %f\n",
        new_ts.tv_sec,
        new_ts.tv_usec,
        rx_bits_per_sec,
        rx_packets_per_sec,
        tx_bits_per_sec,
        tx_packets_per_sec);
  
    // Save current state
    old_counters = new_counters;
    old_ts = new_ts;
    
    // Rest a bit
    sleep(interval_sec);
  }

  return 0;
}
