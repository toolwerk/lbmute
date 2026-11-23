PREFIX ?= $(HOME)/bin

lbmute: Sources/lbmute.swift
	swiftc -O Sources/lbmute.swift -o lbmute

install: lbmute
	mkdir -p $(PREFIX)
	install -m 755 lbmute $(PREFIX)/lbmute

clean:
	rm -f lbmute

.PHONY: install clean
