CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -I include -g
LDFLAGS = -lm

SRC_DIR = src
INC_DIR = include
TEST_DIR = tests
BUILD_DIR = build
EXAMPLE_DIR = examples

TARGET = soro
TEST_TARGET = test_soro

# Source files (recursively find all .c files except main.c)
SRCS = $(shell find $(SRC_DIR) -name '*.c' ! -name 'main.c')
OBJS = $(SRCS:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)
MAIN_OBJ = $(BUILD_DIR)/main.o

# Test files (recursively find all test .c files)
TEST_SRCS = $(shell find $(TEST_DIR) -name '*.c')
TEST_OBJS = $(TEST_SRCS:$(TEST_DIR)/%.c=$(BUILD_DIR)/test_%.o)

all: $(TARGET)

$(TARGET): $(OBJS) $(MAIN_OBJ)
	@echo "Linking $@..."
	@$(CC) $^ -o $@ $(LDFLAGS)

# Compile source files (create subdirectories as needed)
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# Compile test files (create subdirectories as needed)
$(BUILD_DIR)/test_%.o: $(TEST_DIR)/%.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -I $(TEST_DIR) -c $< -o $@

$(TEST_TARGET): $(OBJS) $(TEST_OBJS)
	@echo "Linking $@..."
	@$(CC) $^ -o $@ $(LDFLAGS)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)/lexer $(BUILD_DIR)/test_lexer

test: $(TEST_TARGET)
	@echo "Running tests..."
	@./$(TEST_TARGET)

run: $(TARGET)
	@./$(TARGET) $(EXAMPLE_DIR)/hello.soro

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(TARGET) $(TEST_TARGET)

rebuild: clean all

.PHONY: all test run clean rebuild
