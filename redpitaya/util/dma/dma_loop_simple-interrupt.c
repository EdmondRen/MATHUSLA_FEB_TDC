/*
Testing DMA with interupt
  DMA is configured as direct register access mode
*/
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>

// Physical memory addresses from the device tree
#define DMA_PHYS_ADDR   0x40400000
#define DMA_MEM_RANGE   0x10000

#define MEM_PHYS_ADDR   0x1000000 // Must match reserved-memory in device tree
#define MEM_SIZE        (2 * 1024 * 1024) // 2MB, must match reserved-memory

// DMA Register Offsets
#define MM2S_DMACR      0x00
#define MM2S_DMASR      0x04
#define MM2S_SA         0x18
#define MM2S_LENGTH     0x28

#define S2MM_DMACR      0x30
#define S2MM_DMASR      0x34
#define S2MM_DA         0x48
#define S2MM_LENGTH     0x58

// DMA Control Register bits
#define DMA_CR_RUN      0x01
#define DMA_CR_RESET    0x04
#define DMA_CR_IOC_IRQ  0x1000

// DMA Status Register bits
#define DMA_SR_HALTED   0x01
#define DMA_SR_IDLE     0x02
#define DMA_SR_IOC_IRQ  0x1000

#define TRANSFER_SIZE   (2 * 1024) // 0.5MB for the test

