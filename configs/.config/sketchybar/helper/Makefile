# Сборка единого event-provider для sketchybar.
#   make        — собрать бинарник sketchybar_metrics
#   make clean  — удалить бинарник

BIN      = sketchybar_metrics
SRC      = provider.c mach.c
# Select the compiler and SDK together. A bare clang may pick an older
# toolchain from PATH while using a newer Command Line Tools SDK.
CC       = /usr/bin/xcrun --sdk macosx --toolchain default clang
CFLAGS   = -std=c99 -O2 -Wall -Wno-deprecated-declarations
FRAMEWORKS = -framework CoreFoundation -framework CoreGraphics -framework IOKit -framework Carbon

$(BIN): $(SRC) mach.h
	$(CC) $(CFLAGS) $(SRC) -o $(BIN) $(FRAMEWORKS)

clean:
	rm -f $(BIN)

.PHONY: clean
