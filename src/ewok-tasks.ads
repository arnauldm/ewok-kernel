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


with ewok.tasks_shared;    use ewok.tasks_shared;
with ewok.devices_shared;  use ewok.devices_shared;
with ewok.ipc;
with ewok.exported.dma;
with ewok.dma_shared;
with ewok.mpu.allocator;
with ewok.devices;
with applications;
with m4.mpu;


package ewok.tasks
   with spark_mode => on
is

   type t_task_state is (
      -- No task in this slot
      TASK_STATE_EMPTY,

      -- Task can be elected by the scheduler with its standard priority
      -- or an ISR is ready for execution
      TASK_STATE_RUNNABLE,

      -- Force the scheduler to choose that task
      TASK_STATE_FORCED,

      -- Pending syscall. Task can't be scheduled.
      TASK_STATE_SVC_BLOCKED,

      -- An ISR is finished
      TASK_STATE_ISR_DONE,

      -- Task currently has nothing to do, not schedulable
      TASK_STATE_IDLE,

      -- Task is sleeping
      TASK_STATE_SLEEPING,

      -- Task is deeply sleeping
      TASK_STATE_SLEEPING_DEEP,

      -- Task has generated an exception (memory fault, etc.), not
      -- schedulable anymore
      TASK_STATE_FAULT,

      -- Task has return from its main() function. Yet its ISR handlers can
      -- still be executed if needed
      TASK_STATE_FINISHED,

      -- Task has emitted a blocking send() and is waiting for the
      -- receiver to emit a recv()
      TASK_STATE_IPC_SEND_BLOCKED,

      -- Task has emitted a blocking recv() and is waiting for a message
      TASK_STATE_IPC_RECV_BLOCKED,

      -- Task has emitted a blocking send() and is waiting an
      -- acknowledgement after the message has been received
      TASK_STATE_IPC_WAIT_ACK,

      -- Task has entered in a critical section. Related ISRs can't be executed
      TASK_STATE_LOCKED);

   type t_task_type is
     (-- Kernel task
      TASK_TYPE_KERNEL,
      -- User task, being executed in user mode, with restricted access
      TASK_TYPE_USER);

   type t_main_context is record
      frame_a       : ewok.t_stack_frame_access                := NULL;
   end record;

   type t_isr_context is record
      entry_point   : system_address                           := 0;
      device_id     : ewok.devices_shared.t_device_id          := ID_DEV_UNUSED;
      sched_policy  : ewok.tasks_shared.t_scheduling_post_isr  := ISR_STANDARD;
      frame_a       : ewok.t_stack_frame_access                := NULL;
   end record;

   --
   -- Tasks
   --

   MAX_DEVS_PER_TASK       : constant := 10;
   MAX_DMAS_PER_TASK       : constant := 8;
   MAX_INTERRUPTS_PER_TASK : constant := 8;
   MAX_DMA_SHM_PER_TASK    : constant := 4;

   type t_registered_dma_index_list is array (unsigned_32 range <>) of
      ewok.dma_shared.t_user_dma_index
         with default_component_value => ewok.dma_shared.ID_DMA_UNUSED;

   type t_dma_shm_info_list is array (unsigned_32 range <>) of
      ewok.exported.dma.t_dma_shm_info;

   type t_device is record
      device_id   : ewok.devices_shared.t_device_id   := ID_DEV_UNUSED;
      mounted     : boolean                           := false;
   end record;

   subtype t_device_descriptor is unsigned_8 range 1 .. MAX_DEVS_PER_TASK;
   subtype t_device_descriptor_ext is unsigned_8 range 0 .. MAX_DEVS_PER_TASK;
   type t_device_list_unbound is
      array (t_device_descriptor range <>) of t_device;
   subtype t_device_list is t_device_list_unbound (t_device_descriptor);

   type t_ipc_endpoint_id_list is array (ewok.tasks_shared.t_task_id) of
      ewok.ipc.t_extended_endpoint_id
         with default_component_value => ewok.ipc.ID_ENDPOINT_UNUSED;


   type t_task is record
      name              : t_task_name     := "          ";
      entry_point       : system_address  := 0;
      ttype             : t_task_type     := TASK_TYPE_USER;
      mode              : t_task_mode     := TASK_MODE_MAINTHREAD;
      id                : ewok.tasks_shared.t_task_id := ID_UNUSED;
      slot              : m4.mpu.t_subregion := m4.mpu.t_subregion'first;
      num_slots         : unsigned_8      := 0;
      prio              : unsigned_8      := 0;
