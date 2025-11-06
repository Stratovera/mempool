.PHONY: help install config deploy start stop status logs backup monitoring test clean

BIN=bin/mempool-deploy

help:
	@$(BIN) help

install:
	@$(BIN) install

config:
	@$(BIN) config

deploy:
	@$(BIN) deploy

start:
	@$(BIN) start

stop:
	@$(BIN) stop

status:
	@$(BIN) status

logs:
	@$(BIN) logs $(NETWORK) $(SERVICE)

backup:
	@$(BIN) backup

monitoring:
	@$(BIN) monitoring

test:
	@$(BIN) test

clean:
	rm -rf .tmp
