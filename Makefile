.PHONY: install update format lint test clean

install:
	shards install

update:
	shards update

format:
	crystal tool format

format-check:
	crystal tool format --check

lint:
	ameba --fix
	ameba

test:
	crystal spec

clean:
	rm -rf ./temp/*
