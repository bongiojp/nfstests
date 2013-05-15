#define _LARGEFILE64_SOURCE

#include <sys/types.h>
#include <sys/param.h>
#include <dirent.h>
#include <pwd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <stdio.h>
#include <sys/vfs.h>
#include <malloc.h>
#include <fcntl.h>

#include <stdint.h>

#include <gpfs.h>
#include <gpfs_nfs.h>
#include <gpfs_gpl.h>
#include <gpfs_fcntl.h>

#define FSAL_NGROUPS_MAX 32
#define OPENHANDLE_HANDLE_LEN 40
struct file_handle
{
  int handle_size;
  int handle_type;
  int handle_key_size;
  /* file identifier */
  unsigned char f_handle[OPENHANDLE_HANDLE_LEN];
};

struct user_credentials {
  uid_t user;
  gid_t group;
  int nbgroups;
  gid_t alt_groups[FSAL_NGROUPS_MAX];
};

#define FSAL_OP_CONTEXT_T_SIZE 680
typedef struct
{
  void *export_context;
  struct user_credentials credential;
  char data[FSAL_OP_CONTEXT_T_SIZE]; /* slightly bigger (for now) */
} fsal_op_context_t;

#define FSAL_HANDLE_T_SIZE            152
typedef struct
{
  char data[FSAL_HANDLE_T_SIZE];
} fsal_handle_t;

#define FSAL_MAX_PATH_LEN   PATH_MAX
typedef struct fsal_path__
{
  char path[FSAL_MAX_PATH_LEN];
  unsigned int len;
} fsal_path_t;

typedef struct
{
  struct
  {
    struct file_handle handle;
  } data ;
} gpfsfsal_handle_t;

typedef struct
{
  /* Warning: This string is not currently filled in or used. */
  char mount_point[FSAL_MAX_PATH_LEN];

  int mount_root_fd;
  gpfsfsal_handle_t mount_root_handle;
  unsigned int fsid[2];
} gpfsfsal_export_context_t;

typedef struct
{
  gpfsfsal_export_context_t *export_context; 
  struct user_credentials credential;
} gpfsfsal_op_context_t;

#define GPFS_ACL_BUF_SIZE 0x1000
typedef struct fsal_xstat__
{
  struct stat64 buffstat;
  char buffacl[GPFS_ACL_BUF_SIZE];
} gpfsfsal_xstat_t;

#define FSAL_MAX_NAME_LEN 255

typedef struct fsal_name__
{
  char name[FSAL_MAX_NAME_LEN];
  unsigned int len;
} fsal_name_t;


int fsal_internal_get_handle(fsal_op_context_t * p_context,
			     fsal_path_t * p_fsalpath, 
			     fsal_handle_t * p_handle) {
  int rc;
  struct name_handle_arg harg;

  if(!p_context || !p_handle || !p_fsalpath)
    return -1;

  harg.handle = (struct gpfs_file_handle *) &((gpfsfsal_handle_t *)p_handle)->data.handle;
  harg.handle->handle_size = OPENHANDLE_HANDLE_LEN;
  harg.name = p_fsalpath->path;
  harg.dfd = AT_FDCWD;
  harg.flag = 0;

  printf("Lookup handle for %s ...\n",p_fsalpath->path);
  rc = gpfs_ganesha(OPENHANDLE_NAME_TO_HANDLE, &harg);
  return rc;
}

int fsal_get_xstat_by_handle(fsal_op_context_t * p_context,
                             fsal_handle_t * p_handle,
                             gpfsfsal_xstat_t *p_buffxstat){
  int rc;
  int dirfd = 0;
  struct xstat_arg xstatarg;

  if(!p_handle || !p_context || !p_context->export_context || !p_buffxstat)
    return EFAULT;

  memset(p_buffxstat, 0, sizeof(gpfsfsal_xstat_t));

  dirfd = ((gpfsfsal_op_context_t *)p_context)->export_context->mount_root_fd;

  xstatarg.attr_valid = XATTR_STAT;
  xstatarg.mountdirfd = dirfd;
  xstatarg.handle = (struct gpfs_file_handle *) &((gpfsfsal_handle_t *)p_handle)->data.handle;
  xstatarg.acl = NULL;

  xstatarg.attr_changed = 0;
  xstatarg.buf = &p_buffxstat->buffstat;

  printf("Getattr by handle ...\n");

  rc = gpfs_ganesha(OPENHANDLE_GET_XSTAT, &xstatarg);
  printf("gpfs_ganesha: GET_XSTAT returned, rc = %d\n", rc);

  if(rc < 0) {
    printf("fsal_get_xstat_by_handle returned errno:%d -- %s\n",
                 errno, strerror(errno));
    return errno;
  }
  return 0;
}

