Example Layout
| Offset in Buffer | Usage | Physical Address |
|-------------------------|----------------------|---------------------------------|
| 0x000 | MM2S descriptor | MEM_PHYS_ADDR |
| 0x040 | S2MM descriptor | MEM_PHYS_ADDR + 0x40 |
| 0x080 | MM2S data buffer | MEM_PHYS_ADDR + 0x80 |
| 0x080 + size | S2MM data buffer | MEM_PHYS_ADDR + 0x80 + size |
