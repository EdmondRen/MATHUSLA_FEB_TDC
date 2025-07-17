# // =================================================================================
# // FILE: Makefile
# //
# // DESCRIPTION:
# // Makefile to compile the AXI DMA library and the example application.
# //
# // USAGE:
# //   make        - Compiles the project
# //   make run    - Compiles and runs the example on the target
# //   make clean  - Removes compiled files
# //
# // =================================================================================

# Target executable name
TARGET = dma_example

# Compiler and flags
CXX = g++
CXXFLAGS = -std=c++11 -Wall -O2 -pthread
LDFLAGS = -lstdc++

# Source files
# This will automatically find all .cpp files in the current directory
SOURCES = $(wildcard *.cpp)
# Create a list of object files from the source files
OBJECTS = $(SOURCES:.cpp=.o)

# Default rule: build the executable
all: $(TARGET)

# Rule to link the executable
$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $(TARGET) $(LDFLAGS)

# Rule to compile C++ source files into object files
%.o: %.cpp %.hpp axi_dma_api.h
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Rule to run the example (assumes target has been pushed to the board)
run: all
	./$(TARGET)

# Rule to clean up the build directory
clean:
	rm -f $(TARGET) $(OBJECTS)

.PHONY: all clean run
