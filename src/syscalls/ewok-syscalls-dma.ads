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
with ewok.tasks;        use ewok.tasks;
with ewok.tasks_shared;
with ewok.devices;
with ewok.dma;
with ewok.interrupts;
with soc.dma;
with applications;

package ewok.syscalls.dma
   with spark_mode => on
is

   procedure svc_register_dma
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
              (ewok.devices.registered_device),
            in_out =>
              (tasks_list,
               ewok.interrupts.interrupt_table,
               ewok.dma.registered_dma,
               soc.dma.DMA1,
               soc.dma.DMA2));

   procedure svc_register_dma_shm
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
              (ewok.devices.registered_device),
            in_out =>
              (tasks_list));

   procedure svc_dma_reconf
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
              (ewok.devices.registered_device),
            in_out =>
              (tasks_list,
               ewok.interrupts.interrupt_table,
               ewok.dma.registered_dma,
               soc.dma.DMA1,
               soc.dma.DMA2));

   procedure svc_dma_reload
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
              (ewok.dma.registered_dma),
            in_out =>
              (tasks_list,
               soc.dma.DMA1,
               soc.dma.DMA2));

   procedure svc_dma_disable
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
      with
         pre => caller_id in applications.t_real_task_id,
         global =>
           (input =>
               ewok.dma.registered_dma,
            in_out =>
              (tasks_list,
               soc.dma.DMA1,
               soc.dma.DMA2));


end ewok.syscalls.dma;
