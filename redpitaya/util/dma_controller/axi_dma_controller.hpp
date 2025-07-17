// =================================================================================
// FILE: axi_dma_controller.hpp
//
// DESCRIPTION:
// C++ class definition for the AXI DMA Controller. This header defines the
// internal implementation and is not meant for direct use by end-applications.
// End-users should use the C API defined in `axi_dma_api.h`.
//
// =================================================================================
#ifndef AXI_DMA_CONTROLLER_HPP
#define AXI_DMA_CONTROLLER_HPP

#include <cstdint>
#include <string>
#include <vector>
#include <stdexcept>

// Forward declaration of the Buffer Descriptor structure
struct AxiDmaBufferDescriptor;

class AxiDmaController {
public:
    enum class DmaDirection {
        TRANSMIT, // Memory-Mapped to Stream (MM2S)
        RECEIVE   // Stream to Memory-Mapped (S2MM)
    };

    enum class DmaMode {
        UNINITIALIZED,
        DIRECT_REGISTER,
        SCATTER_GATHER,
        CYCLIC
    };

    enum class DmaWaitMode {
        WAIT_POLL,
        WAIT_IRQ
    };    

    // Constructor: Opens devices and maps memory. Throws on error.
    AxiDmaController(uint64_t dma_reg_addr, uint64_t mem_phys_addr, uint64_t mem_size);
    AxiDmaController(uint64_t dma_reg_addr, uint64_t mem_phys_addr, uint64_t mem_size, const std::string& uio_mm2s, const std::string& uio_s2mm);

    // Destructor: Cleans up resources automatically (RAII).
    ~AxiDmaController();
    void reset(DmaDirection dir);
    void stop(DmaDirection dir);    


    // --- Control for Direct Register Mode ---
    void simpleTransmit(uint64_t tx_addr, uint32_t tx_len, bool blocking = false);
    void simpleReceive(uint64_t rx_addr, uint32_t rx_len, bool blocking = false);
    void waitForCompletion(DmaDirection dir);


    // --- Control for SG/Cyclic Modes ----
    void initSG(DmaMode mode_mm2s, DmaMode mode_s2mm, uint32_t num_bds, uint32_t buffer_size);
    // TX
    void startSG(DmaDirection dir);
    int SGTransmitBlock(const void* data_ptr, uint32_t len);
    // RX
    int getCompletedBlock(void** data_ptr, uint32_t* len);
    void releaseBlock(DmaDirection dir);


private:
    void waitForCompletion_poll(DmaDirection dir);
    void waitForCompletion_irq(DmaDirection dir);

    // --- Private Members ---
    DmaWaitMode WAIT_METHOD;

    int m_uio_mm2s_fd = -1;
    int m_uio_s2mm_fd = -1;
    int m_mem_fd = -1;
    
    // Memory mapped regions
    volatile uint32_t* m_dma_regs = nullptr;
    volatile uint8_t* m_mem_region = nullptr;
    uint64_t virt_tx_buf;
    uint64_t virt_rx_buf;
    uint64_t m_mem_size;

    // Physical addresses
    uint64_t m_dma_regs_addr;
    uint64_t m_mem_phys_addr;
    uint64_t phys_addr_tx_bd;
    uint64_t phys_addr_tx_buf;    
    uint64_t phys_addr_rx_bd;
    uint64_t phys_addr_rx_buf;


    // Channel-specific state
    struct DmaChannel {
        DmaMode mode = DmaMode::UNINITIALIZED;
        uint32_t num_bds = 0;
        uint32_t buffer_size_per_bd = 0;
        uint64_t buffer_phys_address;
        volatile AxiDmaBufferDescriptor* bd_chain = nullptr;
        int head_idx = 0;
        int tail_idx = 0;
        uint64_t bd_chain_phys_addr = 0;
    };

    DmaChannel m_mm2s_channel;
    DmaChannel m_s2mm_channel;

    // Private helper methods
    void resetIRQ(DmaDirection dir);
    void setupBdChain(DmaChannel& channel);
    void checkDmaErrors();
    void checkDmaStatus();
};

#endif // AXI_DMA_CONTROLLER_HPP

