# 1. Trova tutti i file .scm ovunque (anche nelle sottocartelle)
# Usiamo 'find' invece di 'ls' per cercare in modo ricorsivo, escludendo file nascosti di Emacs
SOURCES := $(shell ls *.scm)
GO_FILES := $(SOURCES:.scm=.go)

# Target principale: compila tutto
all: $(GO_FILES)

# Regola generica: trasforma un .scm in un .go mantenendo la struttura delle cartelle
%.go: %.scm
	guild compile -L .. -o $@ $<

# 3. La regola watch (AGGIORNATA CON IL FLAG RICORSIVO)
#watch:
#	while true; do \
#		inotifywait -r -e modify,create,delete --include '.*\.scm$$' .; \
#		make all; \
#	done

# Clean (trova già i .go in tutte le cartelle, va benissimo così)
clean:
	rm -f *.go 


