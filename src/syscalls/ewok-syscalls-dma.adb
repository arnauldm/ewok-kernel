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

with system;

with ewok.tasks_shared; use ewok.tasks_shared;
with ewok.dma_shared;   use ewok.dma_shared;
with ewok.exported.dma;
with ewok.perm;
with ewok.sanitize;
with ewok.debug;

package body ewok.syscalls.dma
   with spark_mode => on
is

   package TSK renames ewok.tasks;

   procedure svc_register_dma
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
      dma_config_address   : constant system.address := to_address (params(1));
      dma_config           : ewok.exported.dma.t_dma_user_config
         with import, address => dma_config_address;

      dma_descriptor_address   : constant system.address := to_address (params(2));
      dma_descriptor           : unsigned_32
         with import, address => dma_descriptor_address;

      index                : ewok.dma_shared.t_registered_dma_index;
      ok                   : boolean;
   begin

      -- Forbidden after end of task initialization
      if is_init_done (caller_id) then
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- DMA allowed for that task?
      if not ewok.perm.ressource_is_granted
               (ewok.perm.PERM_RES_DEV_DMA, caller_id)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): permission not granted"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Ada based sanitation using on types compliance
      if not dma_config.controller'valid     or
         not dma_config.stream'valid         or
         not dma_config.channel'valid        or
         not dma_config.size'valid           or
         not dma_config.in_addr'valid        or
         not dma_config.in_priority'valid    or
         not dma_config.in_handler'valid     or
         not dma_config.out_addr'valid       or
         not dma_config.out_priority'valid   or
         not dma_config.out_handler'valid    or
         not dma_config.flow_controller'valid or
         not dma_config.transfer_dir'valid   or
         not dma_config.mode'valid           or
         not dma_config.data_size'valid      or
         not dma_config.memory_inc'valid     or
         not dma_config.periph_inc'valid     or
         not dma_config.mem_burst_size'valid or
         not dma_config.periph_burst_size'valid
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): invalid dma_t"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does dma_config'address and dma_descriptor'address are in the caller
      -- address space ?
      if not ewok.sanitize.is_range_in_data_slot
                 (to_system_address (dma_config_address),
                  dma_config'size/8,
                  caller_id,
                  mode)
         or
         not ewok.sanitize.is_word_in_data_slot
                 (to_system_address (dma_descriptor_address), caller_id, mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): parameters not in task's memory space"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Verify DMA configuration transmitted by the user
      if not ewok.dma.sanitize_dma
                 (dma_config,
                  caller_id,
                  ewok.exported.dma.t_config_mask'(others => false),
                  mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): invalid dma configuration"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Check if controller/stream are already used
      -- Note: A DMA controller can manage only one channel per stream in the
      --       same time.
      if ewok.dma.stream_is_already_used (dma_config) then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): dma configuration already used"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Is there any user dma_descriptor available ?
      if TSK.tasks_list(caller_id).num_dma_id < MAX_DMAS_PER_TASK then
         TSK.tasks_list(caller_id).num_dma_id :=
            TSK.tasks_list(caller_id).num_dma_id + 1;
      else
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_BUSY);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Initialization
      ewok.dma.init_stream (dma_config, caller_id, index, ok);
      if not ok then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma(): dma initialization failed"));
         dma_descriptor := 0;
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      dma_descriptor := TSK.tasks_list(caller_id).num_dma_id;
      TSK.tasks_list(caller_id).dma_id(dma_descriptor) := index;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_register_dma;


   procedure svc_register_dma_shm
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
      user_dma_shm_address : constant system.address := to_address (params(1));
      user_dma_shm         : ewok.exported.dma.t_dma_shm_info
         with import, address => user_dma_shm_address;
      granted_id           : ewok.tasks_shared.t_task_id;
   begin

      -- Forbidden after end of task initialization
      if is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Ada based sanitation using on types compliance
      if not user_dma_shm.granted_id'valid   or
         not user_dma_shm.accessed_id'valid  or
         not user_dma_shm.base'valid         or
         not user_dma_shm.size'valid         or
         not user_dma_shm.access_type'valid
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): invalid dma_shm_t"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does user_dma_shm'address is in the caller address space ?
      if not ewok.sanitize.is_range_in_data_slot
                 (to_system_address (user_dma_shm_address),
                  user_dma_shm'size/8,
                  caller_id,
                  mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): params not in task's space"));
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Verify DMA shared memory configuration transmitted by the user
      if not ewok.dma.sanitize_dma_shm (user_dma_shm, caller_id, mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): invalid configuration"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      granted_id := user_dma_shm.granted_id;

      -- Granted is a valid user ?
      if not is_real_user (granted_id) then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): invalid granted id"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does the task can share memory with its target task?
      if not ewok.perm.dmashm_is_granted (caller_id, granted_id)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): not granted"));
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Is there any user descriptor available ?
      if TSK.tasks_list(granted_id).num_dma_shms < MAX_DMA_SHM_PER_TASK and
         TSK.tasks_list(caller_id).num_dma_shms  < MAX_DMA_SHM_PER_TASK
      then
         TSK.tasks_list(granted_id).num_dma_shms :=
            TSK.tasks_list(granted_id).num_dma_shms + 1;
         TSK.tasks_list(caller_id).num_dma_shms  :=
            TSK.tasks_list(caller_id).num_dma_shms + 1;
      else
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_register_dma_shm(): busy"));
         TSK.set_return_value (caller_id, mode, SYS_E_BUSY);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      TSK.tasks_list(granted_id).dma_shm(TSK.tasks_list(granted_id).num_dma_shms)
         := user_dma_shm;
      TSK.tasks_list(caller_id).dma_shm(TSK.tasks_list(caller_id).num_dma_shms)
         := user_dma_shm;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_register_dma_shm;


   procedure svc_dma_reconf
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is

      new_dma_config_address  : constant system.address
         := to_address (params(1));
      new_dma_config          : ewok.exported.dma.t_dma_user_config
         with import, address => new_dma_config_address;

      config_mask    : constant ewok.exported.dma.t_config_mask
         with import, address => params(2)'address;

      dma_descriptor : constant unsigned_32 := params(3);

      ok : boolean;
   begin

      -- Forbidden before end of task initialization
      if not is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Ada based sanitation using on types compliance is not easy,
      -- as only fields marked by config_mask have a real interpretation
      -- These fields are checked in the dma_sanitize_dma() function call
      -- bellow

      -- Does new_dma_config'address is in the caller address space ?
      if not ewok.sanitize.is_range_in_data_slot
                 (to_system_address (new_dma_config_address),
                  new_dma_config'size/8,
                  caller_id,
                  mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_dma_reconf(): params not in task's space"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor ?
      if dma_descriptor < TSK.tasks_list(caller_id).dma_id'first or
         dma_descriptor > TSK.tasks_list(caller_id).num_dma_id
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_dma_reconf(): invalid descriptor"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor should *always* point to a valid
      -- DMA stream
      if TSK.tasks_list(caller_id).dma_id(dma_descriptor)
            = ewok.dma_shared.ID_DMA_UNUSED
      then
         raise program_error;
      end if;

      -- Check if the user tried to change the DMA ctrl/channel/stream
      -- parameters
      if not ewok.dma.has_same_dma_channel
                 (TSK.tasks_list(caller_id).dma_id(dma_descriptor),
                  new_dma_config)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_dma_reconf(): ctrl/channel/stream changed"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Verify DMA configuration transmitted by the user
      if not ewok.dma.sanitize_dma
                 (new_dma_config, caller_id, config_mask, mode)
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_dma_reconf(): invalid configuration"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Reconfigure the DMA controller
      ewok.dma.reconfigure_stream
        (new_dma_config,
         TSK.tasks_list(caller_id).dma_id(dma_descriptor),
         config_mask,
         caller_id,
         ok);

      if not ok then
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_dma_reconf;


   procedure svc_dma_reload
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
      dma_descriptor : constant unsigned_32 := params(1);
   begin

      -- Forbidden before end of task initialization
      if not is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor ?
      if dma_descriptor < TSK.tasks_list(caller_id).dma_id'first or
         dma_descriptor > TSK.tasks_list(caller_id).num_dma_id
      then
         pragma DEBUG (debug.log
           (debug.ERROR, "svc_dma_reload(): invalid descriptor"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor should *always* point to a valid
      -- DMA stream
      if TSK.tasks_list(caller_id).dma_id(dma_descriptor)
            = ewok.dma_shared.ID_DMA_UNUSED
      then
         raise program_error;
      end if;

      ewok.dma.enable_dma_stream
        (TSK.tasks_list(caller_id).dma_id(dma_descriptor));

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_dma_reload;


   procedure svc_dma_disable
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is
      dma_descriptor : constant unsigned_32 := params(1);
   begin

      -- Forbidden before end of task initialization
      if not is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor ?
      if dma_descriptor < TSK.tasks_list(caller_id).dma_id'first or
         dma_descriptor > TSK.tasks_list(caller_id).num_dma_id
      then
         pragma DEBUG (debug.log (debug.ERROR, "svc_dma_disable(): invalid descriptor"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Valid DMA descriptor should *always* point to a valid
      -- DMA stream
      if TSK.tasks_list(caller_id).dma_id(dma_descriptor)
            = ewok.dma_shared.ID_DMA_UNUSED
      then
         raise program_error;
      end if;

      ewok.dma.disable_dma_stream
        (TSK.tasks_list(caller_id).dma_id(dma_descriptor));

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_dma_disable;


end ewok.syscalls.dma;