void print_attrs(gpfsfsal_xstat_t *p_buffxstat) {
  struct stat64 *p_buffstat = &p_buffxstat->buffstat;

  printf("------------------------\n");
  printf("filesize = %llu\n", p_buffstat->st_size);
  printf("fileid = %llu\n", p_buffstat->st_ino);
  printf("mode = %llu\n", p_buffstat->st_mode);
  printf("numlinks = %lu\n", p_buffstat->st_nlink);
  printf("owner = %u\n", p_buffstat->st_uid);
  printf("group = %u\n", p_buffstat->st_gid);
  printf("------------------------\n");
  /* etc */
}

int fsal_internal_get_handle_at(int dfd,
                                fsal_name_t * p_fsalname,
                                fsal_handle_t * p_handle) {
  int rc;
  struct name_handle_arg harg;

  if(!p_handle || !p_fsalname)
    return EFAULT;

  memset(p_handle, 0, sizeof(*p_handle));
  harg.handle = (struct gpfs_file_handle *) &((gpfsfsal_handle_t *)p_handle)->data.handle;
  harg.handle->handle_size = OPENHANDLE_HANDLE_LEN;
  harg.handle->handle_key_size = OPENHANDLE_KEY_LEN;
  harg.name = p_fsalname->name;
  harg.dfd = dfd;
  harg.flag = 0;

  printf("Lookup handle at for %s\n", p_fsalname->name);

  rc = gpfs_ganesha(OPENHANDLE_NAME_TO_HANDLE, &harg);

  if(rc < 0)
    return errno;

  return 0;
}

