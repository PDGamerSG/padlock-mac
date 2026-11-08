.PHONY: build release clean

build:
	./scripts/build.sh

release:
	./scripts/release.sh

clean:
	rm -rf .build build dist
