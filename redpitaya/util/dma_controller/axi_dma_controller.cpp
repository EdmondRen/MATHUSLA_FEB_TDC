// =================================================================================
// FILE: axi_dma_controller.cpp
//
// DESCRIPTION:
// C++ implementation of the AxiDmaController class. Contains all the core
// logic for interacting with the DMA hardware.
//
// =================================================================================
#include "axi_dma_controller.hpp"
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <stdexcept>
#include <iostream>

// --- AXI DMA Register Offsets ---
constexpr uint32_t DMA_REG_SIZE = 0x10000;
constexpr uint32_t MM2S_DMACR = 0x00;
constexpr uint32_t MM2S_DMASR = 0x04;
constexpr uint32_t MM2S_SA = 0x18;
constexpr uint32_t MM2S_SA_MSB = 0x1C;
constexpr uint32_t MM2S_LENGTH = 0x28;
constexpr uint32_t MM2S_CURDESC = 0x08;
constexpr uint32_t MM2S_TAILDESC = 0x10;

constexpr uint32_t S2MM_DMACR = 0x30;
constexpr uint32_t S2MM_DMASR = 0x34;
constexpr uint32_t S2MM_DA = 0x48;
constexpr uint32_t S2MM_DA_MSB = 0x4C;
constexpr uint32_t S2MM_LENGTH = 0x58;
constexpr uint32_t S2MM_CURDESC = 0x38;
constexpr uint32_t S2MM_TAILDESC = 0x40;

// --- DMA Control/Status Register Bits ---
constexpr uint32_t DMA_CR_RUN_STOP_MASK = 0x00000001;
constexpr uint32_t DMA_CR_RESET_MASK = 0x00000004;
constexpr uint32_t DMA_CR_IOC_IRQ_EN_MASK = 0x00001000;
constexpr uint32_t DMA_CR_ERR_IRQ_EN_MASK = 0x00004000;
constexpr uint32_t DMA_CR_CYCLIC_EN_MASK = 0x00000010;

constexpr uint32_t DMA_SR_HALTED_MASK = 0x00000001;
constexpr uint32_t DMA_SR_IDLE_MASK = 0x00000002;
constexpr uint32_t DMA_SR_IOC_IRQ_MASK = 0x00001000;
constexpr uint32_t DMA_SR_ERR_IRQ_MASK = 0x00004000;
constexpr uint32_t DMA_SR_ALL_ERR_MASK = 0x00000070;

// --- Buffer Descriptor Structure ---
constexpr uint32_t SG_BD_RANGE = 0x2000;
struct AxiDmaBufferDescriptor
{
    uint32_t next_desc_ptr;
    uint32_t next_desc_ptr_MSB;
    uint32_t buffer_addr;
    uint32_t buffer_addr_MSB;
    uint32_t reserved3;
    uint32_t reserved4;
    uint32_t control;
    uint32_t status;
    uint32_t app[5];
    uint32_t unused[3]; // Placeholder to make it aligned to 0x40
};

// --- Class Implementation ---

AxiDmaController::AxiDmaController(uint64_t dma_regs_addr, uint64_t mem_phys_addr, uint64_t mem_size)
    : m_dma_regs_addr(dma_regs_addr), m_mem_phys_addr(mem_phys_addr), m_mem_size(mem_size)
{
    // Use polling since no UIO are provided
    WAIT_METHOD = DmaWaitMode::WAIT_POLL;

    // Open memory device
    // Use non-cached memory with O_SYNC and MAP_SHARED to be coherent with CPU
    m_mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (m_mem_fd < 0)
        throw std::runtime_error("Failed to open /dev/mem device files.");

    // Memory mapped regions
    m_dma_regs = static_cast<volatile uint32_t *>(mmap(NULL, DMA_REG_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, m_mem_fd, m_dma_regs_addr));
    m_mem_region = static_cast<volatile uint8_t *>(mmap(NULL, m_mem_size, PROT_READ | PROT_WRITE, MAP_SHARED, m_mem_fd, m_mem_phys_addr));
    if (m_dma_regs == MAP_FAILED || m_mem_region == MAP_FAILED)
        throw std::runtime_error("Memory mapping failed.");

    phys_addr_tx_buf = phys_addr_tx_bd = m_mem_phys_addr;
    phys_addr_rx_buf = phys_addr_rx_bd = m_mem_phys_addr + mem_size / 2;
    virt_tx_buf = (uint64_t)m_mem_region;
    virt_rx_buf = (uint64_t)m_mem_region+ mem_size / 2;

    m_mm2s_channel.mode = DmaMode::DIRECT_REGISTER;
    m_s2mm_channel.mode = DmaMode::DIRECT_REGISTER;
    reset(DmaDirection::TRANSMIT);
    reset(DmaDirection::RECEIVE);
}

