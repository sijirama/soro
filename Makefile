
# Variables
CC = gcc
CFLAGS = -I src/headers
SRC_DIR = src
TEST_DIR = $(SRC_DIR)/tests
OBJ_DIR = build
TARGET = soro
LDFLAGS = -lm

TEST_TARGET = test_calc
TEST_SRCS = $(wildcard $(TEST_DIR)/*.c)
TEST_OBJS = $(patsubst $(TEST_DIR)/%.c, $(OBJ_DIR)/%.o, $(TEST_SRCS))

# Source and object files
SRCS = $(filter-out $(SRC_DIR)/main.c, $(wildcard $(SRC_DIR)/*.c))
OBJS = $(patsubst $(SRC_DIR)/%.c, $(OBJ_DIR)/%.o, $(SRCS))

# Default target
all: $(TARGET)

# Create the target executable
$(TARGET): $(OBJS) $(OBJ_DIR)/main.o
	@echo "Linking executable $(TARGET)..."
	@$(CC) $(CFLAGS) -o  $@ $^ $(LDFLAGS)

# Compile source files to object files
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS)  $(LDFLAGS) -c $< -o $@

# Compile test source files to object files
$(OBJ_DIR)/%.o: $(TEST_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	@echo "Compiling test file $<..."
	@$(CC) $(CFLAGS)  $(LDFLAGS) -c $< -o $@

# Link and create the test executable
$(TEST_TARGET): $(OBJS) $(TEST_OBJS)
	@echo "Linking test executable $(TEST_TARGET)..."
	@$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)


# Test target
test: $(TEST_TARGET)
	@echo "Running tests..."
	@./$(TEST_TARGET)

# Clean the build
clean:
	@echo "Cleaning build files..."
	@rm -rf $(OBJ_DIR) $(TARGET) $(TEST_TARGET)

# Run the application
run: $(TARGET)
	@./$(TARGET)

.PHONY: all clean run test

