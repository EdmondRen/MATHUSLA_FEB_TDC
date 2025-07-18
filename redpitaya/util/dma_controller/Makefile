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

# Target compiler and flags
CXX = g++
CXXFLAGS = -std=c++11 -Wall -O2 -pthread
LDFLAGS = -lstdc++


# Sources
LIBSRCS = axi_dma_api.cpp axi_dma_controller.cpp
LIBOBJS = $(LIBSRCS:.cpp=.o)

EXAMPLES = example1.cpp example2.cpp
EXECS = $(EXAMPLES:.cpp=)
EXOBJS = $(EXAMPLES:.cpp=.o)

# Default target
all: $(EXECS)

# Build library object files
$(LIBOBJS): %.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile example .cpp to .o
$(EXOBJS): %.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Link each executable from its .o and the library objects
$(EXECS): %: %.o $(LIBOBJS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

# Run target
run: all
	@if [ -z "$(EX)" ]; then \
		echo "Usage: make run EX=example1"; \
		exit 1; \
	else \
		./$(EX); \
	fi

# Clean target
clean:
	rm -f $(EXECS) $(LIBOBJS) $(EXOBJS)