AxiDmaController::AxiDmaController(uint64_t dma_regs_addr,
                                   uint64_t mem_phys_addr,
                                   uint64_t mem_size,
                                   const std::string &uio_mm2s,
                                   const std::string &uio_s2mm) : AxiDmaController(dma_regs_addr, mem_phys_addr, mem_size)
{
    // Use interrupt
    WAIT_METHOD = DmaWaitMode::WAIT_IRQ;

    // Open memory device
    m_uio_mm2s_fd = open(uio_mm2s.c_str(), O_RDWR | O_SYNC);
    m_uio_s2mm_fd = open(uio_s2mm.c_str(), O_RDWR | O_SYNC);
    if (m_uio_mm2s_fd < 0 || m_uio_s2mm_fd < 0)
    {
        throw std::runtime_error("Failed to open " + uio_mm2s + " or " + uio_s2mm + " device files.");
    }
    // Clear previous pending interrupts
    resetIRQ(DmaDirection::RECEIVE);
    resetIRQ(DmaDirection::TRANSMIT);
}

AxiDmaController::~AxiDmaController()
{
    // Cleanup: Reset and clear all status bits for both channels to avoid stale IRQs
    stop(DmaDirection::TRANSMIT);
    stop(DmaDirection::RECEIVE);
    m_dma_regs[MM2S_DMASR / 4] = 0xFFFFFFFF;
    m_dma_regs[S2MM_DMASR / 4] = 0xFFFFFFFF;

    // unmap and close file descriptors
    if (m_dma_regs)
        munmap((void *)m_dma_regs, DMA_REG_SIZE);
    if (m_mem_region)
        munmap((void *)m_mem_region, m_mem_size);
    if (m_mem_fd >= 0)
        close(m_mem_fd);
    if (WAIT_METHOD == DmaWaitMode::WAIT_IRQ)
    {
        // Clear previous pending interrupts
        unsigned int reenable = 1;
        ssize_t write_return;
        write_return = write(m_uio_mm2s_fd, &reenable, sizeof(reenable));
        write_return = write(m_uio_s2mm_fd, &reenable, sizeof(reenable));
        (void)write_return;
        if (m_uio_mm2s_fd >= 0)
            close(m_uio_mm2s_fd);
        if (m_uio_s2mm_fd >= 0)
            close(m_uio_s2mm_fd);
    }
}

void AxiDmaController::reset(DmaDirection dir)
{
    uint32_t offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMACR : S2MM_DMACR;
    m_dma_regs[offset / 4] = DMA_CR_RESET_MASK;
    while (m_dma_regs[offset / 4] & DMA_CR_RESET_MASK)
        ;
}

void AxiDmaController::simpleTransmit(uint64_t tx_addr, uint32_t tx_len, bool blocking)
{
    m_dma_regs[MM2S_DMACR / 4] = DMA_CR_RUN_STOP_MASK | DMA_CR_IOC_IRQ_EN_MASK;
    m_dma_regs[MM2S_SA / 4] = tx_addr & 0xFFFFFFFF;
    if (m_dma_regs_addr > 0xFFFFFFFF)
        m_dma_regs[MM2S_SA_MSB / 4] = tx_addr >> 32;
    m_dma_regs[MM2S_LENGTH / 4] = tx_len;

    if (blocking)
    {
        if (WAIT_METHOD == DmaWaitMode::WAIT_POLL)
            waitForCompletion_poll(DmaDirection::TRANSMIT);
        else
            waitForCompletion_irq(DmaDirection::TRANSMIT);
    }
}

