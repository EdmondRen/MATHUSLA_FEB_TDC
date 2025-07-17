/*
 * AXI DMA Driver Library (User-space, Linux, UIO)
 * Supports Direct Register Access and Scatter-Gather (SG) Mode
 *
 * Usage:
 *   - Initialize with dma_init()
 *   - Setup buffers with dma_setup_buffers()
 *   - Start transfer with dma_start_transfer()
 *   - Wait for completion with dma_wait_interrupt()
 *   - Cleanup with dma_cleanup()
 *
 * Author: (Your Name)
 */

#include "dma_driver.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>

// --- Implementation ---

int dma_init(dma_handle_t *handle, const char *uio_path, uint32_t dma_phys_addr, size_t dma_range, uint32_t buf_phys_addr, size_t buf_size, dma_mode_t mode) {
    handle->mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (handle->mem_fd < 0) {
        perror("Failed to open /dev/mem");
        return -1;
    }
    handle->uio_fd = open(uio_path, O_RDWR);
    if (handle->uio_fd < 0) {
        perror("Failed to open UIO device");
        close(handle->mem_fd);
        return -1;
    }
    handle->regs = (volatile uint32_t *)mmap(NULL, dma_range, PROT_READ | PROT_WRITE, MAP_SHARED, handle->mem_fd, dma_phys_addr);
    if (handle->regs == MAP_FAILED) {
        perror("Failed to mmap DMA registers");
        close(handle->uio_fd);
        close(handle->mem_fd);
        return -1;
    }
    handle->dma_buffer = (uint8_t *)mmap(NULL, buf_size, PROT_READ | PROT_WRITE, MAP_SHARED, handle->mem_fd, buf_phys_addr);
    if (handle->dma_buffer == MAP_FAILED) {
        perror("Failed to mmap DMA buffer");
        munmap((void*)handle->regs, dma_range);
        close(handle->uio_fd);
        close(handle->mem_fd);
        return -1;
    }
    handle->dma_buffer_size = buf_size;
    handle->dma_phys_addr = buf_phys_addr;
    handle->mode = mode;
    handle->sg_desc_virt = NULL;
    handle->sg_desc_phys = 0;
    handle->sg_desc_count = 0;
    handle->dma_reg_range = dma_range;
    return 0;
}

void dma_cleanup(dma_handle_t *handle) {
    if (handle->regs) munmap((void*)handle->regs, handle->dma_reg_range);
    if (handle->dma_buffer) munmap(handle->dma_buffer, handle->dma_buffer_size);
    if (handle->uio_fd >= 0) close(handle->uio_fd);
    if (handle->mem_fd >= 0) close(handle->mem_fd);
    handle->regs = NULL;
    handle->dma_buffer = NULL;
    handle->uio_fd = -1;
    handle->mem_fd = -1;
}

int dma_reset(dma_handle_t *handle) {
    handle->regs[DMA_S2MM_DMACR / 4] = DMA_CR_RESET;
    handle->regs[DMA_MM2S_DMACR / 4] = DMA_CR_RESET;
    // Wait for reset to complete
    int timeout = 1000000;
    while (((handle->regs[DMA_S2MM_DMASR / 4] & DMA_SR_HALTED) == 0 ||
            (handle->regs[DMA_MM2S_DMASR / 4] & DMA_SR_HALTED) == 0) && --timeout) {
        ;
    }
    if (timeout == 0) {
        fprintf(stderr, "DMA reset timeout!\n");
        return -1;
    }
    // Clear all status bits
    handle->regs[DMA_S2MM_DMASR / 4] = 0xFFFFFFFF;
    handle->regs[DMA_MM2S_DMASR / 4] = 0xFFFFFFFF;
    return 0;
}

