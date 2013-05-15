
dFLAGS=-g -DDEBUG
FLAGS= -g -O -Wall -Werror
PFLAGS= -p -g3

#
# The following is "boilerplate" to set up the standard compilation
# commands:
.SUFFIXES:
.SUFFIXES: .cpp .c .cc .h .o
.c.o:  ; gcc $(FLAGS) -c $*.c

all: ml_master ml_posix_child

clean:
	rm -f *.o ml_master ml_posix_child *.out *.file

ml_master:		ml_functions.o ml_master.o
			gcc $(FLAGS) -lm -o ml_master ml_functions.o ml_master.o

ml_posix_child:		ml_functions.o ml_posix_child.o
			gcc $(FLAGS) -lm -o ml_posix_child ml_functions.o ml_posix_child.o

ml_master.o:		ml_master.c multilock.h

ml_posix_child.o:	ml_posix_child.c multilock.h

ml_functions.o:		ml_functions.c multilock.h
