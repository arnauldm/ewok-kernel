
package types.c
   with spark_mode => on
is

   type t_retval is (SUCCESS, FAILURE) with size => 8;
   for t_retval use (SUCCESS  => 0, FAILURE  => 1);

   type bool is new boolean with size => 8;
   for bool use (true => 1, false => 0);

end types.c;