int dma_setup_buffers(dma_handle_t *handle, size_t transfer_size, int use_sg) {
    if (use_sg && handle->mode == DMA_MODE_SG) {
        // Setup separate SG descriptors for MM2S and S2MM
        dma_sg_desc_t *mm2s_desc = (dma_sg_desc_t *)handle->dma_buffer;
        dma_sg_desc_t *s2mm_desc = (dma_sg_desc_t *)(handle->dma_buffer + DMA_SG_DESC_SIZE);
        uint32_t mm2s_desc_phys = handle->dma_phys_addr;
        uint32_t s2mm_desc_phys = handle->dma_phys_addr + DMA_SG_DESC_SIZE;
        uint32_t mm2s_buf_phys = handle->dma_phys_addr + 2 * DMA_SG_DESC_SIZE;
        uint32_t s2mm_buf_phys = mm2s_buf_phys + transfer_size;
        // MM2S descriptor
        memset(mm2s_desc, 0, sizeof(dma_sg_desc_t));
        mm2s_desc->next_desc = 0;
        mm2s_desc->buffer_addr = mm2s_buf_phys;
        mm2s_desc->control = transfer_size;
        mm2s_desc->status = 0;
        // S2MM descriptor
        memset(s2mm_desc, 0, sizeof(dma_sg_desc_t));
        s2mm_desc->next_desc = 0;
        s2mm_desc->buffer_addr = s2mm_buf_phys;
        s2mm_desc->control = transfer_size;
        s2mm_desc->status = 0;
        // Save for use in dma_start_transfer
        handle->sg_desc_virt = handle->dma_buffer;
        handle->sg_desc_phys = handle->dma_phys_addr;
        handle->sg_desc_count = 2;
        // Debug prints
        // printf("[dma_setup_buffers] MM2S desc @ 0x%08X\n", mm2s_desc_phys);
        // printf("  next_desc: 0x%08X\n", mm2s_desc->next_desc);
        // printf("  buffer_addr: 0x%08X\n", mm2s_desc->buffer_addr);
        // printf("  control: 0x%08X\n", mm2s_desc->control);
        // printf("  status: 0x%08X\n", mm2s_desc->status);
        // printf("[dma_setup_buffers] S2MM desc @ 0x%08X\n", s2mm_desc_phys);
        // printf("  next_desc: 0x%08X\n", s2mm_desc->next_desc);
        // printf("  buffer_addr: 0x%08X\n", s2mm_desc->buffer_addr);
        // printf("  control: 0x%08X\n", s2mm_desc->control);
        // printf("  status: 0x%08X\n", s2mm_desc->status);
        // printf("[dma_setup_buffers] MM2S data buffer @ 0x%08X\n", mm2s_buf_phys);
        // printf("[dma_setup_buffers] S2MM data buffer @ 0x%08X\n", s2mm_buf_phys);
    }
    // For direct mode, nothing to do (user fills buffer directly)
    return 0;
}

int dma_start_transfer(dma_handle_t *handle, uint32_t tx_offset, uint32_t rx_offset, size_t transfer_size) {
    if (handle->mode == DMA_MODE_SG) {
        // Use separate descriptors for MM2S and S2MM
        uint32_t mm2s_desc_phys = handle->dma_phys_addr;
        uint32_t s2mm_desc_phys = handle->dma_phys_addr + DMA_SG_DESC_SIZE;
        // Print status before starting
        // printf("[dma_start_transfer] Before start: MM2S_DMASR: 0x%08X\n", handle->regs[DMA_MM2S_DMASR / 4]);
        // printf("[dma_start_transfer] Before start: S2MM_DMASR: 0x%08X\n", handle->regs[DMA_S2MM_DMASR / 4]);
        // S2MM
        handle->regs[DMA_S2MM_CURDESC / 4] = s2mm_desc_phys;
        handle->regs[DMA_S2MM_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ;
        handle->regs[DMA_S2MM_TAILDESC / 4] = s2mm_desc_phys;        
        // MM2S
        handle->regs[DMA_MM2S_CURDESC / 4] = mm2s_desc_phys;
        handle->regs[DMA_MM2S_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ;
        handle->regs[DMA_MM2S_TAILDESC / 4] = mm2s_desc_phys;
        // Print status after starting
        // printf("[dma_start_transfer] After start: MM2S_DMASR: 0x%08X\n", handle->regs[DMA_MM2S_DMASR / 4]);
        // printf("[dma_start_transfer] After start: S2MM_DMASR: 0x%08X\n", handle->regs[DMA_S2MM_DMASR / 4]);
    } else {
        // Direct register mode
        handle->regs[DMA_S2MM_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ;
        handle->regs[DMA_S2MM_DA / 4] = handle->dma_phys_addr + rx_offset;
        handle->regs[DMA_S2MM_LENGTH / 4] = transfer_size;
        handle->regs[DMA_MM2S_DMACR / 4] = DMA_CR_RUN | DMA_CR_IOC_IRQ;
        handle->regs[DMA_MM2S_SA / 4] = handle->dma_phys_addr + tx_offset;
        handle->regs[DMA_MM2S_LENGTH / 4] = transfer_size;
    }
    return 0;
}

int dma_wait_interrupt(dma_handle_t *handle) {
    unsigned int irq_count;
    ssize_t nbytes = read(handle->uio_fd, &irq_count, sizeof(irq_count));
    if (nbytes != sizeof(irq_count)) {
        perror("Failed to read UIO interrupt");
        return -1;
    }
    return 0;
}

void dma_clear_interrupts(dma_handle_t *handle) {
    handle->regs[DMA_S2MM_DMASR / 4] = DMA_SR_IOC_IRQ;
    handle->regs[DMA_MM2S_DMASR / 4] = DMA_SR_IOC_IRQ;
    unsigned int reenable = 1;
    (void)write(handle->uio_fd, &reenable, sizeof(reenable));
}

uint32_t dma_get_status(dma_handle_t *handle, int s2mm) {
    if (s2mm)
        return handle->regs[DMA_S2MM_DMASR / 4];
    else
        return handle->regs[DMA_MM2S_DMASR / 4];
}
