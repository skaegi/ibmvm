.PHONY: test test-watch install uninstall

BATS := bats
TEST_DIR := test

# Run the full test suite
test:
	$(BATS) --recursive $(TEST_DIR)

# Run a single file:  make test FILE=test/02_start.bats
test-file:
	$(BATS) $(FILE)

# Re-run on file change (requires entr: brew install entr)
test-watch:
	find . -name '*.bats' -o -name 'ibmvm' -o -name 'test/mocks/*' | \
	  entr -c $(BATS) --recursive $(TEST_DIR)

install:
	bash ibmvm install

uninstall:
	bash ibmvm uninstall
