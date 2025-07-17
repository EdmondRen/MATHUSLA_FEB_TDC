#include "dma_driver.h"
#include <stdio.h>
#include <string.h>

#define DMA_PHYS_ADDR   0x40400000
#define DMA_MEM_RANGE   0x200000
#define MEM_PHYS_ADDR   0x1000000
#define MEM_SIZE        (2 * 1024 * 1024)
#define TRANSFER_SIZE   (2 * 1024)

int main() {
    dma_handle_t dma;
    int ret;
    int errors = 0;

    // printf("--- AXI DMA Example: Direct Register Mode ---\n");
    // ret = dma_init(&dma, "/dev/uio1", DMA_PHYS_ADDR, DMA_MEM_RANGE, MEM_PHYS_ADDR, MEM_SIZE, DMA_MODE_DIRECT);
    // if (ret != 0) return -1;

    // // Prepare buffers
    // unsigned char *tx_buffer = dma.dma_buffer;
    // unsigned char *rx_buffer = dma.dma_buffer + TRANSFER_SIZE;
    // for (int i = 0; i < TRANSFER_SIZE; i++) tx_buffer[i] = i & 0xFF;

    // dma_reset(&dma);
    // dma_setup_buffers(&dma, TRANSFER_SIZE, 0);
    // dma_start_transfer(&dma, 0, TRANSFER_SIZE, TRANSFER_SIZE);
    // dma_wait_interrupt(&dma);
    // dma_clear_interrupts(&dma);

    // // Verify
    // for (int i = 0; i < TRANSFER_SIZE; i++) {
    //     // printf("[%d]rx: %d \n", i & 0xFF, rx_buffer[i]);
    //     if (rx_buffer[i] != (i & 0xFF)) errors++;
    // }
    // printf(errors == 0 ? "Direct mode: SUCCESS\n" : "Direct mode: FAILURE (%d errors)\n", errors);
    // dma_cleanup(&dma);


    printf("\n--- AXI DMA Example: Scatter-Gather Mode ---\n");
    ret = dma_init(&dma, "/dev/uio1", DMA_PHYS_ADDR, DMA_MEM_RANGE, MEM_PHYS_ADDR, MEM_SIZE, DMA_MODE_SG);
    if (ret != 0) return -1;

    // SG: Descriptor at start, data after
    unsigned char *sg_data = dma.dma_buffer;// + DMA_SG_DESC_SIZE*4;
    unsigned char *sg_rx = sg_data + TRANSFER_SIZE;
    for (int i = 0; i < TRANSFER_SIZE; i++) sg_data[i] = (i + 1) & 0xFF;
    memset(sg_rx, 0, sizeof(sg_rx));

    dma_reset(&dma); printf("DMA reset\n");
    printf("After reset: MM2S_DMASR: 0x%08X\n", dma_get_status(&dma, 0));
    printf("After reset: S2MM_DMASR: 0x%08X\n", dma_get_status(&dma, 1));   

    dma_setup_buffers(&dma, TRANSFER_SIZE, 1); printf("Buffer setup\n");
    printf("MM2S descp ADDR: 0x%08X\n", dma.dma_phys_addr);
    dma_sg_desc_t *mm2s_desc = (dma_sg_desc_t *)dma.dma_buffer;
    dma_sg_desc_t *s2mm_desc = (dma_sg_desc_t *)(dma.dma_buffer + DMA_SG_DESC_SIZE);        
    printf("MM2S desc control: 0x%08X\n", mm2s_desc->control);

    printf("before transfer: MM2S_DMASR: 0x%08X\n", dma_get_status(&dma, 0));

    dma_start_transfer(&dma, DMA_SG_DESC_SIZE, DMA_SG_DESC_SIZE + TRANSFER_SIZE, TRANSFER_SIZE); printf("DMA start transfer\n"); printf("DMA wait interrupt\n");
    printf("MM2S_DMASR: 0x%08X\n", dma_get_status(&dma, 0));

    printf("MM2S data ADDR: 0x%08X\n", mm2s_desc->buffer_addr);
    printf("S2MM_DMASR: 0x%08X\n", dma_get_status(&dma, 1));
    printf("S2MM descp ADDR: 0x%08X\n", dma.dma_phys_addr+DMA_SG_DESC_SIZE);
    printf("S2MM data ADDR: 0x%08X\n", s2mm_desc->buffer_addr);
    dma_wait_interrupt(&dma); printf("DMA interrupt handeled\n");
    dma_clear_interrupts(&dma); printf("DMA interrupt cleared\n");

    // Verify
    errors = 0;
    for (int i = 0; i < TRANSFER_SIZE; i++) {
        printf("[%d:%d]rx: %d \n", i, i & 0xFF, sg_rx[i]);
        if (sg_rx[i] != ((i + 1) & 0xFF)) errors++;
    }
    printf(errors == 0 ? "SG mode: SUCCESS\n" : "SG mode: FAILURE (%d errors)\n", errors);
    dma_cleanup(&dma);
    return 0;
} 