
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
with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.layout;          use ewok.layout;
with ewok.rng;
with ewok.softirq;
with ewok.debug;
with types.c;              use type types.c.t_retval;

with applications; -- Automatically generated
with sections;     -- Automatically generated

package body ewok.tasks.unproved
   with spark_mode => off
is

   procedure create_stack
     (sp       : in  system_address;
      pc       : in  system_address;
      params   : in  ewok.t_parameters;
      frame_a  : out ewok.t_stack_frame_access)
   is
      new_sp : constant system_address := sp - (t_stack_frame'size / 8);
   begin

      frame_a := to_stack_frame_access (new_sp);

      frame_a.all.R0 := params(1);
      frame_a.all.R1 := params(2);
      frame_a.all.R2 := params(3);
      frame_a.all.R3 := params(4);

      frame_a.all.R4    := 0;
      frame_a.all.R5    := 0;
      frame_a.all.R6    := 0;
      frame_a.all.R7    := 0;
      frame_a.all.R8    := 0;
      frame_a.all.R9    := 0;
      frame_a.all.R10   := 0;
      frame_a.all.R11   := 0;
      frame_a.all.R12   := 0;

      frame_a.all.exc_return  := m4.cpu.EXC_THREAD_MODE;
      frame_a.all.LR    := to_system_address (finished_task'address);
      frame_a.all.PC    := pc;
      frame_a.all.PSR   := m4.cpu.t_PSR_register'
        (ISR_NUMBER     => 0,
         ICI_IT_lo      => 0,
         GE             => 0,
         Thumb          => 1,
         ICI_IT_hi      => 0,
         DSP_overflow   => 0,
         Overflow       => 0,
         Carry          => 0,
         Zero           => 0,
         Negative       => 0);

   end create_stack;


   procedure set_default_values (tsk : out t_task)
   is
   begin
      tsk.name              := "          ";
      tsk.entry_point       := 0;
      tsk.ttype             := TASK_TYPE_USER;
      tsk.mode              := TASK_MODE_MAINTHREAD;
      tsk.id                := ID_UNUSED;
      tsk.slot              := m4.mpu.t_subregion'first;
      tsk.num_slots         := 0;
      tsk.prio              := 0;

#if CONFIG_KERNEL_DOMAIN
      tsk.domain            := 0;
#end if;

#if CONFIG_KERNEL_SCHED_DEBUG
      tsk.count             := 0;
      tsk.force_count       := 0;
      tsk.isr_count         := 0;
#end if;

      tsk.num_dma_shms      := 0;
      tsk.dma_shm           :=
        (others => ewok.exported.dma.t_dma_shm_info'
           (granted_id  => ID_UNUSED,
            accessed_id => ID_UNUSED,
            base        => 0,
            size        => 0,
            access_type => ewok.exported.dma.SHM_ACCESS_READ));

      tsk.num_dma_id        := 0;
      tsk.dma_id            := (others => ewok.dma_shared.ID_DMA_UNUSED);

      tsk.num_devs          := 0;
      tsk.devices           := (others => (ewok.devices_shared.ID_DEV_UNUSED, false));
      tsk.init_done         := false;
      tsk.data_slot_start   := 0;
      tsk.data_slot_end     := 0;
      tsk.txt_slot_start    := 0;
      tsk.txt_slot_end      := 0;
      tsk.stack_size        := 0;
      tsk.state             := TASK_STATE_EMPTY;
      tsk.isr_state         := TASK_STATE_EMPTY;
      tsk.ipc_endpoint_id   := (others => ID_ENDPOINT_UNUSED);
      tsk.ctx.frame_a       := NULL;
      tsk.isr_ctx           := t_isr_context'(0, ID_DEV_UNUSED, ISR_STANDARD, NULL);
   end set_default_values;


   procedure init_softirq_task
   is
      params : constant t_parameters := (others => 0);
   begin

      -- Setting default values
      set_default_values (tasks_list(ID_SOFTIRQ));

      tasks_list(ID_SOFTIRQ).name := softirq_task_name;

      tasks_list(ID_SOFTIRQ).entry_point  :=
         to_system_address (ewok.softirq.main_task'address);

      if tasks_list(ID_SOFTIRQ).entry_point mod 2 = 0 then
         tasks_list(ID_SOFTIRQ).entry_point :=
            tasks_list(ID_SOFTIRQ).entry_point + 1;
      end if;

      tasks_list(ID_SOFTIRQ).ttype  := TASK_TYPE_KERNEL;
      tasks_list(ID_SOFTIRQ).id     := ID_SOFTIRQ;

      -- Zeroing the stack
      declare
         stack : byte_array(1 .. STACK_SIZE_SOFTIRQ)
            with address => to_address (STACK_TOP_SOFTIRQ - STACK_SIZE_SOFTIRQ);
      begin
         stack := (others => 0);
      end;

      -- Create the initial stack frame and set the stack pointer
      create_stack
        (STACK_TOP_SOFTIRQ,
         tasks_list(ID_SOFTIRQ).entry_point,
         params,
         tasks_list(ID_SOFTIRQ).ctx.frame_a);

      tasks_list(ID_SOFTIRQ).stack_size   := STACK_SIZE_SOFTIRQ;
      tasks_list(ID_SOFTIRQ).state        := TASK_STATE_IDLE;
      tasks_list(ID_SOFTIRQ).isr_state    := TASK_STATE_IDLE;

      for i in tasks_list(ID_SOFTIRQ).ipc_endpoint_id'range loop
         tasks_list(ID_SOFTIRQ).ipc_endpoint_id(i)   := ID_ENDPOINT_UNUSED;
      end loop;

      pragma DEBUG (debug.log (debug.INFO, "Created SOFTIRQ context (pc: "
         & system_address'image (tasks_list(ID_SOFTIRQ).entry_point)
         & ") sp: "
         & system_address'image
            (to_system_address (tasks_list(ID_SOFTIRQ).ctx.frame_a))));

   end init_softirq_task;


   procedure init_idle_task
   is
      params : constant t_parameters := (others => 0);
   begin

      -- Setting default values
      set_default_values (tasks_list(ID_KERNEL));

      tasks_list(ID_KERNEL).name := idle_task_name;

      tasks_list(ID_KERNEL).entry_point  :=
         to_system_address (idle_task'address);

      if tasks_list(ID_KERNEL).entry_point mod 2 = 0 then
         tasks_list(ID_KERNEL).entry_point :=
            tasks_list(ID_KERNEL).entry_point + 1;
      end if;

      tasks_list(ID_KERNEL).ttype  := TASK_TYPE_KERNEL;
      tasks_list(ID_KERNEL).mode   := TASK_MODE_MAINTHREAD;
      tasks_list(ID_KERNEL).id     := ID_KERNEL;

      -- Zeroing the stack
      declare
         stack : byte_array(1 .. STACK_SIZE_IDLE)
            with address => to_address (STACK_TOP_IDLE - STACK_SIZE_IDLE);
      begin
         stack := (others => 0);
      end;

      -- Create the initial stack frame and set the stack pointer
      create_stack
        (STACK_TOP_IDLE,
         tasks_list(ID_KERNEL).entry_point,
         params,
         tasks_list(ID_KERNEL).ctx.frame_a);

      tasks_list(ID_KERNEL).stack_size   := STACK_SIZE_IDLE;
      tasks_list(ID_KERNEL).state        := TASK_STATE_RUNNABLE;
      tasks_list(ID_KERNEL).isr_state    := TASK_STATE_IDLE;

      for i in tasks_list(ID_KERNEL).ipc_endpoint_id'range loop
         tasks_list(ID_KERNEL).ipc_endpoint_id(i)   := ID_ENDPOINT_UNUSED;
      end loop;

      pragma DEBUG (debug.log (debug.INFO, "Created context for IDLE task (pc: "
         & system_address'image (tasks_list(ID_KERNEL).entry_point)
         & ") sp: "
         & system_address'image
            (to_system_address (tasks_list(ID_KERNEL).ctx.frame_a))));

   end init_idle_task;


   procedure init_apps
   is
      user_base   : system_address;
      params      : t_parameters;
      random      : unsigned_32;
      ok          : boolean;
   begin

      if applications.t_real_task_id'last > ID_APP7 then
         debug.panic ("Too many apps");
      end if;

      user_base := applications.txt_user_region_base;

      for id in applications.list'range loop

         set_default_values (tasks_list(id));

         tasks_list(id).name := applications.list(id).name;

         tasks_list(id).entry_point  :=
            user_base
            + to_unsigned_32 (applications.list(id).slot - 1)
               * applications.txt_user_size / 8; -- this is MPU specific

         if tasks_list(id).entry_point mod 2 = 0 then
            tasks_list(id).entry_point := tasks_list(id).entry_point + 1;
         end if;

         tasks_list(id).ttype := TASK_TYPE_USER;
         tasks_list(id).id    := id;

         if unsigned_8 (applications.list(id).slot)
               + applications.list(id).num_slots
               - 1 > m4.mpu.t_subregion'last
         then
            raise program_error;
         end if;

         tasks_list(id).slot      := applications.list(id).slot;
         tasks_list(id).num_slots := applications.list(id).num_slots;

         tasks_list(id).prio  := applications.list(id).priority;

#if CONFIG_KERNEL_DOMAIN
         tasks_list(id).domain   := applications.list(id).domain;
#end if;

         tasks_list(id).data_slot_start   :=
            USER_DATA_BASE
            + to_unsigned_32 (tasks_list(id).slot - 1)
               * USER_DATA_SIZE;

         tasks_list(id).data_slot_end     :=
            USER_DATA_BASE
            + to_unsigned_32
                 (tasks_list(id).slot + tasks_list(id).num_slots - 1)
               * USER_DATA_SIZE;

         tasks_list(id).txt_slot_start := tasks_list(id).entry_point - 1;

         tasks_list(id).txt_slot_end   :=
            user_base
            + to_unsigned_32
                (applications.list(id).slot + tasks_list(id).num_slots - 1)
               * applications.txt_user_size / 8; -- this is MPU specific

         tasks_list(id).stack_bottom   := applications.list(id).stack_bottom;
         tasks_list(id).stack_top      := applications.list(id).stack_top;
         tasks_list(id).stack_size     := applications.list(id).stack_size;

         tasks_list(id).state       := TASK_STATE_RUNNABLE;
         tasks_list(id).isr_state   := TASK_STATE_IDLE;

         for i in tasks_list(id).ipc_endpoint_id'range loop
            tasks_list(id).ipc_endpoint_id(i)   := ID_ENDPOINT_UNUSED;
         end loop;

         -- Zeroing the stack
         declare
            stack : byte_array(1 .. unsigned_32 (tasks_list(id).stack_size))
               with address => to_address
                 (tasks_list(id).data_slot_end -
                  unsigned_32 (tasks_list(id).stack_size));
         begin
            stack := (others => 0);
         end;

         --
         -- Create the initial stack frame and set the stack pointer
         --

         -- Getting the stack "canary"
         ewok.rng.random (random, ok);
         if not ok then
            pragma DEBUG (debug.log (debug.ERROR,
               "Unable to get random from TRNG source"));
         end if;

         params := t_parameters'(to_unsigned_32 (id), random, 0, 0);

         create_stack
           (tasks_list(id).stack_top,
            tasks_list(id).entry_point,
            params,
            tasks_list(id).ctx.frame_a);

         tasks_list(id).isr_ctx.entry_point := applications.list(id).start_isr;

         pragma DEBUG (debug.log (debug.INFO, "Created task " & tasks_list(id).name
            & " (pc: " & system_address'image (tasks_list(id).entry_point)
            & ", data: " & system_address'image (tasks_list(id).data_slot_start)
            & " - " & system_address'image (tasks_list(id).data_slot_end)
            & ", sp: " & system_address'image
                           (to_system_address (tasks_list(id).ctx.frame_a))
            & ", ID" & t_task_id'image (id) & ")"));
      end loop;

   end init_apps;


   procedure task_init
   is
   begin

      for id in tasks_list'range loop
         set_default_values (tasks_list(id));
      end loop;

      init_idle_task;
      init_softirq_task;
      init_apps;

      sections.task_map_data;

   end task_init;

end ewok.tasks.unproved;