#if CONFIG_KERNEL_DOMAIN
      domain            : unsigned_8      := 0;
#end if;
#if CONFIG_KERNEL_SCHED_DEBUG
      count             : unsigned_32     := 0;
      force_count       : unsigned_32     := 0;
      isr_count         : unsigned_32     := 0;
#end if;
      num_dma_shms      : unsigned_32 range 0 .. MAX_DMA_SHM_PER_TASK   := 0;
      dma_shm           : t_dma_shm_info_list (1 .. MAX_DMA_SHM_PER_TASK);
      num_dma_id        : unsigned_32 range 0 .. MAX_DMAS_PER_TASK      := 0;
      dma_id            : t_registered_dma_index_list (1 .. MAX_DMAS_PER_TASK);
      num_devs          : t_device_descriptor_ext := 0;
      devices           : t_device_list;
      init_done         : boolean         := false;
      data_slot_start   : system_address  := 0;
      data_slot_end     : system_address  := 0;
      txt_slot_start    : system_address  := 0;
      txt_slot_end      : system_address  := 0;
      stack_bottom      : system_address  := 0;
      stack_top         : system_address  := 0;
      stack_size        : unsigned_16     := 0;
      state             : t_task_state    := TASK_STATE_EMPTY;
      isr_state         : t_task_state    := TASK_STATE_EMPTY;
      ipc_endpoint_id   : t_ipc_endpoint_id_list;
      ctx               : t_main_context;
      isr_ctx           : t_isr_context;
   end record
      with
         dynamic_predicate => slot_in_bounds (slot, num_slots);

   function slot_in_bounds
     (slot : m4.mpu.t_subregion;
      num_slots : unsigned_8)
      return boolean
   is
     (num_slots <= m4.mpu.t_subregion'last and
      num_slots + unsigned_8 (slot) - 1 <= m4.mpu.t_subregion'last);


   type t_task_array is array (t_task_id range <>) of t_task;

   -----------
   -- Ghost --
   -----------

#if GNATPROVE
   -- FIXME - Must enable pragmas no_recursion and no_secondary_stack

   function remove_last (dev : t_device_list_unbound)
      return t_device_list_unbound is (dev(dev'first .. dev'last - 1))
   with
      ghost,
      pre => dev'length > 0;

   function count_used (dev : t_device_list_unbound) return unsigned_8 is
     (if dev'length = 0 then 0
      elsif dev(dev'last).device_id /= ID_DEV_UNUSED then
         count_used (remove_last (dev)) + 1
      else
         count_used (remove_last (dev)))
   with
      ghost,
      post => count_used'result <= dev'length;
   pragma annotate (gnatprove, terminating, count_used);
   pragma annotate (gnatprove, false_positive,
      "subprogram ""count_used"" might not terminate", "Count_used is terminating");
#end if;

   -------------
   -- Globals --
   -------------

   -- The list of the running tasks
   tasks_list : t_task_array (ID_APP1 .. ID_KERNEL);

   softirq_task_name : t_task_name := "SOFTIRQ" & "   ";
   idle_task_name    : t_task_name := "IDLE" & "      ";

   ---------------
   -- Functions --
   ---------------

   pragma assertion_policy (pre => IGNORE, post => IGNORE, assert => IGNORE);

   procedure idle_task with no_return;
   procedure finished_task with no_return;

   function is_real_user (id : ewok.tasks_shared.t_task_id) return boolean
      with
         post =>
           (if is_real_user'result then
               id /= ID_UNUSED and
               id in applications.t_real_task_id);

#if CONFIG_KERNEL_DOMAIN
   function get_domain (id : in ewok.tasks_shared.t_task_id)
      return unsigned_8
      with inline;
#end if;

   function get_task_id (name : t_task_name)
      return ewok.tasks_shared.t_task_id
      with
         global => (input => tasks_list);

   procedure set_state
     (id    : ewok.tasks_shared.t_task_id;
      mode  : t_task_mode;
      state : t_task_state)
      with
         inline,
         pre    => id /= ID_UNUSED,
         global => (in_out => tasks_list);

   function get_state
     (id    : ewok.tasks_shared.t_task_id;
      mode  : t_task_mode)
      return t_task_state
      with
         inline,
         pre    => id /= ID_UNUSED,
         global => (input => tasks_list);

   function get_mode
     (id     : in  ewok.tasks_shared.t_task_id)
      return t_task_mode
      with
         inline,
         pre    => id /= ID_UNUSED,
         global => (input => tasks_list);

   procedure set_mode
     (id     : in   ewok.tasks_shared.t_task_id;
      mode   : in   ewok.tasks_shared.t_task_mode)
      with
         inline,
         pre    => id /= ID_UNUSED,
         global => (in_out => tasks_list);

   function is_ipc_waiting
     (id     : in  ewok.tasks_shared.t_task_id)
      return boolean
      with
         pre    => id /= ID_UNUSED,
         global => (input => (tasks_list, ewok.ipc.ipc_endpoints));

   procedure set_return_value
     (id    : in  ewok.tasks_shared.t_task_id;
      mode  : in  t_task_mode;
      val   : in  unsigned_32)
      with
         inline,
         pre    => id /= ID_UNUSED,
         global => (in_out => tasks_list);

   function is_init_done
     (id    : ewok.tasks_shared.t_task_id)
      return boolean
      with
         pre    => id /= ID_UNUSED,
         global => (input => tasks_list);

   procedure append_device
     (id          : in  ewok.tasks_shared.t_task_id;
      dev_id      : in  ewok.devices_shared.t_device_id;
      descriptor  : out t_device_descriptor_ext;
      success     : out boolean)
      with
         global =>
           (in_out => tasks_list),
         pre  =>
            id /= ID_UNUSED and then
#if GNATPROVE
            tasks_list(id).num_devs = count_used (tasks_list(id).devices) and then
#end if;
            tasks_list(id).num_devs < MAX_DEVS_PER_TASK and then
            dev_id /= ID_DEV_UNUSED,
         post =>
           (if success then descriptor in t_device_descriptor'range) and
           (for all i in 1 .. tasks_list(id).num_devs =>
               tasks_list(id).devices(i).device_id /= ID_DEV_UNUSED);

   procedure remove_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
      with
         global => (in_out => tasks_list),
         pre =>
            id /= ID_UNUSED and then
#if GNATPROVE
            tasks_list(id).num_devs = count_used (tasks_list(id).devices) and then
#end if;
            tasks_list(id).num_devs > 0;

   function is_mounted
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
      return boolean
      with
         global => (input => tasks_list),
         pre    =>
#if GNATPROVE
            id /= ID_UNUSED and then
            tasks_list(id).num_devs = count_used (tasks_list(id).devices);
#else
            id /= ID_UNUSED;
#end if;

   procedure mount_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor;
      success        : out boolean)
      with
         global =>
           (input => ewok.devices.registered_device,
            in_out =>
              (tasks_list,
               ewok.mpu.allocator.regions_pool,
               m4.mpu.MPU)),
         pre    =>
#if GNATPROVE
            id /= ID_UNUSED and then
            tasks_list(id).num_devs = count_used (tasks_list(id).devices);
#else
            id /= ID_UNUSED;
#end if;

   procedure unmount_device
     (id             : in  ewok.tasks_shared.t_task_id;
      dev_descriptor : in  t_device_descriptor)
      with
         global =>
           (input => ewok.devices.registered_device,
            in_out =>
              (tasks_list,
               ewok.mpu.allocator.regions_pool,
               m4.mpu.MPU)),
         pre =>
#if GNATPROVE
            id /= ID_UNUSED and then
            tasks_list(id).num_devs = count_used (tasks_list(id).devices);
#else
            id /= ID_UNUSED;
#end if;

end ewok.tasks;
