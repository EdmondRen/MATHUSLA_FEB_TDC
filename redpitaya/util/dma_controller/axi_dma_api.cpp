

// =================================================================================
// FILE: axi_dma_api.cpp
//
// DESCRIPTION:
// C-style wrapper implementation. These functions are the bridge between the
// C API and the C++ implementation. They handle object creation/destruction
// and translate C++ exceptions to C-style error codes.
//
// =================================================================================
#include "axi_dma_api.h"
#include "axi_dma_controller.hpp"
#include <iostream>

extern "C" {

AxiDmaHandle_t dma_create(uint64_t dma_phys_addr, uint64_t mem_phys_addr, uint64_t mem_size) {
    try {
        return new AxiDmaController(dma_phys_addr, mem_phys_addr, mem_size);
    } catch (const std::exception& e) {
        std::cerr << "DMA Creation Failed: " << e.what() << std::endl;
        return nullptr;
    }
}

AxiDmaHandle_t dma_create_irq(uint64_t dma_phys_addr, uint64_t mem_phys_addr, uint64_t mem_size, const char* uio_mm2s, const char* uio_s2mm) {
    try {
        return new AxiDmaController(dma_phys_addr, mem_phys_addr, mem_size, uio_mm2s, uio_s2mm);
    } catch (const std::exception& e) {
        std::cerr << "DMA Creation Failed: " << e.what() << std::endl;
        return nullptr;
    }
}



void dma_destroy(AxiDmaHandle_t handle) {
    if (handle) {
        delete handle;
    }
}

void dma_reset(AxiDmaHandle_t handle) {
    if (handle) {
        handle->reset(AxiDmaController::DmaDirection::TRANSMIT);
        handle->reset(AxiDmaController::DmaDirection::RECEIVE);
    }
}

int dma_init_channel(AxiDmaHandle_t handle, DmaMode_e mode_mm2s, DmaMode_e mode_s2mm, uint32_t num_bds, uint32_t buffer_size) {
    if (!handle) return -1;
    try {
        AxiDmaController::DmaMode cpp_mode_mm2s = (mode_mm2s == DMA_MODE_SG) ? AxiDmaController::DmaMode::SCATTER_GATHER : AxiDmaController::DmaMode::CYCLIC;
        AxiDmaController::DmaMode cpp_mode_s2mm = (mode_s2mm == DMA_MODE_SG) ? AxiDmaController::DmaMode::SCATTER_GATHER : AxiDmaController::DmaMode::CYCLIC;
        handle->initSG(cpp_mode_mm2s, cpp_mode_s2mm, num_bds, buffer_size);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "DMA Channel Init Failed: " << e.what() << std::endl;
        return -1;
    }
}

void dma_start(AxiDmaHandle_t handle, DmaDirection_e dir) {
    if (handle) {
        AxiDmaController::DmaDirection cpp_dir = (dir == DMA_TRANSMIT) ? AxiDmaController::DmaDirection::TRANSMIT : AxiDmaController::DmaDirection::RECEIVE;
        handle->startSG(cpp_dir);
    }
}

int dma_simple_transmit(AxiDmaHandle_t handle, uint64_t tx_addr, uint32_t len) {
    if (!handle) return -1;
    try {
        handle->simpleTransmit(tx_addr, len);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "DMA Simple Transmit Failed: " << e.what() << std::endl;
        return -1;
    }
}

int dma_simple_receive(AxiDmaHandle_t handle, uint64_t rx_addr, uint32_t len) {
    if (!handle) return -1;
    try {
        handle->simpleReceive(rx_addr, len);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "DMA Simple Receive Failed: " << e.what() << std::endl;
        return -1;
    }
}

int dma_wait_for_completion(AxiDmaHandle_t handle, DmaDirection_e dir) {
    if (!handle) return -1;
    try {
        AxiDmaController::DmaDirection cpp_dir = (dir == DMA_TRANSMIT) ? AxiDmaController::DmaDirection::TRANSMIT : AxiDmaController::DmaDirection::RECEIVE;
        handle->waitForCompletion(cpp_dir);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "DMA Wait For Completion Failed: " << e.what() << std::endl;
        return -1;
    }
}

int dma_get_completed_block(AxiDmaHandle_t handle, DmaDirection_e dir, void** data_ptr, uint32_t* len) {
    if (!handle) return -1;
    try {
        return handle->getCompletedBlock(data_ptr, len);
    } catch (const std::exception& e) {
        std::cerr << "DMA get block failed: " << e.what() << std::endl;
        return -1;
    }
}

void dma_release_completed_block(AxiDmaHandle_t handle, DmaDirection_e dir) {
    if (handle) {
        AxiDmaController::DmaDirection cpp_dir = (dir == DMA_TRANSMIT) ? AxiDmaController::DmaDirection::TRANSMIT : AxiDmaController::DmaDirection::RECEIVE;
        handle->releaseBlock(cpp_dir);
    }
}

int dma_submit_transmit_block(AxiDmaHandle_t handle, const void* data_ptr, uint32_t len) {
    if (!handle) return -1;
    try {
        return handle->SGTransmitBlock(data_ptr, len);
    } catch (const std::exception& e) {
        std::cerr << "DMA submit block failed: " << e.what() << std::endl;
        return -1;
    }
}

} // extern "C"