BREW    := $(shell brew --prefix)
CFLAGS  += -Wall -Wextra -O2 -I$(BREW)/include
LDFLAGS += -L$(BREW)/lib
LDLIBS  += -lusb-1.0 -lncurses
PREFIX  ?= $(HOME)/.local

uvctui: uvctui.c

install: uvctui
	install -d $(PREFIX)/bin
	install -m 755 uvctui $(PREFIX)/bin/uvctui

clean:
	rm -f uvctui

.PHONY: install clean
