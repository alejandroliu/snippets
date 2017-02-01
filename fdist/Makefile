#
# Build script
#
DESTDIR	= /usr/local
BINDIR	= /bin
MANDIR	= /man
PWD=$(shell pwd)
MANIFY=perl $(PWD)/../tlkit/manify
ASHLIB=$(PWD)/../ashlib
ASHCC=sh $(ASHLIB)/ashcc -I$(ASHLIB)

all:

$(DESTDIR)$(BINDIR)/fdistc: fdistc.sh
	$(ASHCC) -o$@ $<

$(DESTDIR)$(BINDIR)/fdist_mkidx: mkindex.php
	install -m755 $< $@

subdirs:
	mkdir -p $(DESTDIR)$(BINDIR)

manpages:
	mkdir -p $(DESTDIR)$(MANDIR)
	$(MANIFY) --outdir=$(DESTDIR)$(MANDIR) --genman .

install: subdirs manpages \
	$(DESTDIR)$(BINDIR)/fdistc \
	$(DESTDIR)$(BINDIR)/fdist_mkidx

clean:
	find . -name '*~' | xargs -r rm -v
