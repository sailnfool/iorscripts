# Rule for building executable shells
.ONESHELL:
.sh:
	cp $? `basename $? .sh`
	chmod +x `basename $? .sh`

INSTALL = ior.ex4 \
					md.ex2 \
					ior3runner dobunchior3 \
					md4runner dobunchmd3 \
					func.logger \
					func.global2

.PHONY: all clean uninstall
all: $(INSTALL)

clean:
	rm -f $(INSTALL)

install: $(INSTALL)
	mkdir -p $(HOME)/bin
	install -m 711 -o $(USER) -C $? $(HOME)/bin
uninstall:
	@for script in $(INSTALL) ; \
	do  \
		echo "rm -f $(HOME)/bin/$$script" ; \
		rm -f $(HOME)/bin/$$script ; \
	done
	#vim: set syntax=makefile
