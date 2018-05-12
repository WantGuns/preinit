INCDIR	= include
SRCDIR	= src
OUTDIR	= out

INITRAMFSDIR	= initramfs
ROOTDIR		= $(INITRAMFSDIR)/root

MKDIR	= mkdir -p $(OUTDIR)
MKINITRAMFSDIR	= mkdir -p $(ROOTDIR)

CHOST	= aarch64-unknown-linux-gnu
CC	= $(CHOST)-gcc
CXX	= $(CHOST)-g++
STRIP	= $(CHOST)-strip
CFLAGS	= -I$(INCDIR) -static
CXXFLAGS= $(CFLAGS) -Wall -std=c++17
ABOOTIMG= abootimg
GUNZIP	= gunzip
GZIP	= gzip
CPIO	= cpio
SED	= sed

_TARGETS= init
TARGETS	= $(patsubst %,$(OUTDIR)/%,$(_TARGETS))

_DEPS	= util/log_facility.o

_OBJS	= $(addsuffix .o,$(_TARGETS)) $(_DEPS)
OBJS	= $(patsubst %,$(SRCDIR)/%,$(_OBJS))

LIBS	=

$(TARGETS) : $(OBJS)
	$(MKDIR)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(LIBS)
	$(STRIP) $@

$(SRCDIR)/%.o : $(SRCDIR)/%.cpp $(INCDIR)/%.h
	$(CXX) -c $(CXXFLAGS) -I$(INCDIR)/$(dir $*) -o $@ $<

$(SRCDIR)/%.o : $(SRCDIR)/%.cc $(INCDIR)/%.h
	$(CXX) -c $(CXXFLAGS) -I$(INCDIR)/$(dir $*) -o $@ $<

$(SRCDIR)/%.o : $(SRCDIR)/%.c $(INCDIR)/%.h
	$(CC) -c $(CFLAGS) -I$(INCDIR)/$(dir $*) -o $@ $<

.PHONY : clean
clean :
	rm -f $(OBJS) $(OUTDIR)/*
	rm -rf $(ROOTDIR)

BOOTIMGCFG	= $(OUTDIR)/bootimg.cfg
KERNEL		= $(OUTDIR)/zImage
RAMDISK		= $(OUTDIR)/initrd.img
BOOTIMG		= $(INITRAMFSDIR)/boot.img
RAMDISK_OUT	= $(OUTDIR)/initrd-mod.img
BOOTIMG_OUT	= $(OUTDIR)/boot-mod.img

$(RAMDISK) : $(BOOTIMG)
	$(MKINITRAMFSDIR)
	$(ABOOTIMG) -x $(BOOTIMG) $(BOOTIMGCFG) $(KERNEL) $(RAMDISK)

unpack : $(RAMDISK)
	cat $(RAMDISK) | $(GUNZIP) | $(CPIO) -vidD $(ROOTDIR)

repack : $(ROOTDIR)
	cd $(ROOTDIR) && \
	  find . | $(CPIO) --create --format='newc' | $(GZIP) > $(abspath $(RAMDISK_OUT))
	# specify bootsize= so that abootimg does not complain about image size
	$(ABOOTIMG) --create $(BOOTIMG_OUT) -f $(BOOTIMGCFG) -k $(KERNEL) -r $(RAMDISK_OUT) -c 'bootsize='
