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
#include <sys/ipc.h>
#include <semaphore.h>
#include <sys/wait.h>
#include <sys/shm.h>

#define OPENCLOSELOOP 20
#define NUMFILESTOTEST 40

char *global_filetolock;

void inquisitive_exit();
int mylock(int fd, int cmd, char *type, int start, int end);
void testlock(int fd, char *type, int start, int end, int pid);
void testlock2(int fd, char *type, int start, int end);
void lock1(int fd, char *filetolock, char *type, int start, int end);
void unlock2(int fd, char *filetolock, int start, int end, int prevstart, int prevend);
void unlock1(int fd, char *filetolock, int start, int end);

void inquisitive_exit() {
  int conflict_pid, j, fd;
  char *currfile;
  currfile = calloc(0, (strlen(global_filetolock)+50)*sizeof(char));
  char *type = "EXCLUSIVE";
  int start = 0;
  int end = 0;

  printf("\n----------------------------\n"
	 "INQUISITIVE FAILURE\n"
	 "----------------------------\n\n");
  
  for(j=0; j < NUMFILESTOTEST; j++) {
    sprintf(currfile, "%s.%d", global_filetolock, j);
    fd = open(currfile, O_RDWR);
    if (errno) {
      printf("FAIL: Could not open the file %s prior to locking.\n", currfile);
      perror("error:");
      continue;
    }
    
    conflict_pid = mylock(fd, F_GETLK, type, start, end);
    
    if (conflict_pid != 0)
      printf("LOCKED(pid=%d):%s\n", conflict_pid, currfile);
    else
      printf("UNLOCKED:%s\n", currfile);

    close(fd);
  }

  kill(0, SIGTERM);
  exit(1);
}

int mylock(int fd, int cmd, char *type, int start, int end) {
  struct flock fl;
  int rc;
  if (strncmp(type, "SHARED", 6) == 0)
    fl.l_type = F_RDLCK;
  else if (strncmp(type, "EXCLUSIVE", 9) == 0)
    fl.l_type = F_WRLCK;
  else if (strncmp(type, "UNLOCK", 9) == 0)
    fl.l_type = F_UNLCK;
  else {
    fprintf(stderr, "FAIL: Invalid second argument ... should be either SHARED or EXCLUSIVE.\n");
    kill(0, SIGTERM);
    exit(1);
  }
  
  fl.l_whence = SEEK_SET;
  fl.l_start = start;
  fl.l_len = end - start;

  rc = fcntl(fd, cmd,  &fl);
  if (errno == EACCES || errno == EAGAIN) {
    fprintf(stderr, "FAIL: Already locked by another process\n");
    perror("error:");
    inquisitive_exit();
  }
  if (errno)
    perror("error:");
  if (rc) {
    fprintf(stderr, "FAIL: Could not acquire lock.\n");
    inquisitive_exit();
  }

  if (cmd == F_GETLK) {
    if (fl.l_type == F_UNLCK)
      return 0; /* No conflicting lock */
    else
      return fl.l_pid;
  }
  else
    return rc;
}

/* Another process should have the file locked already. */
void testlock(int fd, char *type, int start, int end, int pid) {
  int conflict_pid;

  conflict_pid = mylock(fd, F_GETLK, type, start, end);

  if (conflict_pid == pid) {
    printf("* Conflict found that is caused by forked process.\n\n");
  } else if (conflict_pid == 0) {
    printf("FAIL: No conflict found on file locked by forked process %d.\n", pid);
    inquisitive_exit();
  } else {
    printf("FAIL: Conflict found on file locked by unknown process %d instead of %d.\n",
	   conflict_pid, pid);
    inquisitive_exit();
  }
}

void testlock2(int fd, char *type, int start, int end) {
  int conflict_pid;

  conflict_pid = mylock(fd, F_GETLK, type, start, end);

  if (conflict_pid != 0) {
    printf("FAIL: Conflict found, but we unlocked everything.\n");
    inquisitive_exit();
  } else {
    printf("* No conflict found on file.\n\n");
  }
}

void lock1(int fd, char *filetolock, char *type, int start, int end) {
  int status;
  char str[255];

  mylock(fd, F_SETLK, type, start, end);
  sprintf(str, "./lock %s %s NOBLOCK %d %d NOSLEEP", filetolock, type, start, end - start);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("* Another process could not exclusively lock bytes %d to %d\n", start, end);
    printf("\twhich means lock operation was successful.\n\n");
  } else {
    printf("EXECUTED: ./lock %s %s NOBLOCK %d %d NOSLEEP\n", filetolock, type, start, end - start);
    printf("FAIL: Another process successfully exclusively locked bytes %d to %d\n", start, end);
    printf("\twhich means the lock operation failed.\n");
    inquisitive_exit();
  }
}

