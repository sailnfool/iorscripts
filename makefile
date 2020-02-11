# Rule for building executable shells
.ONESHELL:
.sh:
	cp $? `basename $? .sh`
	chmod +x `basename $? .sh`

INSTALL = extract_ior \
					extract_md \
					ior_runner dobatch_ior list_dobatch_ior \
					md_runner dobatch_md list_dobatch_md\
					md_runner_sbatch ior_runner_sbatch \
					func.logger \
					func.global

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
