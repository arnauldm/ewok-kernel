
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


with m4.cpu;
with m4.cpu.instructions;
with ewok.debug;
with ewok.ipc;             use ewok.ipc;
with ewok.memory;
with soc.devmap;           use type soc.devmap.t_periph_id;
with types.c;              use type types.c.t_retval;


package body ewok.tasks
   with spark_mode => on
is

   procedure idle_task
   is
   begin
      pragma DEBUG (debug.log (debug.INFO, "IDLE thread"));
      m4.cpu.enable_irq;
      loop
         m4.cpu.instructions.wait_for_interrupt;
      end loop;
   end idle_task;


   procedure finished_task
   is
   begin
      loop null; end loop;
   end finished_task;


   function get_task_id (name : t_task_name)
      return ewok.tasks_shared.t_task_id
   is

      -- String comparison is a bit tricky here because:
      --  - We want it case-unsensitive ('a' and 'A' are the same)
      --  - The nul character and space ' ' are consider the same
      --
      -- The following inner functions are needed to effect comparisons:

      -- Convert a character to uppercase
      function to_upper (c : character)
         return character
      is
         val : constant natural := character'pos (c);
      begin
         return
           (if c in 'a' .. 'z' then character'val (val - 16#20#) else c);
      end;

      -- Test if a character is 'nul'
      function is_nul (c : character)
         return boolean
      is begin
         return c = ASCII.NUL or c = ' ';
      end;

      -- Test if the 2 strings are the same
      function is_same (s1: t_task_name; s2 : t_task_name)
         return boolean
      is begin
         for i in t_task_name'range loop
            if is_nul (s1(i)) and is_nul (s2(i)) then
               return true;
            end if;
            if to_upper (s1(i)) /= to_upper (s2(i)) then
               return false;
            end if;
         end loop;
         return true;
      end;

   begin
      for id in applications.list'range loop
         if is_same (tasks_list(id).name, name) then
            return id;
         end if;
      end loop;
      return ID_UNUSED;
   end get_task_id;


#if CONFIG_KERNEL_DOMAIN
   function get_domain (id : in ewok.tasks_shared.t_task_id)
      return unsigned_8
   is
   begin
      return tasks_list(id).domain;
   end get_domain;
#end if;


   function get_state
     (id    : ewok.tasks_shared.t_task_id;
      mode  : t_task_mode)
      return t_task_state
   is
   begin
      if mode = TASK_MODE_MAINTHREAD then
         return tasks_list(id).state;
      else
         return tasks_list(id).isr_state;
      end if;
   end get_state;


   procedure set_state
     (id    : ewok.tasks_shared.t_task_id;
      mode  : t_task_mode;
      state : t_task_state)
   is
   begin
      if mode = TASK_MODE_MAINTHREAD then
         tasks_list(id).state := state;
      else
         tasks_list(id).isr_state := state;
      end if;
   end set_state;


   function get_mode
     (id     : in  ewok.tasks_shared.t_task_id)
      return t_task_mode
   is
   begin
      return tasks_list(id).mode;
   end get_mode;


   procedure set_mode
     (id     : in   ewok.tasks_shared.t_task_id;
      mode   : in   ewok.tasks_shared.t_task_mode)
   is
   begin
      tasks_list(id).mode := mode;
   end set_mode;


   function is_ipc_waiting
     (id     : in  ewok.tasks_shared.t_task_id)
      return boolean
   is
   begin
      for i in tasks_list(id).ipc_endpoint_id'range loop
         if tasks_list(id).ipc_endpoint_id(i) /= ID_ENDPOINT_UNUSED
            and then
            ewok.ipc.ipc_endpoints(tasks_list(id).ipc_endpoint_id(i)).state
               = ewok.ipc.WAIT_FOR_RECEIVER
            and then
            ewok.ipc.ipc_endpoints(tasks_list(id).ipc_endpoint_id(i)).to
               = id
         then
            return true;
         end if;
      end loop;
      return false;
   end;


   procedure append_device
     (id          : in  ewok.tasks_shared.t_task_id;
      dev_id      : in  ewok.devices_shared.t_device_id;
      descriptor  : out t_device_descriptor_ext;
      success     : out boolean)
   is
   begin

      if tasks_list(id).num_devs = MAX_DEVS_PER_TASK then
         descriptor  := 0;
         success     := false;
         return;
      end if;

      for i in tasks_list(id).devices'range loop
         if tasks_list(id).devices(i).device_id = ID_DEV_UNUSED then
            tasks_list(id).devices(i).device_id := dev_id;
            tasks_list(id).devices(i).mounted   := false;
            tasks_list(id).num_devs             := tasks_list(id).num_devs + 1;
            descriptor  := i;
            success     := true;
            return;
         end if;

         pragma loop_invariant
           (for all j in tasks_list(id).devices'first .. i
                => tasks_list(id).devices(j).device_id /= ID_DEV_UNUSED);
      end loop;

      raise program_error; -- Unreachable (proved)
   end append_device;


   procedure remove_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
   is
   begin
      if tasks_list(id).devices(dev_descriptor).device_id = ID_DEV_UNUSED then
         raise program_error; -- Unreachable (proved)
      end if;
      if tasks_list(id).num_devs < 1 then
         raise program_error; -- Unreachable (proved)
      end if;
      tasks_list(id).devices(dev_descriptor).device_id := ID_DEV_UNUSED;
      tasks_list(id).devices(dev_descriptor).mounted   := false;
      tasks_list(id).num_devs := tasks_list(id).num_devs - 1;
   end remove_device;


   function is_mounted
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
      return boolean
   is
   begin
      if tasks_list(id).devices(dev_descriptor).device_id = ID_DEV_UNUSED then
         raise program_error; -- Unreachable (proved)
      end if;
      return tasks_list(id).devices(dev_descriptor).mounted;
   end is_mounted;


   procedure mount_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor;
      success        : out boolean)
   is
   begin

      if tasks_list(id).devices(dev_descriptor).device_id = ID_DEV_UNUSED then
         raise program_error; -- Unreachable (proved)
      end if;

      if is_mounted (id, dev_descriptor) then
         raise program_error; -- Unreachable (proved)
      end if;

      if ewok.devices.registered_device(tasks_list(id).devices(dev_descriptor).device_id).periph_id
            = soc.devmap.NO_PERIPH
      then
         raise program_error; -- Unreachable (proved)
      end if;

      -- Mapping the device
      ewok.memory.map_device
        (tasks_list(id).devices(dev_descriptor).device_id,
         success);
      if success then
         tasks_list(id).devices(dev_descriptor).mounted := true;
      end if;
   end mount_device;


   procedure unmount_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
   is
   begin

      if tasks_list(id).devices(dev_descriptor).device_id = ID_DEV_UNUSED then
         raise program_error; -- Unreachable (proved)
      end if;

      if not is_mounted (id, dev_descriptor) then
         raise program_error; -- Unreachable (proved)
      end if;

      -- Unmapping the device
      ewok.memory.unmap_device
        (tasks_list(id).devices(dev_descriptor).device_id);

      tasks_list(id).devices(dev_descriptor).mounted := false;
   end unmount_device;


   function is_real_user (id : ewok.tasks_shared.t_task_id) return boolean
   is
   begin
      return (id in applications.t_real_task_id);
   end is_real_user;


   procedure set_return_value
     (id    : in  ewok.tasks_shared.t_task_id;
      mode  : in  t_task_mode;
      val   : in  unsigned_32)
   is
   begin
      case mode is
         when TASK_MODE_MAINTHREAD =>
            if tasks_list(id).ctx.frame_a = NULL then
               raise program_error;
            end if;
            tasks_list(id).ctx.frame_a.all.R0      := val;
         when TASK_MODE_ISRTHREAD =>
            if tasks_list(id).isr_ctx.frame_a = NULL then
               raise program_error;
            end if;
            tasks_list(id).isr_ctx.frame_a.all.R0  := val;
      end case;
   end set_return_value;


   function is_init_done
     (id    : ewok.tasks_shared.t_task_id)
      return boolean
   is
   begin
      return tasks_list(id).init_done;
   end is_init_done;


end ewok.tasks;
