# Rule for building executable shells
.ONESHELL:
.sh:
	cp $? `basename $? .sh`
	chmod +x `basename $? .sh`

INSTALL = ior.ex1 ior.ex2 ior.ex3 ior.ex4 \
					md.ex1 md.ex2 \
					ior2runner dobunchior2 \
					md4runner dobunchmd3 \
					func.logger func.procrate func.getprocrate func.setdefprocrate \
					argsfibonacci argsexponent argsgenrange argspowers argsdouble \
					test.setdefprocrate

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