void AxiDmaController::simpleReceive(uint64_t rx_addr, uint32_t rx_len, bool blocking)
{
    m_dma_regs[S2MM_DMACR / 4] = DMA_CR_RUN_STOP_MASK | DMA_CR_IOC_IRQ_EN_MASK;
    m_dma_regs[S2MM_DA / 4] = rx_addr & 0xFFFFFFFF;
    if (m_dma_regs_addr > 0xFFFFFFFF)
        m_dma_regs[S2MM_DA_MSB / 4] = rx_addr >> 32;
    m_dma_regs[S2MM_LENGTH / 4] = rx_len;

    if (blocking)
    {
        if (WAIT_METHOD == DmaWaitMode::WAIT_POLL)
            waitForCompletion_poll(DmaDirection::RECEIVE);
        else
            waitForCompletion_irq(DmaDirection::RECEIVE);
    }
}

void AxiDmaController::waitForCompletion(DmaDirection dir)
{
    if (WAIT_METHOD == DmaWaitMode::WAIT_POLL)
        waitForCompletion_poll(dir);
    else
        waitForCompletion_irq(dir);
}

void AxiDmaController::waitForCompletion_poll(DmaDirection dir)
{
    uint32_t dmasr_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMASR : S2MM_DMASR;
    uint32_t status;
    uint32_t count = 0;
    do
    {
        status = m_dma_regs[dmasr_offset / 4];
        count ++;
    } while (!(status & DMA_SR_IOC_IRQ_MASK) && count<0xFFFFFFFF);

    m_dma_regs[dmasr_offset / 4] |= DMA_SR_IOC_IRQ_MASK;
}

void AxiDmaController::waitForCompletion_irq(DmaDirection dir)
{
    uint32_t dmasr_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMASR : S2MM_DMASR;
    int uio_fd = (dir == DmaDirection::TRANSMIT) ? m_uio_mm2s_fd : m_uio_s2mm_fd;

    // Wait for S2MM interrupt
    unsigned int irq_count;
    ssize_t nbytes;
    nbytes = read(uio_fd, &irq_count, sizeof(irq_count));
    if (nbytes != sizeof(irq_count))
        perror("Failed to read UIO interrupt");

    // Acknowledge the interrupts
    m_dma_regs[dmasr_offset / 4] |= DMA_SR_IOC_IRQ_MASK;
    // Re-enable the interrupt in UIO (write any value)
    unsigned int reenable = 1;
    nbytes = write(uio_fd, &reenable, sizeof(reenable));
}

void AxiDmaController::stop(DmaDirection dir)
{
    uint32_t offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMACR : S2MM_DMACR;
    m_dma_regs[offset / 4] &= ~DMA_CR_RUN_STOP_MASK;
}

//-------------------------------------------SG Mode------------------------------------------------------

void AxiDmaController::initSG(DmaMode mode_mm2s, DmaMode mode_s2mm, uint32_t num_bds, uint32_t buffer_size)
{
    reset(DmaDirection::RECEIVE);
    reset(DmaDirection::TRANSMIT);

    phys_addr_tx_buf = phys_addr_tx_bd + SG_BD_RANGE;
    phys_addr_rx_buf = phys_addr_rx_bd + SG_BD_RANGE;
    virt_tx_buf = (uint64_t)m_mem_region + SG_BD_RANGE;
    virt_rx_buf = (uint64_t)m_mem_region + m_mem_size / 2 + SG_BD_RANGE;    

    // --- Robust memory partitioning for BDs and buffers ---
    // 1. The memory region is divided into two halfs
    // | MM2S BDs --> MM2S buffers | S2MM BDs --> S2MM buffers |

    // MM2S BDs: base
    uint64_t mm2s_bd_base_virt = (uint64_t)m_mem_region;
    uint64_t mm2s_bd_base_phys = m_mem_phys_addr;

    // S2MM BDs: after MM2S buffers, at the midpoint of memery range
    uint64_t s2mm_bd_base_virt = mm2s_bd_base_virt + m_mem_size / 2;
    uint64_t s2mm_bd_base_phys = mm2s_bd_base_phys + m_mem_size / 2;

    m_mm2s_channel.mode = mode_mm2s;
    m_mm2s_channel.num_bds = num_bds;
    m_mm2s_channel.buffer_size_per_bd = buffer_size;
    m_mm2s_channel.bd_chain = reinterpret_cast<volatile AxiDmaBufferDescriptor *>(mm2s_bd_base_virt);
    m_mm2s_channel.bd_chain_phys_addr = mm2s_bd_base_phys;
    m_mm2s_channel.buffer_phys_address = phys_addr_tx_buf;
    m_mm2s_channel.head_idx = 0;
    m_mm2s_channel.tail_idx = 0;
    setupBdChain(m_mm2s_channel);

    m_s2mm_channel.mode = mode_s2mm;
    m_s2mm_channel.num_bds = num_bds;
    m_s2mm_channel.buffer_size_per_bd = buffer_size;
    m_s2mm_channel.bd_chain = reinterpret_cast<volatile AxiDmaBufferDescriptor *>(s2mm_bd_base_virt);
    m_s2mm_channel.bd_chain_phys_addr = s2mm_bd_base_phys;
    m_s2mm_channel.buffer_phys_address = phys_addr_rx_buf;
    m_s2mm_channel.head_idx = 0;
    m_s2mm_channel.tail_idx = 0;
    setupBdChain(m_s2mm_channel);

}

