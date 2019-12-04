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

with ewok.tasks_shared;       use ewok.tasks_shared;
with ewok.devices_shared;     use ewok.devices_shared;
with ewok.exported.devices;   use ewok.exported.devices;
with ewok.dma_shared;         use ewok.dma_shared;
with ewok.sanitize;
with ewok.memory;
with ewok.perm;
with ewok.sched;
with ewok.debug;

package body ewok.syscalls.init
   with spark_mode => on
is

   package TSK renames ewok.tasks;


   procedure svc_register_device
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is

      udev_address : constant system.address := to_address (params(1));
      udev         : ewok.exported.devices.t_user_device
         with
            import,
            address => udev_address,
            size    => 11232; -- Required by SPARK

      -- Device descriptor transmitted to userspace
      descriptor_address : constant system.address := to_address (params(2));
      descriptor  : unsigned_8 range 0 .. TSK.MAX_DEVS_PER_TASK
         with address => descriptor_address;

      dev_id   : ewok.devices_shared.t_device_id;
      ok       : boolean;
   begin

      -- Forbidden after end of task initialization
      if TSK.is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- NOTE
      --    The kernel might register some devices using this syscall
      --    for user tasks. The device_t structure may be stored in
      --    RAM (.data section) or in flash (.rodata section)
      if TSK.is_real_user (caller_id) and then
        (not ewok.sanitize.is_range_in_data_slot
               (to_system_address (udev_address),
                udev'size/8,
                caller_id,
                mode)
         and
         not ewok.sanitize.is_range_in_txt_slot
               (to_system_address (udev_address),
                udev'size/8,
                caller_id))
      then
         pragma DEBUG (debug.log (debug.ERROR,
            "svc_register_device(): udev not in task's memory space"));
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      if TSK.is_real_user (caller_id) and then
         not ewok.sanitize.is_word_in_data_slot
               (to_system_address (descriptor_address), caller_id, mode)
      then
         pragma DEBUG (debug.log (debug.ERROR,
            "svc_register_device(): descriptor not in task's memory space"));
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

#if not SPARK
      -- Ada based sanitization
      -- /!\ Should be remove for SPARK verification
      if not udev'valid_scalars
      then
         pragma DEBUG (debug.log (debug.ERROR, "svc_register_device(): invalid udev scalars"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;
#end if;

      if TSK.is_real_user (caller_id) and then
         not ewok.devices.sanitize_user_defined_device (udev, caller_id)
      then
         pragma DEBUG (debug.log (debug.ERROR, "svc_register_device(): invalid udev"));
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      if TSK.tasks_list(caller_id).num_devs = TSK.MAX_DEVS_PER_TASK then
         pragma DEBUG (debug.log (debug.ERROR,
            "svc_register_device(): no space left to register the device"));
         TSK.set_return_value (caller_id, mode, SYS_E_BUSY);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Device should be automatically mapped...
      if (udev.map_mode = DEV_MAP_AUTO  and udev.size > 0)
         -- ...but no free memory available!
         and then not ewok.memory.device_can_be_mapped
      then
         pragma DEBUG (debug.log (debug.ERROR,
            "svc_register_device(): no free region left to map the device"));
         TSK.set_return_value (caller_id, mode, SYS_E_BUSY);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      --
      -- Registering the device
      --

      ewok.devices.register_device (caller_id, udev, dev_id, ok);

      if not ok then
         pragma DEBUG (debug.log (debug.ERROR,
            "svc_register_device(): failed to register the device"));
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      --
      -- Recording registered devices in the task record
      --

      TSK.append_device (caller_id, dev_id, descriptor, ok);
      if not ok then
         raise program_error; -- Should never happen here
      end if;

      -- Mount DEV_MAP_AUTO devices in memory
      if udev.size > 0 and udev.map_mode = DEV_MAP_AUTO then
         TSK.mount_device (caller_id, descriptor, ok);
         if not ok then
            raise program_error; -- Should never happen here
         end if;
      end if;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_register_device;


   procedure svc_init_done
     (caller_id   : in  ewok.tasks_shared.t_task_id;
      mode        : in  ewok.tasks_shared.t_task_mode)
   is
      ok       : boolean;
      dev_id   : ewok.devices_shared.t_device_id;
   begin

      -- Forbidden after end of task initialization
      if TSK.is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- We enable auto mapped devices (MAP_AUTO)
      for i in TSK.tasks_list(caller_id).devices'range loop
         dev_id := TSK.tasks_list(caller_id).devices(i).device_id;
         if dev_id /= ID_DEV_UNUSED then
            if ewok.devices.get_device_map_mode (dev_id) = DEV_MAP_AUTO
            then
               -- FIXME - Create new syscalls for enabling/disabling devices?
               ewok.devices.enable_device (dev_id, ok);
               if not ok then
                  TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
                  TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
                  return;
               end if;
            end if;
         end if;
      end loop;

      for i in 1 .. TSK.tasks_list(caller_id).num_dma_id loop
         declare
            index : constant ewok.dma_shared.t_user_dma_index
               := TSK.tasks_list(caller_id).dma_id(i);
         begin
            if index = ewok.dma_shared.ID_DMA_UNUSED then
               raise program_error;
            end if;
            ewok.dma.enable_dma_irq (index);
         end;
      end loop;

      TSK.tasks_list(caller_id).init_done := true;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

      -- Request a schedule to ensure that the task has its devices mapped
      -- afterward
      -- FIXME - has to be changed when device mapping will be synchronously done
      ewok.sched.request_schedule;

   end svc_init_done;


   procedure svc_get_taskid
     (caller_id   : in ewok.tasks_shared.t_task_id;
      params      : in t_parameters;
      mode        : in ewok.tasks_shared.t_task_mode)
   is

      target_name : ewok.tasks_shared.t_task_name
         with import, address => to_address (params(1));

      target_id_address : constant system.address := to_address (params(2));
      target_id   : ewok.tasks_shared.t_task_id
         with address => target_id_address;

      tmp_id      : ewok.tasks_shared.t_task_id;

   begin

      -- Forbidden after end of task initialization
      if TSK.is_init_done (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- Does &target_id is in the caller address space ?
      if not ewok.sanitize.is_word_in_data_slot
               (to_system_address (target_id_address), caller_id, mode)
      then
         TSK.set_return_value (caller_id, mode, SYS_E_DENIED);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- We retrieve the 'id' related to the target name. Before updating the
      -- parameter passed by the user, we must check that the 2 tasked are
      -- allowed to communicate
      tmp_id := TSK.get_task_id (target_name);

      if not is_real_user (tmp_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

#if CONFIG_KERNEL_DOMAIN
      if TSK.get_domain (tmp_id) /= TSK.get_domain (caller_id) then
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;
#end if;

      -- Are tasks allowed to communicate through IPCs or DMA_SHM ?
      if not ewok.perm.ipc_is_granted (caller_id, tmp_id) and
         not ewok.perm.dmashm_is_granted (caller_id, tmp_id)
      then
         TSK.set_return_value (caller_id, mode, SYS_E_INVAL);
         TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);
         return;
      end if;

      -- We may update the target_id
      target_id := tmp_id;

      TSK.set_return_value (caller_id, mode, SYS_E_DONE);
      TSK.set_state (caller_id, mode, TASK_STATE_RUNNABLE);

   end svc_get_taskid;

end ewok.syscalls.init;