int main() {
    printf("--- Starting AXI DMA Loopback Test under Linux ---\n");

    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) {
        perror("Failed to open /dev/mem");
        return -1;
    }

    // Map the DMA control registers into user space
    volatile unsigned int *dma_regs = (unsigned int *)mmap(
        NULL, DMA_MEM_RANGE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, DMA_PHYS_ADDR);
    if (dma_regs == MAP_FAILED) {
        perror("Failed to mmap DMA registers");
        close(mem_fd);
        return -1;
    }

    // Map the reserved memory region for DMA buffers
    unsigned char *dma_buffer = (unsigned char *)mmap(
        NULL, MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, MEM_PHYS_ADDR);
    if (dma_buffer == MAP_FAILED) {
        perror("Failed to mmap DMA buffer memory");
        munmap((void*)dma_regs, DMA_MEM_RANGE);
        close(mem_fd);
        return -1;
    }

    printf("Successfully mapped DMA registers and buffer memory.\n");

    // --- Open UIO device for interrupt handling ---
    int uio_fd = open("/dev/uio1", O_RDWR);
    int uio_fd_s = open("/dev/uio2", O_RDWR);
    if (uio_fd < 0) {
        perror("Failed to open /dev/uio0");
        munmap((void*)dma_regs, DMA_MEM_RANGE);
        munmap(dma_buffer, MEM_SIZE);
        close(mem_fd);
        return -1;
    }

    // Define source (Tx) and destination (Rx) buffers within the reserved memory
    unsigned char *tx_buffer = dma_buffer;
    unsigned char *rx_buffer = dma_buffer + TRANSFER_SIZE;
    
    // Physical addresses for the DMA
    unsigned int tx_phys_addr = MEM_PHYS_ADDR;
    unsigned int rx_phys_addr = MEM_PHYS_ADDR + TRANSFER_SIZE;

    // --- Prepare Buffers ---
    printf("Preparing data buffers...\n");
    // Fill Tx buffer with a pattern
    for (int i = 0; i < TRANSFER_SIZE; i++) {
        tx_buffer[i] = i & 0xFF;
    }
    // Clear Rx buffer
    memset(rx_buffer, 0, TRANSFER_SIZE);


    // --- DMA Setup and Transfer ---
    printf("Resetting DMA...\n");
    dma_regs[S2MM_DMACR / 4] = DMA_CR_RESET;
    dma_regs[MM2S_DMACR / 4] = DMA_CR_RESET;
    while((dma_regs[S2MM_DMASR / 4] & DMA_SR_HALTED) == 0 || (dma_regs[MM2S_DMASR / 4] & DMA_SR_HALTED) == 0) {
        // Wait for reset to complete
    }
    printf("DMA Reset Complete.\n");

    // Start the S2MM (receive) channel
    // dma_regs[S2MM_DMACR / 4] = DMA_CR_RUN; // Run + Enable Interrupt on Complete
    dma_regs[S2MM_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ; // Run + Enable Interrupt on Complete
    dma_regs[S2MM_DA / 4] = rx_phys_addr;
    dma_regs[S2MM_LENGTH / 4] = TRANSFER_SIZE;
    printf("S2MM (Receive) channel started.\n");

    // Start the MM2S (transmit) channel
    // dma_regs[MM2S_DMACR / 4] = DMA_CR_RUN; // Run + Enable Interrupt on Complete
    dma_regs[MM2S_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ; // Run + Enable Interrupt on Complete
    dma_regs[MM2S_SA / 4] = tx_phys_addr;
    dma_regs[MM2S_LENGTH / 4] = TRANSFER_SIZE;
    printf("MM2S (Transmit) channel started. Transfer in progress...\n");

    // --- Wait for Completion using Interrupt ---
    printf("Waiting for DMA completion interrupt...\n");
    unsigned int irq_count;
    ssize_t nbytes;
    // Wait for S2MM interrupt
    nbytes = read(uio_fd, &irq_count, sizeof(irq_count));
    if (nbytes != sizeof(irq_count)) {
        perror("Failed to read UIO interrupt");
        // Cleanup
        close(uio_fd);
        munmap((void*)dma_regs, DMA_MEM_RANGE);
        munmap(dma_buffer, MEM_SIZE);
        close(mem_fd);
        return -1;
    }
    printf("DMA transfer complete (interrupt received).\n");

    // Acknowledge the interrupts
    dma_regs[S2MM_DMASR / 4] = DMA_SR_IOC_IRQ;
    dma_regs[MM2S_DMASR / 4] = DMA_SR_IOC_IRQ;
    // Re-enable the interrupt in UIO (write any value)
    unsigned int reenable = 1;
    write(uio_fd, &reenable, sizeof(reenable));
    // write(uio_fd_s, &reenable, sizeof(reenable));

    // --- Verification ---
    printf("Verifying data...\n");
    int errors = 0;
    for (int i = 0; i < TRANSFER_SIZE; i++) {
        if (rx_buffer[i] != (i & 0xFF)) {
            printf("* Error: [%d]: Tx %d, Rx %d*\n",i, i & 0xFF, rx_buffer[i]);
            errors++;
        }
    }

    if (errors == 0) {
        printf("\n*** SUCCESS: Data verified correctly! ***\n");
    } else {
        printf("\n*** FAILURE: %d data errors detected! ***\n", errors);
    }


    // --- Check and clear any remaining interrupt bits in DMA status registers ---
    unsigned int s2mm_status = dma_regs[S2MM_DMASR / 4];
    unsigned int mm2s_status = dma_regs[MM2S_DMASR / 4];
    printf("S2MM DMA Status Register: 0x%08X\n", s2mm_status);
    printf("MM2S DMA Status Register: 0x%08X\n", mm2s_status);
    if ((s2mm_status & 0xFFFF0000) || (mm2s_status & 0xFFFF0000) ||
        (s2mm_status & (DMA_SR_IOC_IRQ)) || (mm2s_status & (DMA_SR_IOC_IRQ))) {
        printf("Clearing all interrupt bits in DMA status registers...\n");
        dma_regs[S2MM_DMASR / 4] = 0xFFFFFFFF;
        dma_regs[MM2S_DMASR / 4] = 0xFFFFFFFF;
        printf("S2MM DMA Status Register after clear: 0x%08X\n", dma_regs[S2MM_DMASR / 4]);
        printf("MM2S DMA Status Register after clear: 0x%08X\n", dma_regs[MM2S_DMASR / 4]);
    }    

    // --- Cleanup ---
    close(uio_fd);
    munmap((void*)dma_regs, DMA_MEM_RANGE);
    munmap(dma_buffer, MEM_SIZE);
    close(mem_fd);

    return 0;
}
