CC ?= gcc
CFLAGS ?= -Wall -O2
AR ?= ar
ARFLAGS ?= rcs

LIBSRC = dma_driver.c
LIBOBJ = $(LIBSRC:.c=.o)
LIB = libdma_driver.a

EXAMPLESRC = dma_example.c
EXE = dma_example

INCLUDES = -I.

.PHONY: all clean

all: $(LIB) $(EXE)

$(LIB): $(LIBOBJ)
	$(AR) $(ARFLAGS) $@ $^

$(EXE): $(EXAMPLESRC) $(LIB)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $^ 

%.o: %.c dma_driver.h
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(LIBOBJ) $(LIB) $(EXE) 