void AxiDmaController::setupBdChain(DmaChannel &channel)
{
    for (uint32_t i = 0; i < channel.num_bds; ++i)
    {
        uint64_t next_bd_phys = channel.bd_chain_phys_addr + ((i + 1) % channel.num_bds) * sizeof(AxiDmaBufferDescriptor);
        channel.bd_chain[i].next_desc_ptr = next_bd_phys & 0xFFFFFFFF;
        channel.bd_chain[i].next_desc_ptr_MSB = 0;
        channel.bd_chain[i].buffer_addr = channel.buffer_phys_address + (i * channel.buffer_size_per_bd);
        channel.bd_chain[i].buffer_addr_MSB = 0;
        channel.bd_chain[i].reserved3 = 0;
        channel.bd_chain[i].reserved4 = 0;
        channel.bd_chain[i].control = (channel.buffer_size_per_bd & 0x03FFFFFF); // | (1 << 27) | (1 << 26); // Set length, SOF, EOF
        channel.bd_chain[i].status = 0;
        for (int j = 0; j < 5; ++j)
            channel.bd_chain[i].app[j] = 0;
        // std::cout << "  BD[" << i << "] next_desc_ptr=0x" << std::hex << channel.bd_chain[i].next_desc_ptr
        //           << " buffer_addr=0x" << channel.bd_chain[i].buffer_addr
        //           << " control=0x" << channel.bd_chain[i].control
        //           << " status=0x" << channel.bd_chain[i].status << std::dec << std::endl;
    }
}

void AxiDmaController::startSG(DmaDirection dir)
{
    DmaChannel &channel = (dir == DmaDirection::TRANSMIT) ? m_mm2s_channel : m_s2mm_channel;
    if (channel.mode == DmaMode::SCATTER_GATHER || channel.mode == DmaMode::CYCLIC)
    {
        if (debug_enabled) {
            std::cout << "[DEBUG] Printing all Buffer Descriptors before starting DMA (dir=" << (dir == DmaDirection::TRANSMIT ? "MM2S" : "S2MM") << ")" << std::endl;
            for (uint32_t i = 0; i < channel.num_bds; ++i)
            {
                const volatile AxiDmaBufferDescriptor &bd = channel.bd_chain[i];
                std::cout << "  BD[" << i << "] next_desc_ptr=0x" << std::hex << bd.next_desc_ptr
                          << " buffer_addr=0x" << bd.buffer_addr
                          << " control=0x" << bd.control
                          << " status=0x" << bd.status << std::dec << std::endl;
            }
        }
        uint32_t cr_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMACR : S2MM_DMACR;
        uint32_t curdesc_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_CURDESC : S2MM_CURDESC;
        uint32_t taildesc_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_TAILDESC : S2MM_TAILDESC;

        uint32_t cr_val = DMA_CR_RUN_STOP_MASK | DMA_CR_IOC_IRQ_EN_MASK | DMA_CR_ERR_IRQ_EN_MASK;
        if (channel.mode == DmaMode::CYCLIC)
            cr_val |= DMA_CR_CYCLIC_EN_MASK;
        m_dma_regs[curdesc_offset / 4] = channel.bd_chain_phys_addr & 0xFFFFFFFF;
        m_dma_regs[cr_offset / 4] = cr_val;
        if (dir == DmaDirection::RECEIVE)
            m_dma_regs[taildesc_offset / 4] = channel.bd_chain_phys_addr + (channel.num_bds - 1) * sizeof(AxiDmaBufferDescriptor);
        if (debug_enabled) {
            std::cout<<std::hex<< m_dma_regs[cr_offset / 4]<<std::endl;
            std::cout<<std::hex<< m_dma_regs[curdesc_offset / 4]<<","<<std::hex<< (channel.bd_chain_phys_addr & 0xFFFFFFFF)<<std::endl;
            std::cout<<std::hex<< m_dma_regs[taildesc_offset / 4]<<std::endl;            
            std::cout << "[DEBUG] Set taildesc (offset 0x" << std::hex << taildesc_offset << ") to 0x" << (channel.bd_chain_phys_addr + (channel.num_bds - 1) * sizeof(AxiDmaBufferDescriptor)) << std::dec << std::endl;
        }
    }

    checkDmaStatus();

}

