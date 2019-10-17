with system.machine_code;

with ewok.tasks;           use ewok.tasks;
with ewok.devices_shared;  use ewok.devices_shared;
with ewok.syscalls.handler;
with ewok.interrupts;
with soc.interrupts;

package body ewok.sched.unproved
   with spark_mode => off
is

   procedure init
   is
      idle_task   : t_task renames ewok.tasks.tasks_list(ID_KERNEL);
   begin

      current_task_id := ID_KERNEL;

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_SYSTICK,
         ewok.interrupts.TASK_SWITCH_HANDLER,
         to_system_address (systick_handler'address),
         ID_KERNEL,
         ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_PENDSV,
         ewok.interrupts.TASK_SWITCH_HANDLER,
         to_system_address (pendsv_handler'address),
         ID_KERNEL,
         ID_DEV_UNUSED);

      ewok.interrupts.set_interrupt_handler
        (soc.interrupts.INT_SVC,
         ewok.interrupts.TASK_SWITCH_HANDLER,
         to_system_address (ewok.syscalls.handler.svc_handler'address),
         ID_KERNEL,
         ID_DEV_UNUSED);

      --
      -- Jump to the kernel task
      --
      system.machine_code.asm
        ("mov r0, %0"   & ascii.lf &
         "msr psp, r0"  & ascii.lf &
         "mov r0, 2"    & ascii.lf &
         "msr control, r0" & ascii.lf &
         "mov r1, %1"   & ascii.lf &
         "bx r1",
         inputs   =>
           (system_address'asm_input
              ("r", to_system_address (idle_task.ctx.frame_a)),
            system_address'asm_input
              ("r", idle_task.entry_point)),
         clobber  => "r0, r1",
         volatile => true);

   end init;


end ewok.sched.unproved;
