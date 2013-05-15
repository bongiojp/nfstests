all: build run
build:
	gcc -lgpfs -o fifo_s.test gpfs_invalid_fifodev_w_ssh_getattrs.c
	gcc -lgpfs -o fifo_l.test gpfs_invalid_fifodev_w_local_getattrs.c

	gcc -lgpfs -o ubuff_s.test gpfs_invalid_unbuffchardev_w_ssh_getattrs.c
	gcc -lgpfs -o ubuff_l.test gpfs_invalid_unbuffchardev_w_local_getattrs.c

	gcc -lgpfs -o block_s.test gpfs_invalid_blockdev_w_ssh_getattrs.c
	gcc -lgpfs -o block_l.test gpfs_invalid_blockdev_w_local_getattrs.c

	gcc -lgpfs -o file_s.test gpfs_invalid_file_w_ssh_getattrs.c
	gcc -lgpfs -o file_l.test gpfs_invalid_file_w_local_getattrs.c

	gcc -lgpfs -o char_s.test gpfs_invalid_chardev_w_ssh_getattrs.c
	gcc -lgpfs -o char_l.test gpfs_invalid_chardev_w_local_getattrs.c

	gcc -lgpfs -o dir_s.test gpfs_invalid_directory_w_ssh_getattrs.c
	gcc -lgpfs -o dir_l.test gpfs_invalid_directory_w_local_getattrs.c

	gcc -lgpfs -o symlink_s.test gpfs_invalid_symlink_w_ssh_getattrs.c
	gcc -lgpfs -o symlink_l.test gpfs_invalid_symlink_w_local_getattrs.c

run: fifo_s.test ubuff_s.test block_s.test file_s.test char_s.test dir_s.test symlink_s.test \
	fifo_l.test ubuff_l.test block_l.test file_l.test char_l.test dir_l.test symlink_l.test
fifo_s.test:
	./$@ | grep "Stale NFS file handle"
clean:
	rm fifo_s.test ubuff_s.test block_s.test file_s.test char_s.test dir_s.test symlink_s.test \
	fifo_l.test ubuff_l.test block_l.test file_l.test char_l.test dir_l.test symlink_l.test