int AxiDmaController::sgTransmit(const void *data_ptr, uint32_t len) {
    DmaChannel &channel = m_mm2s_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return -1;
    if (len == 0) return 0;

    const uint8_t* src = static_cast<const uint8_t*>(data_ptr);
    uint32_t remaining = len;
    uint32_t block_size = channel.buffer_size_per_bd;
    int num_blocks = (len + block_size - 1) / block_size;
    for (int i = 0; i < num_blocks; ++i) {
        uint32_t this_block = (remaining > block_size) ? block_size : remaining;
        bool sof = (i == 0);
        bool eof = (i == num_blocks - 1);
        int ret = prepareTransmitBlock(src + i * block_size, this_block, sof, eof);
        if (ret <= 0) {
            // Not enough free BDs or error
            return ret;
        }
        remaining -= this_block;
    }
    flushTransmit();
    return num_blocks;
}

int AxiDmaController::waitForTransmitCompletionSG() {
    DmaDirection dir = DmaDirection::TRANSMIT;
    DmaChannel& channel = m_mm2s_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return -1; // Invalid mode
    checkDmaStatus();

    // Check if the next BD is already complete
    if (!(channel.bd_chain[channel.tail_idx].status & 0x80000000)) {
        if (WAIT_METHOD == DmaWaitMode::WAIT_POLL) {
            // Poll until complete
            while (!(channel.bd_chain[channel.tail_idx].status & 0x80000000)) {
                // Optionally add a small sleep or yield here
            }
        } else {
            // Wait for IRQ
            uint32_t irq_count;
            ssize_t n = read(m_uio_mm2s_fd, &irq_count, sizeof(irq_count));
            (void)n;
        }
    }

    // If still not complete, return 0
    if (!(channel.bd_chain[channel.tail_idx].status & 0x80000000))
        return 0;

    // Advance tail pointer
    channel.tail_idx = (channel.tail_idx + 1) % channel.num_bds;
    resetIRQ(dir);

    return 1; // Success
}

int AxiDmaController::prepareTransmitBlock(const void* data_ptr, uint32_t len, bool sof, bool eof) {
    DmaChannel& channel = m_mm2s_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return -1;
    // Check if there is a free BD
    if (channel.bd_chain[channel.head_idx].status & 0x80000000)
        return 0; // No free BDs
    // Copy user data to the DMA buffer
    uint64_t buf_address_virt = virt_tx_buf + (channel.head_idx * channel.buffer_size_per_bd);
    void* dma_buffer_virt = (void*)(buf_address_virt);
    memcpy(dma_buffer_virt, data_ptr, len);
    // Prepare the BD (set SOF/EOF as requested)
    uint32_t control = (len & 0x03FFFFFF);
    if (sof) control |= (1 << 27);
    if (eof) control |= (1 << 26);
    channel.bd_chain[channel.head_idx].control = control;
    channel.bd_chain[channel.head_idx].status = 0;
    // Advance head pointer
    channel.head_idx = (channel.head_idx + 1) % channel.num_bds;
    return 1;
}

