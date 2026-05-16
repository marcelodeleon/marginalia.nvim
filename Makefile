NVIM ?= nvim
NVIM_CMD := $(NVIM) --headless --noplugin -u scripts/minimal_init.lua

deps:
	@test -d deps/mini.nvim || git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
	@test -d deps/diffview.nvim || git clone --depth 1 https://github.com/sindrets/diffview.nvim deps/diffview.nvim

test: deps
	$(NVIM_CMD) -c "lua MiniTest.run()" -c "qa!"

test-unit: deps
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_comments.lua')" -c "qa!"
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_comments_extmarks.lua')" -c "qa!"
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_review_file.lua')" -c "qa!"

test-ui: deps
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_ui.lua')" -c "qa!"

test-keymaps: deps
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_keymaps.lua')" -c "qa!"

test-integration: deps
	$(NVIM_CMD) -c "lua MiniTest.run_file('tests/test_integration.lua')" -c "qa!"

.PHONY: deps test test-unit test-ui test-keymaps test-integration
