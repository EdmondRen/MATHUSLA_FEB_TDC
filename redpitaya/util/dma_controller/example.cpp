// =================================================================================
// FILE: example.cpp
//
// DESCRIPTION:
// An example application demonstrating how to use the AXI DMA C API.
//
// HOW TO COMPILE:
// See the provided Makefile. Run `make`.
//
// =================================================================================
#include "axi_dma_api.h"
#include <iostream>
#include <vector>
#include <unistd.h>
#include <cstring>
#include <sys/mman.h>
#include <fcntl.h>


// --- Configuration ---
const char* UIO_DEVICE_S2MM = "/dev/uio1";
const char* UIO_DEVICE_MM2S = "/dev/uio2";
const uint64_t DMA_PHYS_ADDR = 0x40400000;
const uint64_t MEM_PHYS_ADDR = 0x1000000;
const uint64_t MEM_SIZE = 0x2000000; // 32 * 1024 * 1024 =  32 MB

void run_direct_register_loopback_test() {
    std::cout << "\n--- Running Direct Register Mode Loopback Test ---" << std::endl;
    AxiDmaHandle_t dma = dma_create_irq(DMA_PHYS_ADDR, MEM_PHYS_ADDR, MEM_SIZE, UIO_DEVICE_S2MM, UIO_DEVICE_MM2S);
    if (!dma) return;
    dma_reset(dma);


    const uint32_t TRANSFER_LEN = 1024*4;
    uint64_t tx_buf_phys = MEM_PHYS_ADDR;
    uint64_t rx_buf_phys = MEM_PHYS_ADDR + TRANSFER_LEN;

    // Get virtual addresses to prepare buffers
    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    uint8_t* tx_buf_virt = (uint8_t*)mmap(NULL, TRANSFER_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, tx_buf_phys);
    uint8_t* rx_buf_virt = (uint8_t*)mmap(NULL, TRANSFER_LEN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, rx_buf_phys); // tx_buf_phys and rx_buf_phys must be page aligned to n*4096...
    if (tx_buf_virt == MAP_FAILED || rx_buf_virt == MAP_FAILED) {
        std::cerr << "mmap failed: " << strerror(errno) << std::endl;
        close(mem_fd);
        dma_destroy(dma);
        return;
    }    

    // [DEBUG] Map the DMA control registers into user space
    // volatile unsigned int *dma_regs = (unsigned int *)mmap(
    //     NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, DMA_PHYS_ADDR);  
    // for (int i = 0; i < 8; ++i) {
    //     std::cout << "  Reg[" << i << "] = 0x" << std::hex << dma_regs[i] << std::dec << std::endl;
    // }

    // Prepare buffers
    for(uint32_t i=0; i < TRANSFER_LEN; ++i) tx_buf_virt[i] = i & 0xFF;
    memset(rx_buf_virt, 0, TRANSFER_LEN);
    
    std::cout << "Starting S2MM (Receive) channel..." << std::endl;
    dma_simple_receive(dma, rx_buf_phys, TRANSFER_LEN);

    std::cout << "Starting MM2S (Transmit) channel..." << std::endl;
    dma_simple_transmit(dma, tx_buf_phys, TRANSFER_LEN);

    // Equivalent to:
    // dma_regs[S2MM_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ; // Run + Enable Interrupt on Complete
    // dma_regs[S2MM_DA / 4] = rx_buf_phys;
    // dma_regs[S2MM_LENGTH / 4] = TRANSFER_LEN;
    // dma_regs[MM2S_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ; // Run + Enable Interrupt on Complete
    // dma_regs[MM2S_SA / 4] = tx_buf_phys;
    // dma_regs[MM2S_LENGTH / 4] = TRANSFER_LEN;    


    std::cout << "Waiting for transmit to complete..." << std::endl;
    dma_wait_for_completion(dma, DMA_TRANSMIT);
    std::cout << "Waiting for receive to complete..." << std::endl;
    dma_wait_for_completion(dma, DMA_RECEIVE);

    // Verification
    int errors = 0;
    for(uint32_t i=0; i < TRANSFER_LEN; ++i) {
        if (rx_buf_virt[i] != tx_buf_virt[i]) {
            printf("* Error: [%d]: Tx %d, Rx %d*\n",i, tx_buf_virt[i] & 0xFF, rx_buf_virt[i]);
            errors++;
        }
    }

    std::cout << "Verification complete." << std::endl;
    if (errors == 0) {
        std::cout << "*** SUCCESS: Data verified correctly! ***" << std::endl;
    } else {
        std::cout << "*** FAILURE: " << errors << " data errors detected! ***" << std::endl;
    }

    munmap(tx_buf_virt, TRANSFER_LEN);
    munmap(rx_buf_virt, TRANSFER_LEN);
    close(mem_fd);
    dma_destroy(dma);
}