void unlock1(int fd, char *filetolock, int start, int end) {
  int status;
  char str[255];

  mylock(fd, F_SETLK, "UNLOCK", start, end);
  sprintf(str, "./lock %s EXCLUSIVE NOBLOCK %d %d NOSLEEP", filetolock, start, end - start);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("FAIL: Another process could not exclusively lock bytes %d to %d which means that we probably failed to unlock.\n", start, end);
    inquisitive_exit();
  } else {
    printf("* Another process successfully exclusively locked bytes %d to %d which means the unlock operation was successful.\n\n", start, end);
  }
}

void unlock2(int fd, char *filetolock, int start, int end, int prevstart, int prevend) {
  int status;
  char str[255];

  mylock(fd, F_SETLK, "UNLOCK", start, end);
  sprintf(str, "./lock %s EXCLUSIVE NOBLOCK %d %d NOSLEEP", filetolock, start, end - start);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("FAIL: Another process could not exclusively lock bytes %d to %d\n", start, end);
    printf("\t which means the unlock operation failed.\n");
    inquisitive_exit();
  } else {
    printf("* Another process successfully exclusively locked bytes %d to %d\n", start, end);
    printf("\twhich means the unlock operation was successful.\n\n");
  }

  sprintf(str, "./lock %s EXCLUSIVE NOBLOCK %d %d NOSLEEP", filetolock, prevstart, start);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("* Another process could not exclusively lock bytes %d to %d\n", prevstart, start);
    printf("\twhich means the start of the larger lock was preserved.\n\n");
  } else {
    printf("FAIL: Another process successfully exclusively locked bytes %d to %d\n", prevstart, start);
    printf("\twhich means the lock was not split.\n");
    inquisitive_exit();
  }

  sprintf(str, "./lock %s EXCLUSIVE NOBLOCK %d %d NOSLEEP", filetolock, end, prevend);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("* Another process could not exclusively lock bytes %d to %d\n", end, prevend);
    printf("\twhich means the end of the larger lock was preserved.\n\n");
  } else {
    printf("FAIL: Another process successfully exclusively locked bytes %d to %d\n", end, prevend);
    printf("\twhich means the lock was not split.\n");
    inquisitive_exit();
  }

  sprintf(str, "./lock %s EXCLUSIVE NOBLOCK %d %d NOSLEEP", filetolock, prevend, prevend+10);
  status = system(str);
  if (WEXITSTATUS(status) != 0) {
    printf("FAIL: Process could not exclusively lock bytes %d to %d\n", prevend, prevend+10);
    printf("\twhich were never locked in the first place!! This is a very big problem.\n");
    inquisitive_exit();
  } else {
    printf("* Process could successfully exclusively locked bytes %d to %d\n", prevend, prevend+10);
    printf("\twhich means bytes that were never locked are still unlocked.\n\n");
  }
}

