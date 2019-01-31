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

#define MAX_DEV_FILE_SIZE 1024

struct net_dev_counters {
  uint64_t bytes;
  uint64_t packets;
};

static int running = 1;

void
usage(const char *name)
{
  printf("Usage: %s <device>\n", name);
  printf("  outputs statistics from /proc/net/dev\n");
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
      if (sscanf(buf_ptr, "%*s %ld %ld", 
            &counters->bytes,
            &counters->packets) == 2) {
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

int
main(int argc, char *argv[])
{
  char *proc_net_dev_filepath = "/proc/net/dev";
  char *dev_name;
  struct net_dev_counters old_counters;
  struct net_dev_counters new_counters;
  double bytes_per_sec;
  double packets_per_sec;
  
  int res;

  if (argc != 2) {
    usage(argv[0]);
    return 0;
  }
  dev_name = argv[1];

  // Main loop
  while (running) {

    // Read proc net dev file
    res = read_proc_net_dev(&new_counters, proc_net_dev_filepath, dev_name);
    if (res == 1) {
      printf("Failed to find device named %s\n", dev_name);
    } else if (res == -1) {
      printf("Failed to read from proc file\n");
    }

    // Compute rates
    bytes_per_sec = (double)new_counters.bytes - (double)old_counters.bytes;
    packets_per_sec = (double)new_counters.packets - (double)old_counters.packets;
    printf("%f bytes per second; %f packets per second;\n", bytes_per_sec, packets_per_sec);
  
    // Save current counter state
    old_counters = new_counters;
    
    // Rest a bit
    sleep(1);
  }

  return 0;
}
