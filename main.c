/*
 * Licensed under the GNU General Public License version 2 with exceptions. See
 * LICENSE file in the project root for full license information
 */

#include "ecat_slv.h"
#include "esc_foe.h"
#include "utypes.h"
#include "xmc_gpio.h"

#include <string.h>
#include <stdio.h>

#ifdef XMC4800_F144x2048
#define P_LED  P5_8
#define P_BTN  P15_12
#endif

#ifdef XMC4300_F100x256
#define P_LED  P4_1
#define P_BTN  P3_4
#endif

#define FLASH_WRITE_BLOCK_SIZE 8192
#define DUMMY_FLASH_SIZE FLASH_WRITE_BLOCK_SIZE

extern void ESC_eep_handler(void);
void foe_init(void);
uint32_t foe_write_to_test_bin(foe_writefile_cfg_t * self, uint8_t * data, size_t length);

/* Application variables */
_Rbuffer    Rb;
_Wbuffer    Wb;
_Cbuffer    Cb;

uint8_t * rxpdo = (uint8_t *)&Wb.LED;
uint8_t * txpdo = (uint8_t *)&Rb.button;

uint32_t encoder_scale;
uint32_t encoder_scale_mirror;


static const uint32_t test_bin_dummy_flash = 0;

static const XMC_GPIO_CONFIG_t gpio_config_btn = {
  .mode = XMC_GPIO_MODE_INPUT_INVERTED_PULL_UP,
  .output_level = 0,
  .output_strength = 0
};

static const XMC_GPIO_CONFIG_t gpio_config_led = {
  .mode = XMC_GPIO_MODE_OUTPUT_PUSH_PULL,
  .output_level = XMC_GPIO_OUTPUT_LEVEL_LOW,
  .output_strength = XMC_GPIO_OUTPUT_STRENGTH_STRONG_SOFT_EDGE
};

void cb_get_inputs (void)
{
   Rb.button = XMC_GPIO_GetInput(P_BTN);
   Cb.reset_counter++;
   Rb.encoder =  ESCvar.Time;
}

void cb_set_outputs (void)
{
   if (Wb.LED)
   {
      XMC_GPIO_SetOutputHigh(P_LED);
   }
   else
   {
      XMC_GPIO_SetOutputLow(P_LED);
   }
}

uint32_t post_object_download_hook (uint16_t index, uint8_t subindex,
                                uint16_t flags)
{
   switch(index)
   {
      case 0x7100:
      {
         switch (subindex)
         {
            case 0x01:
            {
               encoder_scale_mirror = encoder_scale;
               break;
            }
         }
         break;
      }
      case 0x8001:
      {
         switch (subindex)
         {
            case 0x01:
            {
               Cb.reset_counter = 0;
               break;
            }
         }
         break;
      }
   }
   return 0;
}

void soes (void * arg)
{
   /* Setup config hooks */
   static esc_cfg_t config =
   {
      .user_arg = NULL,
      .use_interrupt = 0,
      .watchdog_cnt = 5000,
      .set_defaults_hook = NULL,
      .pre_state_change_hook = NULL,
      .post_state_change_hook = NULL,
      .application_hook = NULL,
      .safeoutput_override = NULL,
      .pre_object_download_hook = NULL,
      .post_object_download_hook = post_object_download_hook,
      .rxpdo_override = NULL,
      .txpdo_override = NULL,
      .esc_hw_interrupt_enable = NULL,
      .esc_hw_interrupt_disable = NULL,
      .esc_hw_eep_handler = ESC_eep_handler
   };

   DPRINT ("SOES (Simple Open EtherCAT Slave)\n");

   // configure I/O
   XMC_GPIO_Init(P_BTN, &gpio_config_btn);
   XMC_GPIO_Init(P_LED, &gpio_config_led);

   ecat_slv_init(&config);
   foe_init();

   while (1)
   {
      ecat_slv();
   }
}

int main (void)
{
   soes (NULL);
   return 0;
}


void foe_init(void)
{
  static foe_writefile_cfg_t files[] =
  {
     {
        .name               = "test.bin",
        .max_data           = DUMMY_FLASH_SIZE,
        .dest_start_address = (uint32_t)test_bin_dummy_flash,
        .address_offset     = 0,
        .filepass           = 0,
        .write_function     = foe_write_to_test_bin   /* NULL if not used */
     }
  };

  static uint8_t fbuf[FLASH_WRITE_BLOCK_SIZE];
  static foe_cfg_t config =
  {
     .buffer_size = FLASH_WRITE_BLOCK_SIZE,  /* Buffer size before we flush to destination */
     .fbuffer     = (uint8_t *)&fbuf,
     .n_files     = 1,
     .files       = files
  };

  FOE_config(&config, files);
}


uint32_t foe_write_to_test_bin(foe_writefile_cfg_t * self, uint8_t * data, size_t length)
{
  return 0;
}
