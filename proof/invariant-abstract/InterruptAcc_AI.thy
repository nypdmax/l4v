(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory InterruptAcc_AI
imports TcbAcc_AI
begin

lemma get_irq_slot_real_cte[wp]:
  "\<lbrace>invs\<rbrace> get_irq_slot irq \<lbrace>real_cte_at\<rbrace>"
  apply (simp add: get_irq_slot_def)
  apply wp
  apply (clarsimp simp: invs_def valid_state_def valid_irq_node_def)
  done


lemma get_irq_slot_cte_at[wp]:
  "\<lbrace>invs\<rbrace> get_irq_slot irq \<lbrace>cte_at\<rbrace>"
  apply (rule hoare_strengthen_post [OF get_irq_slot_real_cte])
  apply (clarsimp simp: real_cte_at_cte)
  done


crunch valid_ioc[wp]: set_irq_state valid_ioc

definition valid_irq_masks_but where
  "valid_irq_masks_but irq table masked \<equiv> \<forall> irq'. irq' \<noteq> irq \<longrightarrow> table irq' = IRQInactive \<longrightarrow> masked irq'"

definition valid_irq_states_but where
  "valid_irq_states_but irq s \<equiv> valid_irq_masks_but irq (interrupt_states s) (irq_masks (machine_state s))"

definition all_invs_but_valid_irq_states_for where
  "all_invs_but_valid_irq_states_for irq \<equiv> valid_pspace and valid_mdb and 
  valid_ioc and valid_idle and only_idle and
  if_unsafe_then_cap and
  valid_reply_caps and
  valid_reply_masters and
  valid_global_refs and
  valid_arch_state and
  valid_irq_node and
  valid_irq_handlers and
  valid_irq_states_but irq and
  valid_machine_state and
  valid_arch_objs and
  valid_arch_caps and
  valid_global_objs and
  valid_kernel_mappings and
  equal_kernel_mappings and
  valid_asid_map and
  valid_global_pd_mappings and
  pspace_in_kernel_window and
  cap_refs_in_kernel_window and cur_tcb and
  executable_arch_objs"

lemma dmo_maskInterrupt_invs:
  "\<lbrace>all_invs_but_valid_irq_states_for irq and (\<lambda>s. state = interrupt_states s irq)\<rbrace> 
   do_machine_op (maskInterrupt (state = IRQInactive) irq) 
   \<lbrace>\<lambda>rv. invs\<rbrace>"
   apply (simp add: do_machine_op_def split_def maskInterrupt_def)
   apply wp
   apply (clarsimp simp: in_monad invs_def valid_state_def all_invs_but_valid_irq_states_for_def valid_irq_states_but_def valid_irq_masks_but_def valid_machine_state_def cur_tcb_def valid_irq_states_def valid_irq_masks_def)
  done

lemma set_irq_state_invs[wp]:
  "\<lbrace>\<lambda>s. invs s \<and> (state \<noteq> irq_state.IRQNotifyAEP \<longrightarrow> cap.IRQHandlerCap irq \<notin> ran (caps_of_state s))\<rbrace>
      set_irq_state state irq
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: set_irq_state_def)
  apply (wp dmo_maskInterrupt_invs)
  apply (clarsimp simp: invs_def valid_state_def cur_tcb_def valid_mdb_def all_invs_but_valid_irq_states_for_def)
  apply (simp add: mdb_cte_at_def valid_irq_node_def
                   valid_irq_handlers_def irq_issued_def)
  apply (rule conjI)
   apply fastforce
  apply (rule conjI)
  apply  (clarsimp simp: cap_irqs_def cap_irq_opt_def 
             split: cap.split_asm)
  apply(clarsimp simp: valid_machine_state_def valid_irq_states_but_def valid_irq_masks_but_def, blast elim: valid_irq_statesE)
  done

lemmas ucast_ucast_mask8 = ucast_ucast_mask[where 'a=8, simplified, symmetric]

end