int main(int argc, char **argv) {
  char *filetolock,*currfile,*type,*block;
  int status, i, j, pid, shmid;
  key_t shmem_key = 345626;
  int singlefd, fd[NUMFILESTOTEST];
  int *shared_int;
  sem_t* mutex;

  if (argc < 4) {
    printf("Not enough arguments to %s\n", argv[0]);
    printf("Usage: %s filename [SHARED|EXCLUSIVE] [NOBLOCK|BLOCK]\n", argv[0]);
    exit(1);
  }

  filetolock = argv[1];
  type = argv[2];
  block = argv[3];
  currfile = calloc(0, (strlen(filetolock)+50)*sizeof(char));

  global_filetolock = filetolock;

  /* Open and close multiple times before lock operations */
  for(j=0; j < NUMFILESTOTEST; j++) {
    sprintf(currfile, "%s.%d\n", filetolock, j);
    printf("Commencing multiple open/close ops for %s", currfile);
    for(i=0; i < OPENCLOSELOOP; i++) {
      singlefd = open(currfile, O_RDWR|O_CREAT);
      if (errno) {
        fprintf(stderr, "FAIL: Could not open the file %s prior to locking.\n", currfile);
	exit(1);
      }
      close(singlefd);
    }
  }
  
  printf("Open/Close of files completed.\n");
  printf("Forking another process to hold a lock during \"TEST\" request.\n\n");

  ///////////////////////////////////////////////////////////////////
  // SETUP SHARED MUTEX FOR FORKED PROCESSES
  ///////////////////////////////////////////////////////////////////
  shmid = shmget(shmem_key, sizeof(int), IPC_CREAT);
  if (shmid < 0) {
    perror("FAIL: Could not create shared memory space.");
    exit(1);
  }

  shared_int = (int *)shmat(shmid, NULL, 0);
  if (shared_int == (void *) -1) {
    perror("FAIL: Could not share shared memory space.");
    exit(1);
  }
  *shared_int = 0;
  
  mutex = sem_open("mutex", O_CREAT);
  sem_init(mutex, 1, 1);
  sem_wait(mutex);
  
  pid = fork();

  ///////////////////////////////////////////////////////////////////
  // CHILD PROCESS
  ///////////////////////////////////////////////////////////////////
  if (pid == 0) {
    sem_wait(mutex);
    for(j=0; j < NUMFILESTOTEST; j++) {
      sprintf(currfile, "%s.%d", filetolock, j);    
      printf("Child opening file: %s\n", currfile);
      fd[j] = open(currfile, O_RDWR|O_CREAT);
      if (errno) {
	fprintf(stderr, "FAIL: Could not open the file prior to locking.\n");
	*shared_int = -1;
	kill(0, SIGTERM);
	exit(1);
      }
      
      printf("Child EXCLUSIVE locking entire file: %s\n", currfile);    
      lock1(fd[j], currfile, "EXCLUSIVE", 0, 0);
    }

    /* Wait until parent signals that we can unlock and exit */
    printf("Child signalling and waiting for parent process.\n");

    *shared_int = 1; /* Tell parent file is locked and we're looping*/
    while (*shared_int != 2) {
      sem_post(mutex);
      sleep(1);
      sem_wait(mutex);
    }

    printf("Child closing all file handles\n");
    for(j=0; j < NUMFILESTOTEST; j++)
      close(fd[j]);

    printf("Child signalling to parent process that child is exiting.\n");
    *shared_int = 3; /* Tell parent we're exiting.*/
    sem_post(mutex);

    return 0;
  }

  ///////////////////////////////////////////////////////////////////
  // PARENT PROCESS
  ///////////////////////////////////////////////////////////////////
  else {
    printf("Parent waitinf for child process to lock file: %s\n", filetolock);
    while(*shared_int != 1) {
      sem_post(mutex);
      printf("Waiting for forked child process to lock the file ...  %d\n", *shared_int);
      sleep(1);

      sem_wait(mutex);

      if (waitpid(pid, &status, WNOHANG) > 0) {
	if (WIFEXITED(status))
	  printf("FAIL: Child process exited prematurely before TEST requests with status:%d\n",
		 WEXITSTATUS(status));
	else
	  printf("FAIL: Error with child process, waitpid status: %d\n", WEXITSTATUS(status));
	kill(0, SIGTERM);
	exit(1);
      }
    }

    for(j=0; j < NUMFILESTOTEST; j++) {
      sprintf(currfile, "%s.%d", filetolock, j);    
      printf("Parent opening file: %s\n", currfile);
      fd[j] = open(currfile, O_RDWR);
      if (errno) {
	fprintf(stderr, "FAIL: Could not open the file prior to locking.\n");
	kill(0, SIGTERM);
	exit(1);
      }

      printf("Parent testing lock on file: %s\n", currfile);
      testlock(fd[j], type, 0, 0, pid);
    }

    printf("NFS \"TEST\" REQUEST TEST -- PASSED\n\n");

    /* Signal the forked process to exit. */
    printf("Parent signalling and waiting for child to exit\n");
    *shared_int = 2; /* Tell child to unlock and exit. */

    while(*shared_int != 3) {
      sem_post(mutex);
      printf("Waiting for child process to exit ...\n");
      sleep(1);
      sem_wait(mutex);
    }    

    ///////////////////////////////////////////////////////////////////
    // MAIN LOCKING TESTS ON MULTIPLE FILES
    ///////////////////////////////////////////////////////////////////
    for(j=0; j < NUMFILESTOTEST; j++) {
      sprintf(currfile, "%s.%d", filetolock, j);
      printf(" -- Starting lock tests for %s -- \n", currfile);

      // friendly multiple lock test: lock 0-3, lock 8-11, lock 16-19, lock 24-27, unlock 0-3, unlock 8-11, unlock 16-19, unlock 24-27
      printf("Beginning sequential lock test\n");
      lock1(fd[j], currfile, type, 0, 3);
      lock1(fd[j], currfile, type, 8, 11);
      lock1(fd[j], currfile, type, 16, 19);
      lock1(fd[j], currfile, type, 24, 27);
      
      unlock1(fd[j], currfile, 0, 3);
      unlock1(fd[j], currfile, 8, 11);
      unlock1(fd[j], currfile, 16, 19);
      unlock1(fd[j], currfile, 24, 27);
      printf("SEQUENTIAL LOCK/UNLOCK TEST -- PASSED\n\n");
      
      //   unfriendly multiple lock test: lock 0-15, unlock 4-7, unlock 0-0 (whole file)
      printf("Beginning split lock test.\n");
      lock1(fd[j], currfile, type, 0, 15);
      unlock2(fd[j], currfile, 4, 7, 0, 15);
      unlock1(fd[j], currfile, 0, 0);
      printf("SPLIT LOCK TEST -- PASSED\n\n");
    }    

    /* Check if locks are all gone now */
    for(j=0; j < NUMFILESTOTEST; j++) {
      sprintf(currfile, "%s.%d", filetolock, j);    
      printf("Testing lock on file: %s\n", currfile);
      testlock2(fd[j], "EXCLUSIVE", 0, 0);
    }

    for(j=0; j < NUMFILESTOTEST; j++)
      close(fd[j]);

    printf("-----------------------\n");
    printf("-- ALL TESTS PASSED! --\n");
    printf("-----------------------\n\n");
  }

  free(sem_close);
  free(currfile);
  kill(0, SIGTERM);
  return 0;
}