void run_sg_loopback_test() {
    std::cout << "\n--- Running Scatter-Gather Loopback Test ---" << std::endl;
    AxiDmaHandle_t dma = dma_create_irq(DMA_PHYS_ADDR, MEM_PHYS_ADDR, MEM_SIZE, UIO_DEVICE_S2MM, UIO_DEVICE_MM2S);
    if (!dma) return;

    const int NUM_BLOCKS = 8;
    const int BLOCK_SIZE = 8*1024;

    // Initialize both channels for SG mode
    dma_init_channel(dma, DMA_MODE_SG, DMA_MODE_SG, NUM_BLOCKS, BLOCK_SIZE);

    // Start the receiver first so it's ready for data
    dma_start(dma, DMA_TRANSMIT);
    dma_start(dma, DMA_RECEIVE);
    std::cout << "Receive channel started." << std::endl;

    // Prepare and submit transmit blocks
    int tx_length = BLOCK_SIZE*NUM_BLOCKS;
    std::vector<uint8_t> test_data(BLOCK_SIZE*NUM_BLOCKS);
    for (int i = 0; i < NUM_BLOCKS; ++i) {
        // Create a unique pattern for each block
        for(int j = 0; j < BLOCK_SIZE; ++j) {
            test_data[j + i*BLOCK_SIZE] = (uint8_t)(i + j);
        }
    }
    std::cout << "Submitting transmit blocks" << std::endl;
    while (dma_submit_transmit_block(dma, test_data.data(), tx_length) == 0) {
        // This loop will spin if the DMA transmit ring is full,
        // which shouldn't happen in this simple test.
        usleep(1000);
    }    
    std::cout << "Transmit channel started." << std::endl;

    // Wait for and verify received blocks
    int total_errors = 0;
    for (int i = 0; i < NUM_BLOCKS; ++i) {
        void* data_ptr = nullptr;
        uint32_t len = 0;
        int result = dma_get_completed_block(dma, DMA_RECEIVE, &data_ptr, &len);

        if (result > 0) {
            std::cout << "Received block #" << i << " with length " << len << std::endl;
            // Verify data
            bool ok = true;
            uint8_t* rx_data = static_cast<uint8_t*>(data_ptr);
            for(uint32_t j = 0; j < len; ++j) {
                if (rx_data[j] != (uint8_t)(i + j)) {
                    ok = false;
                    total_errors++;
                    // printf("* Error: [%d]: Tx %d, Rx %d*\n",j, (i+j) & 0xFF, rx_data[j]);
                }
                else{
                    // printf("* Correct: [%d]: Tx %d, Rx %d*\n",j, (i+j) & 0xFF, rx_data[j]);
                }
            }
            std::cout << "  Verification: " << (ok ? "PASS" : "FAIL")<< ", total errors "<< total_errors << std::endl;

            dma_release_completed_block(dma, DMA_RECEIVE);
        } else {
            std::cerr << "Error receiving block." << std::endl;
            total_errors++;
            break;
        }
    }
    
    if (total_errors == 0) {
        std::cout << "\n*** SG Test SUCCESS ***" << std::endl;
    } else {
        std::cout << "\n*** SG Test FAILURE ***" << std::endl;
    }

    dma_destroy(dma);
}


int main() {
    // run_direct_register_loopback_test();
    run_sg_loopback_test();
    return 0;
}