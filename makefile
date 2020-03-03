# Rule for building executable shells
.ONESHELL:
.sh:
	cp $? `basename $? .sh`
	chmod +x `basename $? .sh`

INSTALL = extract_ior extract_md do_extract \
					ior_runner dobatch_ior list_dobatch_ior \
					md_runner dobatch_md list_dobatch_md \
					md_cleanup md_count_and_remove \
					func.logger func.global func.debug

.PHONY: all clean uninstall
all: $(INSTALL)

clean:
	rm -f $(INSTALL)

install: $(INSTALL)
	mkdir -p $(HOME)/bin
	install -m 711 -o $(USER) -C $? $(HOME)/bin
	hash $?
uninstall:
	@for script in $(INSTALL) ; \
	do  \
		echo "rm -f $(HOME)/bin/$$script" ; \
		rm -f $(HOME)/bin/$$script ; \
	done
	hash -r
	#vim: set syntax=makefile