void AxiDmaController::flushTransmit() {
    DmaChannel& channel = m_mm2s_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return;
    int last_idx = (channel.head_idx + channel.num_bds - 1) % channel.num_bds;
    uint64_t bd_address_phys = phys_addr_tx_bd + (last_idx * sizeof(AxiDmaBufferDescriptor));

    // Check if DMA is halted (idle)
    uint32_t status = m_dma_regs[MM2S_DMASR / 4];
    if (status & DMA_SR_HALTED_MASK) {
        // Set CURDESC to the first BD in the ring (tail_idx)
        int first_idx = channel.tail_idx % channel.num_bds;
        uint64_t first_bd_phys = phys_addr_tx_bd + (first_idx * sizeof(AxiDmaBufferDescriptor));
        m_dma_regs[MM2S_CURDESC / 4] = first_bd_phys & 0xFFFFFFFF;
        // Start DMA
        m_dma_regs[MM2S_DMACR / 4] = DMA_CR_RUN_STOP_MASK | DMA_CR_IOC_IRQ_EN_MASK | DMA_CR_ERR_IRQ_EN_MASK;
    }
    // Always update TAILDESC to notify hardware of new BDs
    m_dma_regs[MM2S_TAILDESC / 4] = bd_address_phys & 0xFFFFFFFF;
}

int AxiDmaController::sgReceive(void **data_ptr, uint32_t *len)
{
    DmaDirection dir = DmaDirection::RECEIVE;
    DmaChannel &channel = (dir == DmaDirection::TRANSMIT) ? m_mm2s_channel : m_s2mm_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return -1; // Invalid mode

    // m_dma_regs[S2MM_TAILDESC / 4] = channel.bd_chain_phys_addr + (channel.num_bds - 1) * sizeof(AxiDmaBufferDescriptor);
    checkDmaStatus();

    // Check if the next BD is already complete
    // std::cout << "[DEBUG] sgReceive: Checking BD status, tail_idx=" << channel.tail_idx << std::endl;
    // std::cout << "[DEBUG] BD status: 0x" << std::hex << channel.bd_chain[channel.tail_idx].status << std::dec << std::endl;
    if (!(channel.bd_chain[channel.tail_idx].status & 0x80000000))
    {
        // std::cout << "[DEBUG] BD not complete, waiting for IRQ..." << std::endl;
        uint32_t irq_count;
        ssize_t n = read(m_uio_s2mm_fd, &irq_count, sizeof(irq_count));
    }

    // Advance tail pointer and release
    // channel.tail_idx = (channel.tail_idx + 1) % channel.num_bds;
    resetIRQ(dir);

    if (!(channel.bd_chain[channel.tail_idx].status & 0x80000000))
    {
        std::cout << "[DEBUG] Still no completed BD after IRQ." << std::endl;
        return 0; // No new block
    }

    // Get the address of received data
    *data_ptr = (void *)(virt_rx_buf + (channel.tail_idx * channel.buffer_size_per_bd));
    *len = channel.bd_chain[channel.tail_idx].status & 0x03FFFFFF;

    // std::cout << "[DEBUG] Completed BD found! len=" << *len << std::endl;
    return 1; // Success
}



void AxiDmaController::releaseBlock(DmaDirection dir)
{
    DmaChannel &channel = (dir == DmaDirection::TRANSMIT) ? m_mm2s_channel : m_s2mm_channel;
    if (channel.mode != DmaMode::SCATTER_GATHER && channel.mode != DmaMode::CYCLIC)
        return;

    channel.bd_chain[channel.tail_idx].status = 0;
    channel.tail_idx = (channel.tail_idx + 1) % channel.num_bds;

    if (channel.mode == DmaMode::SCATTER_GATHER && dir == DmaDirection::RECEIVE)
    {
        // Always keep S2MM_TAILDESC at the last BD in the ring
        uint32_t taildesc_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_TAILDESC : S2MM_TAILDESC;
        int new_tail_idx = (channel.tail_idx + channel.num_bds - 1) % channel.num_bds;
        m_dma_regs[taildesc_offset / 4] = channel.bd_chain_phys_addr + new_tail_idx * sizeof(AxiDmaBufferDescriptor);
    }
}


