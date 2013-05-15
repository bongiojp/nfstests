#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/errno.h>

int main(int argc, char **argv) {
  char *filetolock,*type,*block,*sleepstr;
  int start,length,rc,fd,cmd,loop=0;
  struct flock fl;

  if (argc < 7) {
    printf("Not enough arguments to %s\n", argv[0]);
    printf("Usage: %s filename [SHARED|EXCLUSIVE] [NOBLOCK|BLOCK] start_byte length [SLEEP|NOSLEEP]\n", argv[0]);
    exit(1);
  }

  filetolock = argv[1];
  type = argv[2];
  block = argv[3];
  start = atoi(argv[4]);
  length = atoi(argv[5]);
  sleepstr = argv[6];

  if (strncmp(sleepstr, "SLEEP", 5) == 0)
    loop = 1;

  printf("opening %s\n", filetolock);
  fd = open(filetolock, O_RDWR);
  if (errno) {
    fprintf(stderr, "ERROR: Could not open the file prior to locking.\n");
    exit(1);
  }

  if (strncmp(type, "SHARED", 6) == 0)
    fl.l_type = F_RDLCK;
  else if (strncmp(type, "EXCLUSIVE", 9) == 0)
    fl.l_type = F_WRLCK;
  else {
    fprintf(stderr, "ERROR: Invalid second argument ... should be either SHARED or EXCLUSIVE.\n");
    exit(1);
  }
  fl.l_whence = SEEK_SET;
  fl.l_start = start;
  fl.l_len = length;
  cmd = F_SETLK;

  rc = fcntl(fd, cmd,  &fl);
  if (errno == EACCES || errno == EAGAIN) {
    fprintf(stderr, "ERROR: Already locked by another process\n");
    exit(1);
  }
  if (rc) {
    fprintf(stderr, "ERROR: Could not acquire lock.\n");
    exit(1);
  }

  if (loop)
    printf("Entering infinite loop after successfully obtaining lock.\n");    
  else
    printf("Successfully obtained lock, now exiting.\n");

  while(loop) {
    /* Now the caller has to KILL this process to end the lock. */
    sleep(5);
  }

  return 0;
}




