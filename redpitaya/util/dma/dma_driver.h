#ifndef DMA_DRIVER_H
#define DMA_DRIVER_H

#include <stdint.h>
#include <stddef.h>

// --- Register Offsets and Bit Definitions ---
#define DMA_MM2S_DMACR      0x00
#define DMA_MM2S_DMASR      0x04
#define DMA_MM2S_SA         0x18
#define DMA_MM2S_LENGTH     0x28
#define DMA_MM2S_CURDESC      0x08
#define DMA_MM2S_TAILDESC     0x10

#define DMA_S2MM_DMACR      0x30
#define DMA_S2MM_DMASR      0x34
#define DMA_S2MM_DA         0x48
#define DMA_S2MM_LENGTH     0x58
#define DMA_S2MM_CURDESC      0x38
#define DMA_S2MM_TAILDESC     0x40

#define DMA_CR_RUN          0x01
#define DMA_CR_RESET        0x04
#define DMA_CR_IOC_IRQ      0x1000

#define DMA_SR_HALTED       0x01
#define DMA_SR_IDLE         0x02
#define DMA_SR_IOC_IRQ      0x1000
#define DMA_SR_ERR_MASK     0xF000

#define DMA_SG_DESC_SIZE    0x40
#define DMA_SG_DESC_ALIGN   0x40

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    DMA_MODE_DIRECT = 0,
    DMA_MODE_SG = 1
} dma_mode_t;

typedef struct {
    int mem_fd;
    int uio_fd;
    volatile uint32_t *regs;
    uint8_t *dma_buffer;
    size_t dma_buffer_size;
    uint32_t dma_phys_addr;
    dma_mode_t mode;
    // SG mode
    uint8_t *sg_desc_virt;
    uint32_t sg_desc_phys;
    size_t sg_desc_count;
    size_t dma_reg_range; // Store register region size
} dma_handle_t;

// SG Descriptor Structure (AXI DMA)
typedef struct {
    uint32_t next_desc;
    uint32_t next_desc_msb;
    uint32_t buffer_addr;
    uint32_t buffer_addr_msb;
    uint32_t control;
    uint32_t status;
    uint32_t app[5];
} __attribute__((packed, aligned(64))) dma_sg_desc_t;

/**
 * Initialize the DMA handle and map resources.
 * @param handle Pointer to dma_handle_t
 * @param uio_path Path to UIO device (e.g. "/dev/uio0")
 * @param dma_phys_addr Physical address of DMA registers
 * @param dma_range Size of DMA register region
 * @param buf_phys_addr Physical address of DMA buffer
 * @param buf_size Size of DMA buffer
 * @param mode DMA_MODE_DIRECT or DMA_MODE_SG
 * @return 0 on success, -1 on failure
 */
int dma_init(dma_handle_t *handle, const char *uio_path, uint32_t dma_phys_addr, size_t dma_range, uint32_t buf_phys_addr, size_t buf_size, dma_mode_t mode);

/**
 * Cleanup and unmap all resources.
 */
void dma_cleanup(dma_handle_t *handle);

/**
 * Reset the DMA engine and clear status.
 * @return 0 on success, -1 on timeout
 */
int dma_reset(dma_handle_t *handle);

/**
 * Setup DMA buffers and (optionally) SG descriptors.
 * @param transfer_size Size of transfer in bytes
 * @param use_sg 1 to setup SG, 0 for direct
 * @return 0 on success
 */
int dma_setup_buffers(dma_handle_t *handle, size_t transfer_size, int use_sg);

/**
 * Start a DMA transfer.
 * @param tx_offset Offset in buffer for Tx (MM2S)
 * @param rx_offset Offset in buffer for Rx (S2MM)
 * @param transfer_size Size of transfer in bytes
 * @return 0 on success
 */
int dma_start_transfer(dma_handle_t *handle, uint32_t tx_offset, uint32_t rx_offset, size_t transfer_size);

/**
 * Wait for DMA completion interrupt (UIO).
 * @return 0 on success, -1 on error
 */
int dma_wait_interrupt(dma_handle_t *handle);

/**
 * Clear DMA and UIO interrupts.
 */
void dma_clear_interrupts(dma_handle_t *handle);

/**
 * Get DMA status register.
 * @param s2mm 1 for S2MM, 0 for MM2S
 * @return Status register value
 */
uint32_t dma_get_status(dma_handle_t *handle, int s2mm);

#ifdef __cplusplus
}
#endif

#endif // DMA_DRIVER_H 