// ------------------------------------Helper functions-------------------------------------------------------

void AxiDmaController::resetIRQ(DmaDirection dir)
{
    unsigned int reenable = 1;
    ssize_t write_return;

    uint32_t dmasr_offset = (dir == DmaDirection::TRANSMIT) ? MM2S_DMASR : S2MM_DMASR;
    int uid_fd = (dir == DmaDirection::TRANSMIT) ? m_uio_mm2s_fd : m_uio_s2mm_fd;

    // 1. Write the register
    m_dma_regs[dmasr_offset / 4] = 0xFFFFFFFF; // Clear all status bits (interrupts and errors)
    // 2. Reset LINUX interrupt
    write_return = write(uid_fd, &reenable, sizeof(reenable));
    (void)write_return;
}

void AxiDmaController::checkDmaErrors()
{
    uint32_t s2mm_status = m_dma_regs[S2MM_DMASR / 4];
    uint32_t mm2s_status = m_dma_regs[MM2S_DMASR / 4];

    if (s2mm_status & DMA_SR_ALL_ERR_MASK)
    {
        throw std::runtime_error("S2MM DMA Error: status " + std::to_string(s2mm_status));
    }
    if (mm2s_status & DMA_SR_ALL_ERR_MASK)
    {
        throw std::runtime_error("MM2S DMA Error: status " + std::to_string(mm2s_status));
    }
}

void AxiDmaController::checkDmaStatus()
{
    if (!debug_enabled) return;
    uint32_t s2mm_status = m_dma_regs[S2MM_DMASR / 4];
    uint32_t mm2s_status = m_dma_regs[MM2S_DMASR / 4];
    printf("  * Memory-mapped to stream status (0x%08x@0x%02x):\n", mm2s_status, MM2S_DMASR);
    printf("      MM2S_STATUS_REGISTER status register values:\n       ");
    if (mm2s_status & 0x00000001)
        printf(" halted");
    else
        printf(" running");
    if (mm2s_status & 0x00000002)
        printf(" idle");
    if (mm2s_status & 0x00000008)
        printf(" SGIncld");
    if (mm2s_status & 0x00000010)
        printf(" DMAIntErr");
    if (mm2s_status & 0x00000020)
        printf(" DMASlvErr");
    if (mm2s_status & 0x00000040)
        printf(" DMADecErr");
    if (mm2s_status & 0x00000100)
        printf(" SGIntErr");
    if (mm2s_status & 0x00000200)
        printf(" SGSlvErr");
    if (mm2s_status & 0x00000400)
        printf(" SGDecErr");
    if (mm2s_status & 0x00001000)
        printf(" IOC_Irq");
    if (mm2s_status & 0x00002000)
        printf(" Dly_Irq");
    if (mm2s_status & 0x00004000)
        printf(" Err_Irq");
    printf("\n");
    printf("  * Stream to memory-mapped status (0x%08x@0x%02x):\n", s2mm_status, S2MM_DMASR);
    printf("      S2MM_STATUS_REGISTER status register values:\n       ");
    if (s2mm_status & 0x00000001)
        printf(" halted");
    else
        printf(" running");
    if (s2mm_status & 0x00000002)
        printf(" idle");
    if (s2mm_status & 0x00000008)
        printf(" SGIncld");
    if (s2mm_status & 0x00000010)
        printf(" DMAIntErr");
    if (s2mm_status & 0x00000020)
        printf(" DMASlvErr");
    if (s2mm_status & 0x00000040)
        printf(" DMADecErr");
    if (s2mm_status & 0x00000100)
        printf(" SGIntErr");
    if (s2mm_status & 0x00000200)
        printf(" SGSlvErr");
    if (s2mm_status & 0x00000400)
        printf(" SGDecErr");
    if (s2mm_status & 0x00001000)
        printf(" IOC_Irq");
    if (s2mm_status & 0x00002000)
        printf(" Dly_Irq");
    if (s2mm_status & 0x00004000)
        printf(" Err_Irq");
    printf("\n");
}

bool AxiDmaController::debug_enabled = false;

void AxiDmaController::setDebug(bool enable) {
    debug_enabled = enable;
}
