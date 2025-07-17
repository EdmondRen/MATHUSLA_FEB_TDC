

// =================================================================================
// FILE: axi_dma_api.h
//
// DESCRIPTION:
// Public C-style API header for the AXI DMA library. This is the file that
// end-user applications should include. It provides a stable, compatible
// interface that hides the underlying C++ implementation.
//
// =================================================================================
#ifndef AXI_DMA_API_H
#define AXI_DMA_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the C++ DMA controller object
typedef struct AxiDmaController* AxiDmaHandle_t;

typedef enum {
    DMA_TRANSMIT, // MM2S
    DMA_RECEIVE   // S2MM
} DmaDirection_e;

typedef enum {
    DMA_MODE_SG,
    DMA_MODE_CYCLIC
} DmaMode_e;


/**
 * @brief Creates and initializes a DMA controller instance.
 * @param uio_dev_path Path to the UIO device, e.g., "/dev/uio0".
 * @param dma_phys_addr Physical base address of the AXI DMA's control registers.
 * @param mem_phys_addr Physical base address of the reserved memory region for buffers.
 * @param mem_size Total size of the reserved memory region.
 * @return A handle to the DMA controller, or NULL on failure.
 */
AxiDmaHandle_t dma_create(uint64_t dma_phys_addr, uint64_t mem_phys_addr, uint64_t mem_size);


/**
 * @brief Creates and initializes a DMA controller instance.
 * @param dma_phys_addr Physical base address of the AXI DMA's control registers.
 * @param mem_phys_addr Physical base address of the reserved memory region for buffers.
 * @param mem_size Total size of the reserved memory region.
 * @param uio_mm2s Path to the UIO device for uio_mm2s, e.g., "/dev/uio0".
 * @param uio_s2mm Path to the UIO device for uio_s2mm, e.g., "/dev/uio1".
 * @return A handle to the DMA controller, or NULL on failure.
 */
AxiDmaHandle_t dma_create_irq(uint64_t dma_phys_addr, uint64_t mem_phys_addr, uint64_t mem_size, const char* uio_mm2s, const char* uio_s2mm);

/**
 * @brief Destroys a DMA controller instance and releases all resources.
 * @param handle The handle returned by dma_create.
 */
void dma_destroy(AxiDmaHandle_t handle);


/**
 * @brief Reset a DMA controller instance.
 * @param handle The handle returned by dma_create.
 */
void dma_reset(AxiDmaHandle_t handle);

/**
 * @brief Initializes a DMA channel for Scatter-Gather or Cyclic mode.
 * @param handle The DMA handle.
 * @param dir The direction (DMA_TRANSMIT or DMA_RECEIVE).
 * @param mode The mode (DMA_MODE_SG or DMA_MODE_CYCLIC).
 * @param num_bds The number of buffer descriptors to create in the ring.
 * @param buffer_size The size of each data buffer associated with a descriptor.
 * @return 0 on success, -1 on failure.
 */
int dma_init_channel(AxiDmaHandle_t handle, DmaMode_e mode_mm2s, DmaMode_e mode_s2mm, uint32_t num_bds, uint32_t buffer_size);

/**
 * @brief Starts a DMA channel.
 * @param handle The DMA handle.
 * @param dir The direction to start.
 */
void dma_start(AxiDmaHandle_t handle, DmaDirection_e dir);

/**
 * @brief Performs a simple one-shot transmit transfer in Direct Register Mode.
 * @param handle The DMA handle.
 * @param tx_addr The physical source address in memory.
 * @param len The number of bytes to transmit.
 * @return 0 on success, -1 on failure.
 */
int dma_simple_transmit(AxiDmaHandle_t handle, uint64_t tx_addr, uint32_t len);

/**
 * @brief Performs a simple one-shot receive transfer in Direct Register Mode.
 * @param handle The DMA handle.
 * @param rx_addr The physical destination address in memory.
 * @param len The number of bytes to receive.
 * @return 0 on success, -1 on failure.
 */
int dma_simple_receive(AxiDmaHandle_t handle, uint64_t rx_addr, uint32_t len);

/**
 * @brief Waits for a simple transfer to complete on a specific channel.
 * @param handle The DMA handle.
 * @param dir The direction to wait for.
 * @return 0 on success, -1 on failure.
 */
int dma_wait_for_completion(AxiDmaHandle_t handle, DmaDirection_e dir);

/**
 * @brief Waits for and retrieves the next completed data block from a channel.
 * This is a blocking call.
 * @param handle The DMA handle.
 * @param dir The direction to check.
 * @param data_ptr A pointer that will be filled with the address of the data buffer.
 * @param len A pointer that will be filled with the number of bytes received/transmitted.
 * @return 1 if a block was successfully retrieved, 0 if a spurious interrupt occurred, -1 on error.
 */
int dma_get_completed_block(AxiDmaHandle_t handle, DmaDirection_e dir, void** data_ptr, uint32_t* len);

/**
 * @brief Waits for the next transmit block to complete in SG mode (does not return data pointer or length).
 * This is a blocking call (polling or interrupt based).
 * @param handle The DMA handle.
 * @return 1 if a block was completed, 0 if not, -1 on error.
 */
int dma_wait_for_transmit_completion_sg(AxiDmaHandle_t handle);

/**
 * @brief Releases a processed block, making its buffer available to the DMA again.
 * @param handle The DMA handle.
 * @param dir The direction to release the block for.
 */
void dma_release_completed_block(AxiDmaHandle_t handle, DmaDirection_e dir);

/**
 * @brief Submits a block of data for transmission.
 * @param handle The DMA handle.
 * @param data_ptr Pointer to the data to transmit.
 * @param len Number of bytes to transmit.
 * @return 1 on success, 0 if no free buffers are available, -1 on error.
 */
int dma_submit_transmit_block(AxiDmaHandle_t handle, const void* data_ptr, uint32_t len);


#ifdef __cplusplus
}
#endif

#endif // AXI_DMA_API_H