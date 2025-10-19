# Variables
CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -I include
LDFLAGS = -lm

# Directories
SRC_DIR = src
INC_DIR = include
TEST_DIR = tests
BUILD_DIR = build

TARGET = soro
TEST_TARGET = test_soro

# Source files
SRCS = $(filter-out $(SRC_DIR)/main.c, $(wildcard $(SRC_DIR)/*.c))
OBJS = $(SRCS:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)
MAIN_OBJ = $(BUILD_DIR)/main.o

# Test files
TEST_SRCS = $(wildcard $(TEST_DIR)/*.c)
TEST_OBJS = $(TEST_SRCS:$(TEST_DIR)/%.c=$(BUILD_DIR)/test_%.o)

# Default target
all: $(TARGET)

# Build main executable
$(TARGET): $(OBJS) $(MAIN_OBJ)
	@echo "Linking $@..."
	@$(CC) $^ -o $@ $(LDFLAGS)

# Compile source files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# Compile test files
$(BUILD_DIR)/test_%.o: $(TEST_DIR)/%.c | $(BUILD_DIR)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -I $(TEST_DIR) -c $< -o $@

# Build test executable
$(TEST_TARGET): $(OBJS) $(TEST_OBJS)
	@echo "Linking $@..."
	@$(CC) $^ -o $@ $(LDFLAGS)

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Run tests
test: $(TEST_TARGET)
	@echo "Running tests..."
	@./$(TEST_TARGET)

# Run the compiler
run: $(TARGET)
	@./$(TARGET)

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(TARGET) $(TEST_TARGET)

# Rebuild everything
rebuild: clean all

.PHONY: all test run clean rebuild
