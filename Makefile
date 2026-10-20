SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TARGET ?= $(HOME)
DRY_RUN ?= 0
ifneq ($(filter plan,$(MAKECMDGOALS)),)
override DRY_RUN := 1
endif
export TARGET DRY_RUN
export PATH := $(HOME)/.local/bin:$(PATH):/opt/homebrew/bin:/usr/local/bin

# Discover payloads from the directory tree; no install-<name> registry is needed.
CONFIG_PATHS := $(patsubst $(ROOT)/configs/%,%,$(wildcard $(ROOT)/configs/.config/*))
ROOT_PATHS := $(patsubst $(ROOT)/configs/%,%,$(wildcard $(ROOT)/configs/.* $(ROOT)/configs/*))
CONFIG_PATHS += $(filter-out . .. .config .git .gitignore .gitmodules .stow-local-ignore .DS_Store .zsh.secrets .env .env.%,$(ROOT_PATHS))
config_name = $(if $(filter .zshrc .p10k.zsh,$(1)),zsh,$(patsubst .%,%,$(notdir $(1))))
PACKAGES := $(sort $(foreach path,$(CONFIG_PATHS),$(call config_name,$(path))))
PLATFORM := $(if $(filter Darwin,$(shell uname -s)),macos,arch)
ifeq ($(DRY_RUN),1)
ifneq ($(DOTFILES_PLATFORM),)
PLATFORM := $(DOTFILES_PLATFORM)
endif
endif
MACOS_ONLY := aerospace aerospace-swipe hammerspoon iterm2 sketchybar
ACTIVE := $(if $(filter macos,$(PLATFORM)),$(PACKAGES),$(filter-out $(MACOS_ONLY),$(PACKAGES)))
SELECTED ?= $(ACTIVE)
STATE_DIR ?= $(if $(XDG_STATE_HOME),$(XDG_STATE_HOME),$(HOME)/.local/state)/dotfiles
CONFLICTS ?= backup
START ?= 1
export DOTFILES_ROOT := $(ROOT)
export DOTFILES_STATE_DIR := $(STATE_DIR)
export DOTFILES_CONFLICTS := $(CONFLICTS)
check_supported = $(if $(filter $(1),$(ACTIVE)),,$(error $(1) does not support $(PLATFORM)))

# configs/ is one native Stow package. Filters retain per-config commands and OS
# selection; --no-folding ensures ignored siblings cannot enter via a folder link.
empty :=
space := $(empty) $(empty)
comma := ,
paths_for = $(foreach path,$(CONFIG_PATHS),$(if $(filter $(call config_name,$(path)),$(1)),$(path)))
path_pattern = $(subst $(space),|,$(strip $(foreach path,$(call paths_for,$(1)),$(subst .,\.,$(path))(/|$$))))
include_pattern = $(if $(filter .config/%,$(call paths_for,$(1))),\.config$$|)$(call path_pattern,$(1))
stow_for = stow --dir "$(ROOT)" --target "$(TARGET)" --no-folding $(if $(filter 1,$(DRY_RUN)),--simulate) --ignore='$(if $(strip $(call paths_for,$(1))),^(?!(?:$(call include_pattern,$(1)))).*,.*)' --$(2) configs
RUN := $(if $(filter 1,$(DRY_RUN)),echo,)
POST_INSTALL_nvim = env DOTFILES_BOOTSTRAP=1 nvim --headless '+lua require("config.bootstrap").run()' && $(MAKE) --no-print-directory -C "$(ROOT)" test-nvim
ANSIBLE_FLAGS ?=
BECOME_FLAGS ?= $(if $(filter arch,$(PLATFORM)),--ask-become-pass)
PLAYBOOK = ansible-playbook -i localhost, -c local "$(ROOT)/dependencies.yaml" $(if $(filter 1,$(DRY_RUN)),--check) $(ANSIBLE_FLAGS)
POST_INSTALL_hammerspoon = defaults write org.hammerspoon.Hammerspoon MJConfigFile "$(TARGET)/.config/hammerspoon/init.lua"
POST_INSTALL_aerospace-swipe = $(PLAYBOOK) --tags activation
TRANSACTION = $(PLAYBOOK) --tags transaction --extra-vars '{dotfiles_paths: [$(subst $(space),$(comma),$(strip $(call paths_for,$(SELECTED))))], dotfiles_configs: [$(subst $(space),$(comma),$(SELECTED))]}' --extra-vars "dotfiles_owner_pid=$$$$"
companions_aerospace := iterm2 sketchybar
companions_aerospace-swipe := aerospace iterm2 sketchybar
selection_for = $(sort $(1) $(companions_$(1)))

.DEFAULT_GOAL := help
.NOTPARALLEL:
.PHONY: help list ansible check stow deps-stow install deps link sync unlink plan start test test-transactions test-nvim initialize rollback recover \
        $(addprefix install-,$(PACKAGES)) $(addprefix deps-,$(PACKAGES)) \
        $(addprefix link-,$(PACKAGES)) $(addprefix unlink-,$(PACKAGES)) \
        $(addprefix init-,$(PACKAGES)) $(addprefix start-,$(MACOS_ONLY))

help:
	@printf '%s\n' \
	  'make install[-<name>]  Install dependencies, Stow links and plugins' \
	  'make deps[-<name>]     Install missing dependencies only' \
	  'make stow              Install GNU Stow if missing' \
	  'make sync              Repeat the transactional installation' \
	  'make link[-<name>]     Raw Stow links from the working copy (no history)' \
	  'make unlink[-<name>]   Run stow --delete' \
	  'make plan              Preview dependencies, Ansible steps and Stow changes' \
	  'make list              List configs selected for this OS' \
	  'make start[-<name>]    Start macOS apps/services' \
	  'make check             Validate dependencies.yaml' \
	  'make test              Validate YAML and test Stow in an isolated HOME' \
	  'make test-nvim         Verify installed Neovim plugins, tools and parsers' \
	  'make rollback          Restore configs from the last successful installation' \
	  'make recover           Restore an interrupted configuration transaction' \
	  '' 'Options: DRY_RUN=1 (Stow --simulate), TARGET=/existing/home' \
	  'Discovered configs: $(PACKAGES)'

list:
	@printf 'Platform: %s\n' '$(PLATFORM)'
	@printf '%s\n' $(ACTIVE)

ansible:
	@if ! command -v ansible-playbook >/dev/null; then \
	  case "$(PLATFORM)" in \
	    macos) brew install ansible ;; \
	    arch) sudo pacman -Syu --needed ansible ;; \
	    *) echo 'Supported systems: macOS and Arch Linux.' >&2; exit 1 ;; \
	  esac; \
	fi
	@ansible-doc -t module community.general.homebrew >/dev/null 2>&1 || ansible-galaxy collection install community.general

check: ansible
	@ansible-playbook -i localhost, -c local "$(ROOT)/dependencies.yaml" --syntax-check

stow:
	@if ! command -v stow >/dev/null; then $(MAKE) --no-print-directory deps-stow; fi

deps-stow: ansible
	@$(PLAYBOOK) $(BECOME_FLAGS) --tags deps,stow

ifeq ($(DRY_RUN),1)
install: plan
else
install: ansible stow
	@$(foreach config,$(SELECTED),$(call check_supported,$(config)))
	@$(TRANSACTION) --extra-vars dotfiles_action=preflight
	@$(MAKE) --no-print-directory deps SELECTED='$(SELECTED)'
	@$(TRANSACTION) --extra-vars dotfiles_action=install
	@if [ '$(START)' = 1 ]; then $(MAKE) --no-print-directory start SELECTED='$(SELECTED)'; fi
endif
deps: ansible
	@$(PLAYBOOK) $(BECOME_FLAGS) --tags deps,stow,$(subst $(space),$(comma),$(SELECTED))
initialize: $(addprefix init-,$(SELECTED))
rollback recover: ansible
	@$(TRANSACTION) --extra-vars dotfiles_action=$@
link: stow
	@$(call stow_for,$(ACTIVE),restow)
sync: install
unlink: stow
	@$(call stow_for,$(ACTIVE),delete)
plan:
	@command -v ansible-playbook >/dev/null && command -v stow >/dev/null || { \
	  printf '%s\n' 'Planning requires Ansible and GNU Stow. Run make ansible stow once, then make plan.' >&2; exit 1; }
	@ansible-doc -t module community.general.homebrew >/dev/null 2>&1 || { \
	  printf '%s\n' 'Planning requires the community.general collection. Run make ansible first.' >&2; exit 1; }
	@printf '\nDependency lists for %s (no packages will be installed):\n' '$(PLATFORM)'
	@$(PLAYBOOK) --tags validate --extra-vars '{requested_configs: [stow,$(subst $(space),$(comma),$(SELECTED))], dotfiles_plan_platform: $(PLATFORM)}'
	@printf '\nAnsible installation steps (tasks for other operating systems will be skipped during installation):\n'
	@$(PLAYBOOK) --list-tasks --tags deps,stow,$(subst $(space),$(comma),$(SELECTED))
	@printf '\nStow changes for %s (simulation):\n' '$(TARGET)'
	@$(call stow_for,$(SELECTED),restow) --verbose=1 || { \
	  if [ '$(CONFLICTS)' = backup ]; then printf '%s\n' 'When activation is needed, install backs up selected config roots before replacing them.'; else exit 1; fi; }
	@printf '\nInitialization after linking: %s\n' '$(strip $(foreach config,$(SELECTED),$(if $(POST_INSTALL_$(config)),$(config))))'
	@$(if $(filter iterm2,$(SELECTED)),printf '%s\n' 'The transaction also publishes the Dotfiles profile at $(TARGET)/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json. Select Dotfiles as the default profile in iTerm2 Settings.',:)

# These configs use each other's programs and settings. Make orders them.
deps-aerospace: deps-sketchybar
deps-aerospace-swipe: deps-aerospace
start-aerospace: start-sketchybar
start-aerospace-swipe: start-aerospace

$(addprefix install-,$(PACKAGES)): install-%:
	@$(call check_supported,$*)
	@$(MAKE) --no-print-directory install SELECTED='$(call selection_for,$*)'
$(addprefix deps-,$(PACKAGES)): deps-%: | ansible
	@$(call check_supported,$*)
	@$(PLAYBOOK) $(BECOME_FLAGS) --tags deps,stow,$*
$(addprefix link-,$(PACKAGES)): link-%: | stow
	@$(call check_supported,$*)
	@$(call stow_for,$*,restow)
$(addprefix unlink-,$(PACKAGES)): unlink-%: | stow
	@$(call check_supported,$*)
	@$(call stow_for,$*,delete)
$(addprefix init-,$(PACKAGES)): init-%:
	@$(call check_supported,$*)
	@$(if $(POST_INSTALL_$*),$(RUN) $(POST_INSTALL_$*))

start: $(addprefix start-,$(filter $(MACOS_ONLY),$(SELECTED)))
start-aerospace:
	@$(call check_supported,aerospace)
	@$(RUN) open -a AeroSpace
start-hammerspoon:
	@$(call check_supported,hammerspoon)
	@$(RUN) open -a Hammerspoon
start-iterm2:
	@$(call check_supported,iterm2)
	@$(RUN) open -a iTerm
start-sketchybar:
	@$(call check_supported,sketchybar)
	@$(RUN) brew services start FelixKratz/formulae/sketchybar
start-aerospace-swipe:
	@$(call check_supported,aerospace-swipe)
	@$(RUN) bash -ec 'domain="gui/$$(id -u)"; launchctl print "$$domain/com.acsandmann.swipe" >/dev/null 2>&1 || launchctl bootstrap "$$domain" "$(HOME)/Library/LaunchAgents/com.acsandmann.swipe.plist"; launchctl kickstart "$$domain/com.acsandmann.swipe"'

# Tests use real Stow and a disposable HOME; no OS packages or services are changed.
test-transactions: check
	@python3 -m unittest discover -s "$(ROOT)/tests" -v

test-nvim:
	@env DOTFILES_BOOTSTRAP=1 DOTFILES_NVIM_VERIFY="$(ROOT)/tests/verify_nvim.lua" nvim --headless '+lua dofile(vim.env.DOTFILES_NVIM_VERIFY)'

test: check test-transactions
	@command -v stow >/dev/null || { echo 'Run make stow first.' >&2; exit 1; }
	@tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/dotfiles-test.XXXXXX"); \
	trap 'rm -rf "$$tmp"' EXIT; \
	fixture="$$tmp/repo"; test_home="$$tmp/home"; \
	mkdir -p "$$fixture/configs/.config/nvim" "$$fixture/configs/.config/btop" "$$test_home"; \
	cp "$(ROOT)/Makefile" "$$fixture/Makefile"; \
	cp "$(ROOT)/dependencies.yaml" "$$fixture/dependencies.yaml"; \
	cp "$(ROOT)/configs/.stow-local-ignore" "$$fixture/configs/"; \
	printf 'editor\n' > "$$fixture/configs/.config/nvim/init.lua"; \
	printf 'monitor\n' > "$$fixture/configs/.config/btop/btop.conf"; \
	printf 'shell\n' > "$$fixture/configs/.zshrc"; \
	printf 'prompt\n' > "$$fixture/configs/.p10k.zsh"; \
	printf 'test-only\n' > "$$fixture/configs/.zsh.secrets"; \
	printf 'original\n' > "$$test_home/.zshrc"; \
	export HOME="$$test_home" TARGET="$$test_home"; \
	if $(MAKE) -s -C "$$fixture" link >"$$tmp/log" 2>&1; then echo 'Expected a Stow conflict' >&2; exit 1; fi; \
	test "$$(cat "$$test_home/.zshrc")" = original; test ! -e "$$test_home/.config/nvim/init.lua"; \
	rm "$$test_home/.zshrc"; \
	$(MAKE) -s -C "$$fixture" link-nvim >"$$tmp/log" 2>&1 || { cat "$$tmp/log"; exit 1; }; \
	test -L "$$test_home/.config/nvim/init.lua"; test ! -e "$$test_home/.config/btop"; test ! -e "$$test_home/.zshrc"; \
	$(MAKE) -s -C "$$fixture" link-zsh >"$$tmp/log" 2>&1; \
	$(MAKE) -s -C "$$fixture" link-zsh >"$$tmp/log" 2>&1; \
	test -L "$$test_home/.zshrc"; test -L "$$test_home/.p10k.zsh"; \
	$(MAKE) -s -C "$$fixture" unlink-nvim >"$$tmp/log" 2>&1; \
	test ! -e "$$test_home/.config/nvim/init.lua"; test -L "$$test_home/.zshrc"; \
	$(MAKE) -s -C "$$fixture" link DRY_RUN=1 >"$$tmp/log" 2>&1; \
	test ! -e "$$test_home/.config/btop/btop.conf"; \
	mkdir -p "$$fixture/configs/.config/tmux"; printf 'tmux\n' > "$$fixture/configs/.config/tmux/tmux.conf"; \
	printf 'git\n' > "$$fixture/configs/.gitconfig"; \
	$(MAKE) -s -C "$$fixture" link-tmux link-gitconfig >"$$tmp/log" 2>&1; \
	test -L "$$test_home/.config/tmux/tmux.conf"; test -L "$$test_home/.gitconfig"; \
	printf 'outside\n' > "$$fixture/.outsiderc"; \
	$(MAKE) -s -C "$$fixture" link >"$$tmp/log" 2>&1; \
	stow --dir "$$fixture" --target "$$test_home" --no-folding --restow configs >"$$tmp/log" 2>&1; \
	test ! -e "$$test_home/.outsiderc"; test ! -e "$$test_home/dependencies.yaml"; test ! -e "$$test_home/Makefile"; test ! -e "$$test_home/.zsh.secrets"; \
	printf 'keep\n' > "$$test_home/unrelated"; \
	$(MAKE) -s -C "$$fixture" unlink >"$$tmp/log" 2>&1; \
	test ! -e "$$test_home/.zshrc"; test -f "$$test_home/unrelated"; test -f "$$fixture/configs/.zshrc"; \
	mkdir -p "$$fixture/configs/.config/aerospace"; \
	DOTFILES_PLATFORM=arch DRY_RUN=1 $(MAKE) -s -C "$$fixture" -n link >"$$tmp/arch-plan"; \
	if grep -q '\.config/aerospace' "$$tmp/arch-plan"; then echo 'macOS config leaked into Arch plan' >&2; exit 1; fi; \
	printf 'Stow integration checks passed: conflicts, selection, idempotence, dry-run, discovery, isolation, platforms, unstow.\n'
