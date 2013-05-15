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
  char *filetolock,*type,*filename;
  int start,length,rc,fd,cmd;
  struct flock fl;
  char *strng = "aaaaaaaaaabbbbbbbbbbbbbccccccccccccddddddddeeeeeeeeee11111111111";
  int strng_len = sizeof(strng);
  char buf[strng_len+1];
  char comm[50];

  filename = argv[1];

  fd = open(filename, O_CREAT|O_RDWR);
  if (!fd) {
    fprintf(stderr, "ERROR: Could not open the file prior to locking.\n");
    exit(1);
  }

  fl.l_type = F_WRLCK;
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
    fprintf(stderr, "ERROR: Could not acquire lock to start.\n");
    exit(1);
  }

  write(fd, strng, strng_len);

  sprintf(comm, "rm %s", filename);
  rc = system(comm);

  sleep(10);

  rc = lseek(fd, 0, SEEK_SET);

  rc = read(fd, buf, strng_len);

  if (strncmp(strng, buf, strng_len) == 0)
    printf("SUCCESS: File content for process holding lock still available after file deletion.\n");
  else {
    printf("FAIL: File content for process holding lock not available after file deletion.\n");
    return 1;
  }

  close(fd);

  ///////////////////////////////////////////////////////////////

  fd = open(filename, O_CREAT|O_RDWR);
  if (!fd) {
    fprintf(stderr, "ERROR: Could not open the file prior to locking.\n");
    exit(1);
  }

  fl.l_type = F_RDLCK;
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
    fprintf(stderr, "ERROR: Could not acquire lock for second test.\n");
    exit(1);
  }

  write(fd, strng, strng_len);

  sprintf(comm, "rm %s", filename);
  rc = system(comm);

  sleep(10);

  rc = lseek(fd, 0, SEEK_SET);

  rc = read(fd, buf, strng_len);

  if (strncmp(strng, buf, strng_len) == 0)
    printf("SUCCESS: File content for process holding lock still available after file deletion.\n");
  else {
    printf("FAIL: File content for process holding lock not available after file deletion.\n");
    return 1;
  }

  close(fd);

  return 0;
}