int main() {
  fsal_path_t path;
  int rc,fd,status, i, memsz, mempos, memval;
  fsal_op_context_t op_context;
  struct statfs stat_buf;
  gpfsfsal_export_context_t *p_export_context = calloc(0, sizeof(gpfsfsal_export_context_t));
  fsal_handle_t object_handle;
  fsal_handle_t object_handle_garbled;
  gpfsfsal_xstat_t buffstat;
  fsal_name_t file_name;
  unsigned char *handle_ptr;

  char *TESTDIR = "/ibm/gpfs0";
  char *TESTFILE = "invalid_getattrs_example";
  char *TESTFILE_PATH = "/ibm/gpfs0/invalid_getattrs_example";
  char *CREATETESTFILE = "mknod /ibm/gpfs0/invalid_getattrs_example c 1 1";
  char *REMOVETESTFILE = "rm -rf /ibm/gpfs0/invalid_getattrs_example";

  printf("Creating test file: %s\n", TESTFILE);
  system(CREATETESTFILE);

  strcpy(path.path, TESTDIR);
  path.len = strlen(TESTDIR);

  strcpy(file_name.name, TESTFILE);
  file_name.len = strlen(TESTFILE);

  fd = open(path.path, O_RDONLY | O_DIRECTORY);
  if(fd < 0) {
    printf("Couldn't open directory.\n");
    return 0;
  }
  p_export_context->mount_root_fd = fd;

  rc = statfs(path.path, &stat_buf);
  if(rc) {
    printf ("statfs call failed on file %s: %d", path.path, rc);
    return 0;
  }
  
 p_export_context->fsid[0] = stat_buf.f_fsid.__val[0];
 p_export_context->fsid[1] = stat_buf.f_fsid.__val[1];
 
 /* Get file handle to root of GPFS share */
 op_context.export_context = p_export_context;

 status = fsal_internal_get_handle(&op_context,
				   &path,
				   (fsal_handle_t *)(&(p_export_context->mount_root_handle)));
 if (status)
   printf("fsal_internal_get_handle() failed\n");

 /* Now show the error for when we use a nonsense file handle. */
 /* printf("USING AN UNINITIALIZED FILE HANDLE FOR GETATTR ...\n");
 fsal_get_xstat_by_handle(&op_context, &object_handle, &buffstat);
 printf("\n");
 */

 /* Get handle of file */
 fsal_internal_get_handle_at(fd, &file_name, &object_handle);

 /* Getattrs of file */
 printf("USING A CORRECT FILE HANDLE FOR GETATTR ...\n");
 handle_ptr = ((gpfsfsal_handle_t *)&object_handle)->data.handle.f_handle;
 printf("handle: ");
 for(i=0; i < OPENHANDLE_HANDLE_LEN; i++)
   printf("%02x", (unsigned char)handle_ptr[i]);
 printf("\n");

 fsal_get_xstat_by_handle(&op_context, &object_handle, &buffstat);

 /* print attrs */
 print_attrs(&buffstat);
 printf("\n");

 /* Getattrs of file */
 /* printf("USING A FILE HANDLE THAT HAS BEEN MEMSET at 4th BYTE FOR GETATTR ...\n");
 memcpy(&object_handle_garbled, &object_handle, sizeof(fsal_handle_t));
 handle_ptr = ((gpfsfsal_handle_t *)&object_handle_garbled)->data.handle.f_handle;
 memset(handle_ptr+3, 4, 1); 

 printf("handle: ");
 for(i=0; i < OPENHANDLE_HANDLE_LEN; i++)
   printf("%02x", (unsigned char)handle_ptr[i]);
 printf("\n");

 fsal_get_xstat_by_handle(&op_context, &object_handle_garbled, &buffstat);
 printf("\n");
 */
 /* Getattrs of file */
 /*
 printf("USING A FILE HANDLE THAT HAS BEEN MEMSET at 2nd BYTE FOR GETATTR ...\n");
 memcpy(&object_handle_garbled, &object_handle, sizeof(fsal_handle_t));
 handle_ptr = ((gpfsfsal_handle_t *)&object_handle_garbled)->data.handle.f_handle;
 memset(handle_ptr+1, 4, 1); 

 printf("handle: ");
 for(i=0; i < OPENHANDLE_HANDLE_LEN; i++)
   printf("%02x", (unsigned char)handle_ptr[i]);
 printf("\n");

 fsal_get_xstat_by_handle(&op_context, &object_handle_garbled, &buffstat);
 printf("\n");
 */
 /* Getattrs of file */
 /*
 printf("USING FILE HANDLEs THAT HAVE BEEN MEMSET\n");
 for(memsz=0; memsz <= OPENHANDLE_HANDLE_LEN; memsz++) {
   for(mempos=0; mempos <= OPENHANDLE_HANDLE_LEN-memsz; mempos++) {
     for(memval=0; memval <= 255; memval++) {
       memcpy(&object_handle_garbled, &object_handle, sizeof(fsal_handle_t));
       handle_ptr = ((gpfsfsal_handle_t *)&object_handle_garbled)->data.handle.f_handle;
       memset(handle_ptr+mempos, memval, memsz); 
       
       printf("handle: ");
       for(i=0; i < OPENHANDLE_HANDLE_LEN; i++)
         printf("%02x", (unsigned char)handle_ptr[i]);
       printf("\n");
       
       fsal_get_xstat_by_handle(&op_context, &object_handle_garbled, &buffstat);
     }
   }
 }
 */
 /* delete file */
 printf("Removing test file: %s\n", TESTFILE);
 system(REMOVETESTFILE);

 /* Now show the INTERRUPT error. */
 printf("USING A FILE HANDLE FROM A DELETED FILE FOR GETATTR ...\n");
 fsal_get_xstat_by_handle(&op_context, &object_handle, &buffstat);
 printf("\n");

 close(fd);

 return 0;
}
