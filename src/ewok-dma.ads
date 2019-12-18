--
-- Copyright 2018 The wookey project team <wookey@ssi.gouv.fr>
--   - Ryad     Benadjila
--   - Arnauld  Michelizza
--   - Mathieu  Renard
--   - Philippe Thierry
--   - Philippe Trebuchet
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--     Unless required by applicable law or agreed to in writing, software
--     distributed under the License is distributed on an "AS IS" BASIS,
--     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--     See the License for the specific language governing permissions and
--     limitations under the License.
--
--

with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.dma_shared;   use ewok.dma_shared;
with ewok.exported.dma;
with soc.dma;
with soc.dma.interfaces;

pragma warnings (off,
   "*soc.interrupts.t_interrupt* is already use-visible through previous use_type_clause");
with soc.interrupts;    use type soc.interrupts.t_interrupt;
pragma warnings (on);

with soc.devmap;        use type soc.devmap.t_periph_id;


package ewok.dma
   with spark_mode => on
is

   type t_status is (DMA_UNUSED, DMA_USED, DMA_CONFIGURED);

   type t_registered_dma is record
      status      : t_status                             := DMA_UNUSED;
      task_id     : ewok.tasks_shared.t_task_id          := ID_UNUSED;
      periph_id   : soc.devmap.t_periph_id               := soc.devmap.NO_PERIPH;
      config      : soc.dma.interfaces.t_dma_config;
   end record
      with dynamic_predicate =>
        (if task_id /= ID_UNUSED then
            periph_id /= soc.devmap.NO_PERIPH);

   registered_dma :
      array (ewok.dma_shared.t_registered_dma_index) of t_registered_dma;


   procedure get_registered_dma_entry
     (index    : out ewok.dma_shared.t_registered_dma_index;
      success  : out boolean)
   with
      global =>
        (in_out => registered_dma),
      post   =>
        (if success then registered_dma(index).status = DMA_USED);

   procedure release_registered_dma_entry
     (index    : in  ewok.dma_shared.t_registered_dma_index)
   with
      global =>
        (in_out => registered_dma);

   function has_same_dma_channel
     (index       : ewok.dma_shared.t_registered_dma_index;
      user_config : ewok.exported.dma.t_dma_user_config)
      return boolean
   with
      global =>
        (input => registered_dma);

   function stream_is_already_used
     (user_config : ewok.exported.dma.t_dma_user_config)
      return boolean;

   procedure enable_dma_stream
     (index : in ewok.dma_shared.t_registered_dma_index)
   with
      global =>
        (input  =>
            registered_dma,
         in_out =>
           (soc.dma.DMA1,
            soc.dma.DMA2));

   procedure disable_dma_stream
     (index : in ewok.dma_shared.t_registered_dma_index);

   procedure enable_dma_irq
     (index : in ewok.dma_shared.t_registered_dma_index);
--   with
--      pre => registered_dma(index).periph_id /= soc.devmap.NO_PERIPH;

   function is_config_complete
     (config : soc.dma.interfaces.t_dma_config)
      return boolean;

   function sanitize_dma
     (user_config    : ewok.exported.dma.t_dma_user_config;
      caller_id      : ewok.tasks_shared.t_task_id;
      to_configure   : ewok.exported.dma.t_config_mask;
      mode           : ewok.tasks_shared.t_task_mode)
      return boolean
   with
      pre => caller_id /= ID_UNUSED;

   function sanitize_dma_shm
     (shm            : ewok.exported.dma.t_dma_shm_info;
      caller_id      : ewok.tasks_shared.t_task_id;
      mode           : ewok.tasks_shared.t_task_mode)
      return boolean
   with
      pre => caller_id /= ID_UNUSED;

   procedure reconfigure_stream
     (user_config    : in out ewok.exported.dma.t_dma_user_config;
      index          : in     ewok.dma_shared.t_registered_dma_index;
      to_configure   : in     ewok.exported.dma.t_config_mask;
      caller_id      : in     ewok.tasks_shared.t_task_id;
      success        : out    boolean)
   with
      pre => registered_dma(index).periph_id /= soc.devmap.NO_PERIPH;

   procedure init_stream
     (user_config    : in     ewok.exported.dma.t_dma_user_config;
      caller_id      : in     ewok.tasks_shared.t_task_id;
      index          : out    ewok.dma_shared.t_user_dma_index;
      success        : out    boolean)
   with
      post =>
        (if success then
           (index /= ewok.dma_shared.ID_DMA_UNUSED and
            registered_dma(index).periph_id /= soc.devmap.NO_PERIPH));

   procedure init;

   procedure clear_dma_interrupts
     (caller_id : in  ewok.tasks_shared.t_task_id;
      interrupt : in  soc.interrupts.t_interrupt)
   with
      pre => 
        (interrupt = soc.interrupts.INT_DMA1_STREAM0 or
         interrupt = soc.interrupts.INT_DMA1_STREAM1 or
         interrupt = soc.interrupts.INT_DMA1_STREAM2 or
         interrupt = soc.interrupts.INT_DMA1_STREAM3 or
         interrupt = soc.interrupts.INT_DMA1_STREAM4 or
         interrupt = soc.interrupts.INT_DMA1_STREAM5 or
         interrupt = soc.interrupts.INT_DMA1_STREAM6 or
         interrupt = soc.interrupts.INT_DMA1_STREAM7 or
         interrupt = soc.interrupts.INT_DMA2_STREAM0 or
         interrupt = soc.interrupts.INT_DMA2_STREAM1 or
         interrupt = soc.interrupts.INT_DMA2_STREAM2 or
         interrupt = soc.interrupts.INT_DMA2_STREAM3 or
         interrupt = soc.interrupts.INT_DMA2_STREAM4 or
         interrupt = soc.interrupts.INT_DMA2_STREAM5 or
         interrupt = soc.interrupts.INT_DMA2_STREAM6 or
         interrupt = soc.interrupts.INT_DMA2_STREAM7);
               
   procedure get_status_register
     (caller_id : in  ewok.tasks_shared.t_task_id;
      interrupt : in  soc.interrupts.t_interrupt;
      status    : out soc.dma.t_dma_stream_int_status;
      success   : out boolean);

end ewok.dma;
