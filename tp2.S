#include "common.h"

BEGIN
    CLEAR
/* Acá empieza la versión modificada de PROTECTED_MODE */
/* calcula las direcciones de los segmentos en base a gdt_start, que es el comienzo de todos */
/* CODE_SEG es 8 porque hay un byte nulo al principio de la tabla?*/
.equ CODE_SEG, 8
.equ DATA_SEG, gdt_data - gdt_start
.equ DATA_USER, gdt_data_user - gdt_start

/* Acá se le dice al procesador dónde está, en la memoria, la tabla global de descriptores */
lgdt gdt_descriptor

/* Setea el bit PE (Protection Enable) en CR0 para entrar en modo protegido */
mov %cr0, %eax
orl $0x1, %eax
mov %eax, %cr0

ljmp $CODE_SEG, $protected_mode
/*  El código original usa una GDT que tiene dos segmentos: CODE y DATA.
 * Ambos empiezan en la dirección 0 y ocupan toda la memoria.
 *  En nuestro caso tenemos los mismos descriptores, pero ahora los segmentos 
 * van a ser de la mitad de tamaño y no van a estar solapados.
 *
 *  En un principio, los segmentos van a tener los mismos permisos de acceso que
 * los del ejemplo. Esto es:
 * --
 * ** No se puede escribir en el segmento de código.
 * ** No se puede ejecutar el segmento de datos (pero sí se puede leer y escribir).
 * --
 * +
 * Es bueno destacar el siguiente comentario del código original:
 *
 * A real OS might have 2 extra segments: user data and code.
 * This is better than modifying the privilege bit of the GDT
 * as we'd have to reload it several times, losing cache.
 */
gdt_start:
/* Entrada nula de la GDT */
gdt_null:
    .long 0x0
    .long 0x0
/* Descriptores de segmento
 *  Acá vamos a definir los dos segmentos pedidos en la consigna. Para ello vamos
 * a tener que completar los bits según la estructura siguiente:
 *
 * 31                                              16 15                                               0
 * +---------------------------------------------------------------------------------------------------+
 * | Dirección base 31:24   | flags #2  | Lím 19:16  | flags #1               | Dir. base 23:16        |
 * +-------------------------------------------------+-------------------------------------------------+
 * | Dirección base bits 15:0                        | Límite del segment bits 15:0                    |
 * +---------------------------------------------------------------------------------------------------+
 *
 * Como se ve, cada descriptor va a tener:
 *   - una palabra con los primeros 16 bits del límite [0:15]
 *   - una palabra con los primeros 16 bits de la base [0:15]
 *   - un byte con los siguientes 8 bits de la base [16:23]
 *   - un byte con los flags Accessed, Read/Write, Conforming/Expand down, Type, un bit en 1, DPL y Present
 *   - un byte cuyo nibble inferior serán los últimos 4 bits del límite [16:19]
 *         y cuyo nibble superior serán otros bits de flag: Available, Long, Default/Big, Granularity
 *   - un último byte con los últimos bits de la base [24:31]
 */
 
/* Segmento de código del kernel */
gdt_code:
/* Límite del segmento. Bits 0 a 15 */
    .word 0x7fff
/* Dirección base. Bits 16 a 31 */
    .word 0x0
/* Dirección base. Bits 0 a 7 */
    .byte 0x0
/* Bits A = 0, R = 1, C = 0, Type= 1, S = 1, DPL = 00 y P = 1 
 * S nos indica que no es de sistema y Type nos indica que el segmento es de código, 
 *   por lo que R nos indica que se puede ejecutar y leer y C que no es Conforming. 
 *   DPL nos indica el nivel de privilegio.*/
    .byte 0b10011010
/*  Este byte contiene los bits 16 a 19, que son la segunda mitad del límite (F)
 * y los bits AVL = 0, L = 0, D = 1 y G = 1 
 * Acá tenemos que está disponible (AVL), es un segmento de 32 bits (L y D), y que maneja una las paginas de 4Kb */
    .byte 0b11001111
/* Últimos bits de la base, bits 24 a 31 de la segunda palabra doble */
    .byte 0x0

/* Segmento de datos del kernel */
gdt_data:
/* Límite del segmento. Bits 0 a 15 */
    .word 0xffff
/* Dirección base. Bits 16 a 31 */
    .word 0x0
/* Dirección base. Bits 0 a 7 */
    .byte 0x0
/* Bits A = 0, R/W = 1, C/E = 0, Type = 0, 1, DPL = 00 y P = 1 */
    .byte 0b10010010
/*  Este byte contiene los bits 16 a 19, que son la segunda mitad del límite (F)
 * y los bits AVL = 0, L = 0, D/B = 1 y G = 1 */
    .byte 0b11001111
/* Las configuraciones en este caso son similares a las del anterior, pero ahora es un segmento de datos
 * por lo que R se reemplaza por W y nos dice que el segmento se puede escribir, C se reemplaza por E y nos
 * dice que es expand-down (o sea que no es una pila).
/* Últimos bits de la base, bits 24 a 31 de la segunda palabra doble */
    .byte 0x0
gdt_data_user:
/* Límite del segmento. Bits 0 a 15 */
    .word 0xffff
/* Dirección base. Bits 16 a 31 */
    .word 0x0100
/* Dirección base. Bits 0 a 7 */
    .byte 0x0
/* Bits A = 0, R/W = 1, C/E = 0, Type = 0, 1, DPL = 00 y P = 1 */
    .byte 0b10010010
/*  Este byte contiene los bits 16 a 19, que son la segunda mitad del límite (F)
 * y los bits AVL = 0, L = 0, D/B = 1 y G = 1 */
    .byte 0b11001111
/* Las configuraciones en este caso son similares a las del anterior, pero ahora es un segmento de datos
 * por lo que R se reemplaza por W y nos dice que el segmento se puede escribir, C se reemplaza por E y nos
 * dice que es expand-down (o sea que no es una pila).
/* Últimos bits de la base, bits 24 a 31 de la segunda palabra doble */
    .byte 0x0
gdt_end:
/* acá está definida la dirección que se le pasa al procesador con lgdt */
gdt_descriptor:
    .word gdt_end - gdt_start
    .long gdt_start
/* el resto del código se deja como está */
vga_current_line:
    .long 0
.code32
protected_mode:
    /* Setup the other segments.
     * Those movs are mandatory because they update the descriptor cache:
     * http://wiki.osdev.org/Descriptor_Cache
     */
    mov $DATA_SEG, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %ss
    mov $DATA_USER, %ax
    mov %ax, %gs
    /* TODO detect the last memory address available properly.
     * It depends on how much RAM we have.
     */
    mov $0X7000, %ebp
    mov %ebp, %esp

    VGA_PRINT_STRING $message
    hlt 

message:
    .asciz "TP2 SISCOMP 2020"
