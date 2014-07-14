(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(NICTA_GPL)
 *)

theory Arch_IF
imports Retype_IF
begin

abbreviation irq_state_of_state :: "det_state \<Rightarrow> nat" where
  "irq_state_of_state s \<equiv> irq_state (machine_state s)"

lemma do_extended_op_irq_state_of_state[wp]:
  "\<lbrace>\<lambda>s. P (irq_state_of_state s)\<rbrace> do_extended_op f \<lbrace>\<lambda>_ s. P (irq_state_of_state s)\<rbrace>"
  apply(wp dxo_wp_weak)
  apply simp
  done

lemma no_irq_underlying_memory_update[simp]:
  "no_irq (modify (underlying_memory_update f))"
  apply(simp add: no_irq_def | wp modify_wp | clarsimp)+
  done

crunch irq_state_of_state[wp]: cap_insert "\<lambda>s. P (irq_state_of_state s)"
  (wp: crunch_wps)


crunch irq_state_of_state[wp]: set_extra_badge "\<lambda>s. P (irq_state_of_state s)"
  (wp: crunch_wps dmo_wp simp: storeWord_def)



lemma transfer_caps_loop_irq_state[wp]:
  "\<lbrace>\<lambda>s. P (irq_state_of_state s)\<rbrace> transfer_caps_loop a b c d e f g \<lbrace>\<lambda>_ s. P (irq_state_of_state s)\<rbrace>"
  apply(wp transfer_caps_loop_pres)
  done

crunch irq_state_of_state[wp]: handle_wait "\<lambda>s. P (irq_state_of_state s)"
  (wp: crunch_wps dmo_wp simp: crunch_simps maskInterrupt_def unless_def store_word_offs_def storeWord_def ignore: const_on_failure)

crunch irq_state_of_state[wp]: handle_reply "\<lambda>s. P (irq_state_of_state s)"
  (wp: crunch_wps dmo_wp simp: crunch_simps maskInterrupt_def unless_def store_word_offs_def storeWord_def ignore: const_on_failure)

crunch irq_state_of_state[wp]: handle_vm_fault "\<lambda>s. P (irq_state_of_state s)"
  (wp: crunch_wps dmo_wp simp: crunch_simps maskInterrupt_def unless_def store_word_offs_def storeWord_def ignore: const_on_failure getFAR getDFSR getIFSR simp: getDFSR_def no_irq_getFAR getFAR_def getIFSR_def)


lemma irq_state_clearExMonitor[wp]: "\<lbrace> \<lambda>s. P (irq_state s) \<rbrace> clearExMonitor \<lbrace> \<lambda>_ s. P (irq_state s) \<rbrace>"
  apply (simp add: clearExMonitor_def | wp modify_wp)+
  done

crunch irq_state_of_state[wp]: schedule "\<lambda>(s::det_state). P (irq_state_of_state s)"
  (wp: dmo_wp modify_wp crunch_wps hoare_whenE_wp
       simp: invalidateTLB_ASID_def setHardwareASID_def setCurrentPD_def
             machine_op_lift_def machine_rest_lift_def crunch_simps storeWord_def)

crunch irq_state_of_state[wp]: reply_from_kernel "\<lambda>s. P (irq_state_of_state s)"

crunch irq_state_of_state[wp]: send_async_ipc "\<lambda>s. P (irq_state_of_state s)"

lemma detype_irq_state_of_state[simp]:
  "irq_state_of_state (detype S s) = irq_state_of_state s"
  apply(simp add: detype_def)
  done

crunch irq_state_of_state[wp]: invoke_untyped "\<lambda>s. P (irq_state_of_state s)"
  (wp: dmo_wp modify_wp crunch_wps simp: crunch_simps ignore: freeMemory simp: freeMemory_def storeWord_def clearMemory_def machine_op_lift_def machine_rest_lift_def mapM_x_defsym)

crunch irq_state_of_state[wp]: invoke_irq_control "\<lambda>s. P (irq_state_of_state s)"

crunch irq_state_of_state[wp]: invoke_irq_handler "\<lambda>s. P (irq_state_of_state s)"
  (wp: dmo_wp simp: maskInterrupt_def)

crunch irq_state'[wp]: cleanCacheRange_PoU "\<lambda> s. P (irq_state s)"
  (wp: crunch_wps ignore: ignore_failure)


crunch irq_state_of_state[wp]: arch_perform_invocation "\<lambda>(s::det_state). P (irq_state_of_state s)"
  (wp: dmo_wp modify_wp simp: setCurrentPD_def invalidateTLB_ASID_def invalidateTLB_VAASID_def cleanByVA_PoU_def do_flush_def cache_machine_op_defs do_flush_defs wp: crunch_wps simp: crunch_simps ignore: ignore_failure)

crunch irq_state_of_state[wp]: finalise_cap "\<lambda>(s::det_state). P (irq_state_of_state s)"
  (wp: select_wp modify_wp crunch_wps dmo_wp simp: crunch_simps invalidateTLB_ASID_def cleanCaches_PoU_def dsb_def invalidate_I_PoU_def clean_D_PoU_def)


crunch irq_state_of_state[wp]: cap_swap_for_delete "\<lambda>(s::det_state). P (irq_state_of_state s)"

crunch irq_state_of_state[wp]: load_hw_asid "\<lambda>(s::det_state). P (irq_state_of_state s)"

crunch irq_state_of_state[wp]: recycle_cap "\<lambda>(s::det_state). P (irq_state_of_state s)"
  (wp: crunch_wps dmo_wp modify_wp simp: filterM_mapM crunch_simps no_irq_clearMemory simp: clearMemory_def storeWord_def invalidateTLB_ASID_def 
   ignore: filterM)

crunch irq_state_of_state[wp]: restart,invoke_domain "\<lambda>(s::det_state). P (irq_state_of_state s)"

subsection "reads_equiv"

(* this to go in InfloFlowBase? *)
lemma get_object_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag \<top>\<top> \<top> (get_object ptr)"
  unfolding get_object_def
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_guard_imp)
     apply(rule gets_kheap_revrv')
    apply(simp, simp)
   apply(rule equiv_valid_2_bind)
      apply(rule return_ev2)
      apply(simp)
     apply(rule assert_ev2)
     apply(simp)
    apply(wp)
   apply fastforce+
   done

lemma get_object_revrv':
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag
   (\<lambda>rv rv'. aag_can_read aag ptr \<longrightarrow> rv = rv')
   \<top> (get_object ptr)"
  unfolding get_object_def
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_guard_imp)
     apply(rule gets_kheap_revrv)
    apply(simp, simp)
   apply(rule equiv_valid_2_bind)
      apply(rule return_ev2)
      apply(simp)
     apply(rule assert_ev2)
     apply(simp add: equiv_for_def)
    apply(wp)
   apply fastforce+
   done

lemma get_asid_pool_revrv':
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag 
   (\<lambda>rv rv'. aag_can_read aag ptr \<longrightarrow> rv = rv')
   \<top> (get_asid_pool ptr)"
  unfolding get_asid_pool_def
  apply(rule_tac W="\<lambda>rv rv'. aag_can_read aag ptr \<longrightarrow>rv = rv'" in equiv_valid_rv_bind)
    apply(rule get_object_revrv')
   apply(case_tac "aag_can_read aag ptr")
    apply(simp)
    apply(case_tac rv')
        apply(simp | rule fail_ev2_l)+
    apply(case_tac arch_kernel_obj)
       apply(simp | rule return_ev2 | rule fail_ev2_l)+
   apply(clarsimp simp: equiv_valid_2_def)
   apply(case_tac rv)
       apply(clarsimp simp: fail_def)+
   apply(case_tac rv')
       apply(clarsimp simp: fail_def)+
   apply(case_tac arch_kernel_obj)
      apply(case_tac arch_kernel_obja)
         apply(clarsimp simp: fail_def return_def)+
  apply(rule get_object_inv)
  done

lemma get_pt_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag \<top>\<top> \<top> (get_pt ptr)"
  unfolding get_pt_def
  apply(rule equiv_valid_rv_bind)
    apply(rule get_object_revrv)
   apply(simp)
   apply(case_tac rv)
       apply(simp | rule fail_ev2_l)+
   apply(case_tac rv')
      apply(simp | rule fail_ev2_r)+
   apply(case_tac arch_kernel_obj)
       apply(simp | rule fail_ev2_l)+
      apply(case_tac arch_kernel_obja)
         apply(simp | rule fail_ev2_r | rule return_ev2)+
    apply(case_tac arch_kernel_obja)
       apply(simp | rule fail_ev2_l)+
  apply(rule get_object_inv)
  done

lemma set_pt_reads_respects:
  "reads_respects aag l \<top> (set_pt ptr pt)"
  unfolding set_pt_def
  apply(subst equiv_valid_def2)
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_guard_imp)
     apply(rule get_object_revrv)
    apply(simp, simp)
   apply(rule equiv_valid_2_bind)
      apply(subst equiv_valid_def2[symmetric])
      apply(rule set_object_reads_respects)
     apply(rule assert_ev2, simp)
     apply(wp wp_post_taut | simp)+
     done

lemma get_pt_reads_respects:
  "reads_respects aag l (K (is_subject aag ptr)) (get_pt ptr)"
  unfolding get_pt_def
  apply(wp get_object_rev hoare_vcg_all_lift
       | wp_once hoare_drop_imps | simp | wpc)+
  done

lemma store_pte_reads_respects:
  "reads_respects aag l (K (is_subject aag (p && ~~ mask pt_bits)))
    (store_pte p pte)"
  unfolding store_pte_def fun_app_def
  apply(wp set_pt_reads_respects get_pt_reads_respects)
  apply(simp)
  done

lemma get_asid_pool_rev:
  "reads_equiv_valid_inv A aag (K (is_subject aag ptr)) (get_asid_pool ptr)"
  unfolding get_asid_pool_def
  apply(wp get_object_rev | wpc | simp)+
  done


lemma assertE_reads_respects:
  "reads_respects aag l \<top> (assertE P)"
  unfolding assertE_def
  apply(wp)
  apply(simp)
  done

lemma gets_applyE:
  "liftE (gets f) >>=E (\<lambda> f. g (f x)) = liftE (gets_apply f x) >>=E g"
  apply(simp add: liftE_bindE)
  apply(rule gets_apply)
  done

lemma gets_apply_wp:
  "\<lbrace>\<lambda> s. P (f s x) s\<rbrace> gets_apply f x \<lbrace>P\<rbrace>"
  apply(simp add: gets_apply_def)
  apply wp
  done


lemma aag_can_read_own_asids:
  "is_subject_asid aag asid \<Longrightarrow> aag_can_read_asid aag asid"
  apply(drule sym)
  apply simp
  apply(rule reads_lrefl)
  done


lemma get_asid_pool_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag
         (\<lambda>rv rv'. rv (ucast asid) = rv' (ucast asid))
         (\<lambda>s. Some a = arm_asid_table (arch_state s) (asid_high_bits_of asid) \<and>  
          is_subject_asid aag asid \<and> asid \<noteq> 0)
         (get_asid_pool a)"
  unfolding get_asid_pool_def
  apply(rule equiv_valid_rv_guard_imp)
   apply(rule_tac R'="\<lambda> rv rv'. \<forall> asid_pool asid_pool'. rv= ArchObj (ASIDPool asid_pool) \<and> rv'= ArchObj (ASIDPool asid_pool') \<longrightarrow> asid_pool (ucast asid) = asid_pool' (ucast asid)" and P="\<lambda>s. Some a = arm_asid_table (arch_state s) (asid_high_bits_of asid) \<and>  
          is_subject_asid aag asid \<and> asid \<noteq> 0" and P'="\<lambda>s. Some a = arm_asid_table (arch_state s) (asid_high_bits_of asid) \<and>  
          is_subject_asid aag asid \<and> asid \<noteq> 0" in equiv_valid_2_bind)
      apply(clarsimp split: kernel_object.splits arch_kernel_obj.splits simp: fail_ev2_l fail_ev2_r return_ev2)
     apply(clarsimp simp: get_object_def gets_def assert_def bind_def put_def get_def equiv_valid_2_def return_def fail_def split: split_if)
     apply(erule reads_equivE)
     apply(clarsimp simp: equiv_asids_def equiv_asid_def asid_pool_at_kheap)
     apply(drule aag_can_read_own_asids)
     apply(drule_tac s="Some a" in sym)
     apply blast
    apply (wp wp_post_taut | simp)+
  done

lemma asid_high_bits_0_eq_1:
  "asid_high_bits_of 0 = asid_high_bits_of 1" by (auto simp: asid_high_bits_of_def asid_low_bits_def)



lemma requiv_arm_asid_table_asid_high_bits_of_asid_eq:
  "\<lbrakk>is_subject_asid aag asid; reads_equiv aag s t; asid \<noteq> 0\<rbrakk> \<Longrightarrow>
               arm_asid_table (arch_state s) (asid_high_bits_of asid) =
               arm_asid_table (arch_state t) (asid_high_bits_of asid)"
  apply(erule reads_equivE)
  apply(fastforce simp: equiv_asids_def equiv_asid_def intro: aag_can_read_own_asids)
  done

lemma find_pd_for_asid_reads_respects:
  "reads_respects aag l (K (is_subject_asid aag asid)) (find_pd_for_asid asid)"
  apply(simp add: find_pd_for_asid_def)
  apply(subst gets_applyE)
  (* everything up to and including get_asid_pool, both executions are the same.
     it is only get_asid_pool that can return different values and for which we need
     to go equiv_valid_2. We rewrite using associativity to make the decomposition
     easier *)
  apply(subst bindE_assoc[symmetric])+
  apply(simp add: equiv_valid_def2)
  apply(subst rel_sum_comb_equals[symmetric])
  apply(rule equiv_valid_rv_guard_imp)
   apply(rule_tac R'="\<lambda> rv rv'. rv (ucast asid) = rv' (ucast asid)" and Q="\<top>\<top>" and Q'="\<top>\<top>" in equiv_valid_2_bindE)
      apply(clarsimp split: option.splits simp: throwError_def returnOk_def)
      apply(intro conjI impI allI)
       apply(rule return_ev2, simp)
      apply(rule return_ev2, simp)
     apply wp
   apply(rule_tac R'="op =" and Q="\<lambda> rv s. rv = (arm_asid_table (arch_state s)) (asid_high_bits_of asid) \<and> is_subject_asid aag asid \<and> asid \<noteq> 0" and Q'="\<lambda> rv s. rv = (arm_asid_table (arch_state s)) (asid_high_bits_of asid) \<and> is_subject_asid aag asid \<and> asid \<noteq> 0" in equiv_valid_2_bindE)
      apply (simp add: equiv_valid_def2[symmetric])
      apply (split option.splits)      
      apply (intro conjI impI allI)
       apply (simp add: throwError_def)
       apply (rule return_ev2, simp)
      apply(rule equiv_valid_2_liftE)
      apply(clarsimp)
      apply(rule get_asid_pool_revrv)
     apply(wp gets_apply_wp)
   apply(subst rel_sum_comb_equals)
   apply(subst equiv_valid_def2[symmetric])
   apply(wp gets_apply_ev | simp)+
  apply(fastforce intro: requiv_arm_asid_table_asid_high_bits_of_asid_eq)
  done

lemma find_pd_for_asid_assert_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and
    K (is_subject_asid aag asid))
  (find_pd_for_asid_assert asid)"
  unfolding find_pd_for_asid_assert_def catch_def
  apply(wp get_pde_rev find_pd_for_asid_reads_respects hoare_vcg_all_lift
       | wpc | simp)+
    (* need to be careful -- wp gets stuck if we put the drop_imps in above *)
    apply(rule hoare_drop_imps)
   apply(rule hoare_vcg_all_lift)
   apply(rule hoare_post_taut)
   apply(rule validE_cases_valid)
   apply(simp)
   apply(rule validE_R_validE)
   apply(rule_tac Q'="\<lambda>rv s. is_subject aag (lookup_pd_slot rv 0 && ~~ mask pd_bits)" in hoare_post_imp_R)
    apply(rule find_pd_for_asid_pd_slot_authorised)
   apply(subgoal_tac "lookup_pd_slot r 0 = r")
    apply(fastforce)
   apply(simp add: lookup_pd_slot_def)
  apply(fastforce)
  done

lemma modify_arm_hwasid_table_reads_respects:
  "reads_respects aag l \<top> (modify
          (\<lambda>s. s\<lparr>arch_state := arch_state s\<lparr>arm_hwasid_table := param\<rparr>\<rparr>))"
  apply(simp add: equiv_valid_def2)
  apply(rule modify_ev2)
  apply(auto simp: reads_equiv_def affects_equiv_def states_equiv_for_def equiv_for_def intro: equiv_asids_triv)
done

lemma modify_arm_asid_map_reads_respects:
  "reads_respects aag l \<top> (modify
          (\<lambda>s. s\<lparr>arch_state := arch_state s\<lparr>arm_asid_map := param\<rparr>\<rparr>))"
  apply(simp add: equiv_valid_def2)
  apply(rule modify_ev2)
  apply(auto simp: reads_equiv_def affects_equiv_def states_equiv_for_def equiv_for_def intro: equiv_asids_triv)
done

lemma modify_arm_next_asid_reads_respects:
  "reads_respects aag l \<top> (modify
          (\<lambda>s. s\<lparr>arch_state := arch_state s\<lparr>arm_next_asid := param\<rparr>\<rparr>))"
  apply(simp add: equiv_valid_def2)
  apply(rule modify_ev2)
  apply(auto simp: reads_equiv_def affects_equiv_def states_equiv_for_def equiv_for_def intro: equiv_asids_triv)
done

lemmas modify_arch_state_reads_respects = 
  modify_arm_asid_map_reads_respects
  modify_arm_hwasid_table_reads_respects
  modify_arm_next_asid_reads_respects

lemma states_equiv_for_arm_hwasid_table_update1:
  "states_equiv_for P Q R S X (s\<lparr> arch_state := (arch_state s)\<lparr> arm_hwasid_table := Y \<rparr>\<rparr>) t = states_equiv_for P Q R S X s t"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemma states_equiv_for_arm_hwasid_table_update2:
  "states_equiv_for P Q R S X t (s\<lparr> arch_state := (arch_state s)\<lparr> arm_hwasid_table := Y \<rparr>\<rparr>) = states_equiv_for P Q R S X t s"
  apply(rule iffI)
   apply(drule states_equiv_for_sym)
   apply(rule states_equiv_for_sym)
   apply(simp add: states_equiv_for_arm_hwasid_table_update1)
  apply(drule states_equiv_for_sym)
  apply(rule states_equiv_for_sym)
  apply(simp add: states_equiv_for_arm_hwasid_table_update1)
  done

lemma states_equiv_for_arm_hwasid_table_update':
  "states_equiv_for P Q R S X t (s\<lparr> arch_state := (arch_state s)\<lparr> arm_hwasid_table := Y \<rparr>\<rparr>) = states_equiv_for P Q R S X t s"
  apply(rule iffI)
   apply(drule states_equiv_for_sym)
   apply(rule states_equiv_for_sym)
   apply(simp add: states_equiv_for_arm_hwasid_table_update1)
  apply(drule states_equiv_for_sym)
  apply(rule states_equiv_for_sym)
  apply(simp add: states_equiv_for_arm_hwasid_table_update1)
  done

lemmas states_equiv_for_arm_hwasid_table_update = 
  states_equiv_for_arm_hwasid_table_update1
  states_equiv_for_arm_hwasid_table_update2


lemma states_equiv_for_arm_next_asid_update1:
  "states_equiv_for P Q R S X (s\<lparr> arch_state := (arch_state s)\<lparr> arm_next_asid := Y \<rparr>\<rparr>) t = states_equiv_for P Q R S X s t"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemma states_equiv_for_arm_next_asid_update2:
  "states_equiv_for P Q R S Y t (s\<lparr> arch_state := (arch_state s)\<lparr> arm_next_asid := X \<rparr>\<rparr>) = states_equiv_for P Q R S Y t s"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemmas states_equiv_for_arm_next_asid_update = 
  states_equiv_for_arm_next_asid_update1
  states_equiv_for_arm_next_asid_update2

lemma states_equiv_for_arm_asid_map_update1:
  "states_equiv_for P Q R S Y (s\<lparr> arch_state := (arch_state s)\<lparr> arm_asid_map := X \<rparr>\<rparr>) t = states_equiv_for P Q R S Y s t"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemma states_equiv_for_arm_asid_map_update2:
  "states_equiv_for P Q R S Y t (s\<lparr> arch_state := (arch_state s)\<lparr> arm_asid_map := X \<rparr>\<rparr>) = states_equiv_for P Q R S Y t s"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemmas states_equiv_for_arm_asid_map_update = 
  states_equiv_for_arm_asid_map_update1
  states_equiv_for_arm_asid_map_update2

(* FIXME: move *)
lemma equiv_valid_rv_trivial:
  assumes inv: "\<And> P. \<lbrace> P \<rbrace> f \<lbrace> \<lambda>_. P \<rbrace>"
  shows "equiv_valid_rv_inv I A \<top>\<top> \<top> f"
  by(auto simp: equiv_valid_2_def dest: state_unchanged[OF inv])

(*
(* this works while we don't have either arm_asid_map or arm_hwasid_table in the
   state relation because it doesn't read from either *)
lemma store_hw_asid_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and
    K (is_subject_asid aag asid))
  (store_hw_asid asid hw_asid)"
  unfolding store_hw_asid_def
  apply simp
  apply(rule bind_ev_pre)
     apply(subst equiv_valid_def2)     
     apply(rule equiv_valid_2_bind)
        apply(rule equiv_valid_2_bind)
           apply(rule equiv_valid_2_bind)
              apply(rule modify_ev2)
              apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_hwasid_table_update)
             apply(rule equiv_valid_rv_trivial)
             apply wp
          apply(rule modify_ev2)
          apply(rule conjI, rule TrueI)
          apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_asid_map_update)
         apply wp
       apply(rule equiv_valid_rv_trivial| wp find_pd_for_asid_assert_reads_respects | simp | rule conjI | rule TrueI)+
  done
  
       
(* these two unused for now, may be totally unusable because for the moment we
   are trying to assert that the relationship between hwasids and asids is 
   unobservable and so when we call these functions in two executions, it probably
   won't be the case that the arguments will be the same *)
lemma invalidate_hw_asid_entry_reads_respects:
  "reads_respects aag l \<top> (invalidate_hw_asid_entry hw_asid)"
  unfolding invalidate_hw_asid_entry_def
  apply(simp add: equiv_valid_def2)
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_trivial)
    apply wp
   apply(rule modify_ev2)
   apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_hwasid_table_update)
  by wp


lemma invalidate_asid_reads_respects:
  "reads_respects aag l \<top> (invalidate_asid asid)"
  unfolding invalidate_asid_def
  apply(simp add: equiv_valid_def2)
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_trivial)
    apply wp
   apply(rule modify_ev2)
   apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_asid_map_update)
  by wp
*)

(* FIXME: move *)
lemma equiv_valid_2_trivial:
  assumes inv: "\<And> P. \<lbrace> P \<rbrace> f \<lbrace> \<lambda>_. P \<rbrace>"
  assumes inv': "\<And> P. \<lbrace> P \<rbrace> f' \<lbrace> \<lambda>_. P \<rbrace>"
  shows "equiv_valid_2 I A A \<top>\<top> \<top> \<top> f f'"
  by(auto simp: equiv_valid_2_def dest: state_unchanged[OF inv] state_unchanged[OF inv'])

(*
lemma invalidate_hw_asid_entry_ev2:
  "equiv_valid_2 (reads_equiv aag) (affects_equiv aag l) (affects_equiv aag l) (op =) \<top> \<top> (invalidate_hw_asid_entry hw_asid) (invalidate_hw_asid_entry hw_asid')"
  unfolding invalidate_hw_asid_entry_def
  apply(rule equiv_valid_2_guard_imp)
    apply(rule_tac R'="\<top>\<top>" in equiv_valid_2_bind)
       apply(simp)
      apply(rule modify_ev2)
      apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_hwasid_table_update)
     apply(rule equiv_valid_2_trivial, wp, simp+)
  done


lemma invalidate_asid_ev2:
  "equiv_valid_2 (reads_equiv aag) (affects_equiv aag l) (affects_equiv aag l) (op =) \<top> \<top> (invalidate_asid asid) (invalidate_asid asid')"
  unfolding invalidate_asid_def
  apply(rule equiv_valid_2_guard_imp)
    apply(rule_tac R'="\<top>\<top>" in equiv_valid_2_bind)
       apply(simp)
      apply(rule modify_ev2)
      apply(clarsimp simp: reads_equiv_def affects_equiv_def states_equiv_for_arm_asid_map_update)
     apply(rule equiv_valid_2_trivial, wp, simp+)
  done
*)

(* for things that only modify parts of the state not in the state relations,
   we don't care what they read since these reads are unobservable anyway;
   however, we cannot assert anything about their return-values *)
lemma equiv_valid_2_unobservable:
  assumes f: 
    "\<And> P Q R S X st. \<lbrace> states_equiv_for P Q R S X st \<rbrace> f \<lbrace>\<lambda>_. states_equiv_for P Q R S X st\<rbrace>"
  assumes f': 
    "\<And> P Q R S X st. \<lbrace> states_equiv_for P Q R S X st \<rbrace> f' \<lbrace>\<lambda>_. states_equiv_for P Q R S X st\<rbrace>"
  assumes g:
    "\<And> P. \<lbrace> \<lambda> s. P (cur_thread s) \<rbrace> f \<lbrace> \<lambda> rv s. P (cur_thread s) \<rbrace>"
  assumes g':
    "\<And> P. \<lbrace> \<lambda> s. P (cur_thread s) \<rbrace> f' \<lbrace> \<lambda> rv s. P (cur_thread s) \<rbrace>"
  assumes h:
    "\<And> P. \<lbrace> \<lambda> s. P (cur_domain s) \<rbrace> f \<lbrace> \<lambda> rv s. P (cur_domain s) \<rbrace>"
  assumes h':
    "\<And> P. \<lbrace> \<lambda> s. P (cur_domain s) \<rbrace> f' \<lbrace> \<lambda> rv s. P (cur_domain s) \<rbrace>"
  assumes j:
    "\<And> P. \<lbrace> \<lambda> s. P (scheduler_action s) \<rbrace> f \<lbrace> \<lambda> rv s. P (scheduler_action s) \<rbrace>"
  assumes j':
    "\<And> P. \<lbrace> \<lambda> s. P (scheduler_action s) \<rbrace> f' \<lbrace> \<lambda> rv s. P (scheduler_action s) \<rbrace>"
  assumes k:
    "\<And> P. \<lbrace> \<lambda> s. P (work_units_completed s) \<rbrace> f \<lbrace> \<lambda> rv s. P (work_units_completed s) \<rbrace>"
  assumes k':
    "\<And> P. \<lbrace> \<lambda> s. P (work_units_completed s) \<rbrace> f' \<lbrace> \<lambda> rv s. P (work_units_completed s) \<rbrace>"
  assumes l:
    "\<And> P. \<lbrace> \<lambda> s. P (irq_state (machine_state s)) \<rbrace> f \<lbrace> \<lambda> rv s. P (irq_state (machine_state s)) \<rbrace>"
  assumes l':
    "\<And> P. \<lbrace> \<lambda> s. P (irq_state (machine_state s)) \<rbrace> f' \<lbrace> \<lambda> rv s. P (irq_state (machine_state s)) \<rbrace>"

  shows
    "equiv_valid_2 (reads_equiv aag) (affects_equiv aag l) (affects_equiv aag l) \<top>\<top> \<top> \<top> f f'"
  apply(clarsimp simp: equiv_valid_2_def)
  apply(frule use_valid[OF _ f])
   apply(rule states_equiv_for_refl)
  apply(frule use_valid[OF _ f'])
   apply(rule states_equiv_for_refl)
  apply(frule use_valid[OF _ f])
   apply(rule states_equiv_for_refl)
  apply(frule use_valid[OF _ f'])
   apply(rule states_equiv_for_refl)
  apply(frule use_valid)
    apply(rule_tac P="op = (cur_thread s)" in g)
   apply(rule refl)
  apply(frule_tac f=f' in use_valid)
    apply(rule_tac P="op = (cur_thread t)" in g')
   apply(rule refl)
  apply(frule use_valid)
    apply(rule_tac P="op = (cur_domain s)" in h)
   apply(rule refl)
  apply(frule_tac f=f' in use_valid)
    apply(rule_tac P="op = (cur_domain t)" in h')
   apply(rule refl)
  apply(frule use_valid)
    apply(rule_tac P="op = (scheduler_action s)" in j)
   apply(rule refl)
  apply(frule_tac f=f' in use_valid)
    apply(rule_tac P="op = (scheduler_action t)" in j')
   apply(rule refl)
  apply(frule use_valid)
    apply(rule_tac P="op = (work_units_completed s)" in k)
   apply(rule refl)
  apply(frule_tac f=f' in use_valid)
    apply(rule_tac P="op = (work_units_completed t)" in k')
   apply(rule refl)
  apply(frule use_valid)
    apply(rule_tac P="op = (irq_state (machine_state s))" in l)
   apply(rule refl)
  apply(frule_tac f=f' in use_valid)
    apply(rule_tac P="op = (irq_state (machine_state t))" in l')
   apply(rule refl)

  apply(clarsimp simp: reads_equiv_def2 affects_equiv_def2)
  apply(auto intro: states_equiv_for_sym states_equiv_for_trans)
  done


crunch states_equiv_for: invalidate_hw_asid_entry "states_equiv_for P Q R S X st"
  (simp: states_equiv_for_arm_hwasid_table_update)

crunch states_equiv_for: invalidate_asid "states_equiv_for P Q R S X st"
  (simp: states_equiv_for_arm_asid_map_update)

crunch cur_thread: invalidate_hw_asid_entry "\<lambda> s. P (cur_thread s)"

crunch cur_thread: invalidate_asid "\<lambda> s. P (cur_thread s)"

lemma mol_states_equiv_for:
  "\<lbrace>\<lambda>ms. states_equiv_for P Q R S X st (s\<lparr>machine_state := ms\<rparr>)\<rbrace> machine_op_lift mop \<lbrace>\<lambda>a b. states_equiv_for P Q R S X st (s\<lparr>machine_state := b\<rparr>)\<rbrace>"
  unfolding machine_op_lift_def 
  apply (simp add: machine_rest_lift_def split_def)
  apply (wp modify_wp)
  apply (clarsimp simp: states_equiv_for_def)
  apply (clarsimp simp: equiv_asids_def equiv_asid_def)
  apply (fastforce elim!: equiv_forE intro!: equiv_forI)
  done

lemma do_machine_op_mol_states_equiv_for:
  "invariant (do_machine_op (machine_op_lift f)) (states_equiv_for P Q R S X st)"
  apply(simp add: do_machine_op_def)
  apply(wp modify_wp | simp add: split_def)+
  apply(clarify)
  apply(erule use_valid)
   apply simp
   apply(rule mol_states_equiv_for)
  by simp


(* we don't care about the relationship between virtual and hardware asids at all --
   these should be unobservable, so rightly we don't expect this one to satisfy
   reads_respects but instead the weaker property where we assert no relation on
   the return values *)
lemma find_free_hw_asid_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag \<top>\<top> \<top> (find_free_hw_asid)"
  unfolding find_free_hw_asid_def fun_app_def invalidateTLB_ASID_def
  apply(rule equiv_valid_2_unobservable)
     apply (wp modify_wp invalidate_hw_asid_entry_states_equiv_for 
               do_machine_op_mol_states_equiv_for
               invalidate_asid_states_equiv_for
               invalidate_hw_asid_entry_cur_thread invalidate_asid_cur_thread dmo_wp
           | wpc 
           | simp add: states_equiv_for_arm_asid_map_update 
                       states_equiv_for_arm_hwasid_table_update 
                       states_equiv_for_arm_next_asid_update)+
  done

lemma load_hw_asid_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag \<top>\<top> \<top> (load_hw_asid asid)"

  apply(rule equiv_valid_2_unobservable)
     apply(simp add: load_hw_asid_def | wp)+
  done
  
lemma states_equiv_for_arch_update1:
  "\<lbrakk>arm_globals_frame A = arm_globals_frame (arch_state s);
    arm_asid_table A = arm_asid_table (arch_state s)\<rbrakk> \<Longrightarrow> 
    states_equiv_for P Q R S X (s\<lparr> arch_state := A\<rparr>) t =
    states_equiv_for P Q R S X s t"
  apply(clarsimp simp: states_equiv_for_def equiv_for_def equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemma states_equiv_for_arch_update2:
  "\<lbrakk>arm_globals_frame A = arm_globals_frame (arch_state s);
    arm_asid_table A = arm_asid_table (arch_state s)\<rbrakk> \<Longrightarrow> 
    states_equiv_for P Q R S X t (s\<lparr> arch_state := A\<rparr>) =
    states_equiv_for P Q R S X t s"
  apply(rule iffI)
   apply(drule states_equiv_for_sym)
   apply(rule states_equiv_for_sym)
   apply(simp add: states_equiv_for_arch_update1)
  apply(drule states_equiv_for_sym)
  apply(rule states_equiv_for_sym)
  apply(simp add: states_equiv_for_arch_update1)
  done

lemmas states_equiv_for_arch_update = states_equiv_for_arch_update1 states_equiv_for_arch_update2

crunch states_equiv_for: store_hw_asid "states_equiv_for P Q R S X st"
  (simp: states_equiv_for_arch_update)

lemma find_free_hw_asid_states_equiv_for:
  "invariant (find_free_hw_asid) (states_equiv_for P Q R S X st)"
  apply(simp add: find_free_hw_asid_def)
  apply(wp modify_wp invalidate_hw_asid_entry_states_equiv_for do_machine_op_mol_states_equiv_for invalidate_asid_states_equiv_for | wpc | simp add: states_equiv_for_arm_next_asid_update invalidateTLB_ASID_def)+
  done

crunch states_equiv_for: get_hw_asid "states_equiv_for P Q R S X st"

lemma reads_respects_unobservable_unit_return:
  assumes f: 
    "\<And> P Q R S X st. \<lbrace> states_equiv_for P Q R S X st \<rbrace> f \<lbrace>\<lambda>_. states_equiv_for P Q R S X st\<rbrace>"
  assumes g:
    "\<And> P. \<lbrace> \<lambda> s. P (cur_thread s) \<rbrace> f \<lbrace> \<lambda> rv s. P (cur_thread s) \<rbrace>"
  assumes h:
    "\<And> P. \<lbrace> \<lambda> s. P (cur_domain s) \<rbrace> f \<lbrace> \<lambda> rv s. P (cur_domain s) \<rbrace>"
  assumes j:
    "\<And> P. \<lbrace> \<lambda> s. P (scheduler_action s) \<rbrace> f \<lbrace> \<lambda> rv s. P (scheduler_action s) \<rbrace>"
  assumes k:
    "\<And> P. \<lbrace> \<lambda> s. P (work_units_completed s) \<rbrace> f \<lbrace> \<lambda> rv s. P (work_units_completed s) \<rbrace>"
  assumes l:
    "\<And> P. \<lbrace> \<lambda> s. P (irq_state_of_state s) \<rbrace> f \<lbrace> \<lambda> rv s. P (irq_state_of_state s) \<rbrace>"

  shows
    "reads_respects aag l \<top> (f::(unit,det_ext) s_monad)"
  apply(subgoal_tac "reads_equiv_valid_rv_inv (affects_equiv aag l) aag \<top>\<top> \<top> f")
   apply(clarsimp simp: equiv_valid_2_def equiv_valid_def2)
  apply(rule equiv_valid_2_unobservable[OF f f g g h h j j k k l l])
  done

crunch cur_thread: get_hw_asid "\<lambda> s. P (cur_thread s)"

lemma dmo_mol_irq_state_of_state[wp]:
  "\<And>P. \<lbrace>\<lambda>s. P (irq_state_of_state s) \<rbrace> do_machine_op (machine_op_lift m)
       \<lbrace>\<lambda>_ s. P (irq_state_of_state s) \<rbrace>"
  apply(wp dmo_wp | simp)+
  done

lemma set_current_asid_reads_respects:
  "reads_respects aag l \<top> (set_current_asid asid)"
  unfolding set_current_asid_def
  apply(rule equiv_valid_guard_imp)
  apply(rule reads_respects_unobservable_unit_return)
    apply (wp do_machine_op_mol_states_equiv_for get_hw_asid_states_equiv_for get_hw_asid_cur_thread | simp add: setHardwareASID_def)+
  done

lemma gets_arm_global_pd_bind_setCurrentPD_reads_respects:
  "reads_respects aag l \<top> ( do global_pd \<leftarrow> gets (arm_global_pd \<circ> arch_state);
                  do_machine_op
                   (machine_op_lift (setCurrentPD_impl (addrFromPPtr global_pd)))
               od)"
  apply(rule reads_respects_unobservable_unit_return)
   apply (wp do_machine_op_mol_states_equiv_for)+
  done


lemma set_current_asid_states_equiv_for:
  "invariant (set_current_asid asid) (states_equiv_for P Q R S X st)"
  unfolding set_current_asid_def
  apply (wp do_machine_op_mol_states_equiv_for get_hw_asid_states_equiv_for | simp add: setHardwareASID_def)+
  done

crunch states_equiv_for: find_pd_for_asid "states_equiv_for P Q R S X st"

lemma set_vm_root_states_equiv_for:
  "invariant (set_vm_root thread) (states_equiv_for P Q R S X st)"
  unfolding set_vm_root_def catch_def fun_app_def setCurrentPD_def
  apply (wp_once hoare_drop_imps
        |wp do_machine_op_mol_states_equiv_for hoare_vcg_all_lift set_current_asid_states_equiv_for hoare_whenE_wp | wpc | simp)+
     apply(rule hoare_post_imp_R)
      apply(rule valid_validE_R)
      apply(wp find_pd_for_asid_states_equiv_for hoare_drop_imps set_current_asid_states_equiv_for do_machine_op_mol_states_equiv_for hoare_whenE_wp | simp | wpc)+
    apply(rule hoare_post_imp_R)
     apply(rule valid_validE_R)
     apply(wp find_pd_for_asid_states_equiv_for get_cap_wp | simp)+
  done

crunch cur_thread: set_vm_root "\<lambda> s. P (cur_thread s)"
  (wp: crunch_wps simp: crunch_simps)

crunch sched_act: set_vm_root "\<lambda> s. P (scheduler_action s)"
  (wp: crunch_wps simp: crunch_simps)

crunch wuc: set_vm_root "\<lambda> s. P (work_units_completed s)"
  (wp: crunch_wps simp: crunch_simps)

lemma set_vm_root_reads_respects:
  "reads_respects aag l \<top> (set_vm_root tcb)"
  apply(rule reads_respects_unobservable_unit_return)
       apply(rule set_vm_root_states_equiv_for)
      apply(rule set_vm_root_cur_thread)
     apply(rule set_vm_root_cur_domain)
    apply(rule set_vm_root_sched_act)
   apply(rule set_vm_root_wuc)
  apply wp
  done

lemma get_pte_reads_respects:
  "reads_respects aag l (K (is_subject aag (ptr && ~~ mask pt_bits))) (get_pte ptr)"
  unfolding get_pte_def fun_app_def
  apply(wp get_pt_reads_respects)
  apply(simp)
  done  

lemma gets_cur_thread_revrv:
  "reads_equiv_valid_rv_inv (affects_equiv aag l) aag op = \<top> (gets cur_thread)"
  apply(rule equiv_valid_rv_guard_imp)
   apply(rule gets_evrv)
  apply(fastforce simp: equiv_for_comp[symmetric] equiv_for_or or_comp_dist elim: reads_equivE affects_equivE)
  done

crunch states_equiv_for: set_vm_root_for_flush "states_equiv_for P Q R S X st"
  (wp: do_machine_op_mol_states_equiv_for ignore: do_machine_op simp: setCurrentPD_def)

crunch cur_thread: set_vm_root_for_flush "\<lambda> s. P (cur_thread s)"

lemma set_vm_root_for_flush_reads_respects:
  "reads_respects aag l (is_subject aag \<circ> cur_thread)
    (set_vm_root_for_flush pd asid)"
  unfolding set_vm_root_for_flush_def fun_app_def setCurrentPD_def
  apply(rule equiv_valid_guard_imp)
  apply (wp_once hoare_drop_imps
        |wp set_current_asid_reads_respects dmo_mol_reads_respects
            hoare_vcg_all_lift gets_cur_thread_ev get_cap_rev
        |wpc)+
  apply (clarsimp simp: reads_equiv_def)
  done

(* FIXME: move to EquivValid, write similar rules for the others *)
lemma mapM_ev'':
  assumes reads_res: "\<And> x. x \<in> set lst \<Longrightarrow> equiv_valid_inv D A (P x) (m x)"
  assumes inv: "\<And> x. x \<in> set lst \<Longrightarrow> invariant (m x) (\<lambda> s. \<forall>x\<in>set lst. P x s)"
  shows "equiv_valid_inv D A (\<lambda> s. \<forall>x\<in>set lst. P x s) (mapM m lst)"
  apply(rule mapM_ev)
  apply(rule equiv_valid_guard_imp[OF reads_res], simp+)
  apply(wp inv, simp)
  done

crunch states_equiv_for: flush_table "states_equiv_for P Q R S X st"
  (wp: crunch_wps do_machine_op_mol_states_equiv_for ignore: do_machine_op simp: invalidateTLB_ASID_def crunch_simps)

crunch cur_thread: flush_table "\<lambda> s. P (cur_thread s)"
  (wp: crunch_wps simp: crunch_simps)

crunch sched_act: flush_table "\<lambda> s. P (scheduler_action s)"
  (wp: crunch_wps simp: crunch_simps)

crunch wuc: flush_table "\<lambda> s. P (work_units_completed s)"
  (wp: crunch_wps simp: crunch_simps)

lemma flush_table_reads_respects:
  "reads_respects aag l \<top> (flush_table pd asid vptr pt)"
  apply(rule reads_respects_unobservable_unit_return)
       apply(rule flush_table_states_equiv_for)
      apply(rule flush_table_cur_thread)
     apply(rule flush_table_cur_domain)
    apply(rule flush_table_sched_act)
   apply(rule flush_table_wuc)
  apply wp
  done

lemma page_table_mapped_reads_respects:
  "reads_respects aag l
    (pas_refined aag and pspace_aligned
     and valid_arch_objs and K (is_subject_asid aag asid))
  (page_table_mapped asid vaddr pt)"
  unfolding page_table_mapped_def catch_def fun_app_def
  apply(wp get_pde_rev | wpc | simp)+
     apply(wp find_pd_for_asid_reads_respects | simp)+
  done

lemma catch_ev[wp]:
  assumes ok:
    "equiv_valid I A A P f"
  assumes err:
    "\<And> e. equiv_valid I A A (E e) (handler e)" 
  assumes hoare:
    "\<lbrace> P \<rbrace> f -, \<lbrace> E \<rbrace>"
  shows
  "equiv_valid I A A P (f <catch> handler)"
  apply(simp add: catch_def)
  apply (wp err ok | wpc | simp)+
   apply(insert hoare[simplified validE_E_def validE_def])[1]
   apply(simp split: sum.splits)
  by simp



lemma unmap_page_table_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and K (is_subject_asid aag asid))
   (unmap_page_table asid vaddr pt)"
  unfolding unmap_page_table_def fun_app_def page_table_mapped_def 
  apply(wp find_pd_for_asid_pd_slot_authorised 
           dmo_mol_reads_respects store_pde_reads_respects get_pde_rev get_pde_wp
           flush_table_reads_respects find_pd_for_asid_reads_respects hoare_vcg_all_lift_R catch_ev
       | wpc | simp add: cleanByVA_PoU_def | wp_once hoare_drop_imps)+
  done


lemma perform_page_table_invocation_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and K (authorised_page_table_inv aag pti))
    (perform_page_table_invocation pti)"
  unfolding perform_page_table_invocation_def fun_app_def cleanCacheRange_PoU_def
  apply(rule equiv_valid_guard_imp)
  apply(wp dmo_cacheRangeOp_reads_respects dmo_mol_reads_respects store_pde_reads_respects
           set_cap_reads_respects
           mapM_x_ev'' store_pte_reads_respects unmap_page_table_reads_respects get_cap_rev
       | wpc | simp add: cleanByVA_PoU_def)+
  apply(clarsimp simp: authorised_page_table_inv_def)
  apply(case_tac pti)
  apply auto
  done

lemma do_flush_reads_respects:
  "reads_respects aag l \<top> (do_machine_op (do_flush typ start end pstart))"
  apply (rule equiv_valid_guard_imp)
   apply (cases "typ")
      apply (wp dmo_mol_reads_respects dmo_cacheRangeOp_reads_respects | simp add: do_flush_def cache_machine_op_defs do_flush_defs dmo_bind_ev when_def | rule conjI | clarsimp)+
      done

lemma perform_page_directory_invocation_reads_respects:
  "reads_respects aag l (is_subject aag \<circ> cur_thread) (perform_page_directory_invocation pdi)"
  unfolding perform_page_directory_invocation_def
  apply (cases pdi)
  apply (wp do_flush_reads_respects set_vm_root_reads_respects set_vm_root_for_flush_reads_respects | simp add: when_def requiv_cur_thread_eq split del: split_if | wp_once hoare_drop_imps | clarsimp)+
  done

lemma throw_on_false_reads_respects:
  "reads_respects aag l P f \<Longrightarrow>
  reads_respects aag l P (throw_on_false ex f)"
  unfolding throw_on_false_def fun_app_def unlessE_def
  apply(wp | simp)+
  done

lemma check_mapping_pptr_reads_respects:
  "reads_respects aag l
    (K (\<forall>x.   (tablePtr = Inl x \<longrightarrow> is_subject aag (x && ~~ mask pt_bits))
            \<and> (tablePtr = Inr x \<longrightarrow> is_subject aag (x && ~~ mask pd_bits))))
  (check_mapping_pptr pptr pgsz tablePtr)"
  unfolding check_mapping_pptr_def fun_app_def
  apply(rule equiv_valid_guard_imp)
   apply(wp get_pte_reads_respects get_pde_rev | wpc)+
  apply(simp)
  done

lemma lookup_pt_slot_reads_respects:
  "reads_respects aag l (K (is_subject aag (lookup_pd_slot pd vptr && ~~ mask pd_bits))) (lookup_pt_slot pd vptr)"
  unfolding lookup_pt_slot_def fun_app_def
  apply(wp get_pde_rev | wpc | simp)+
  done

crunch cur_thread: flush_page "\<lambda>s. P (cur_thread s)"
  (wp: crunch_wps simp: if_apply_def2)

crunch sched_act: flush_page "\<lambda>s. P (scheduler_action s)"
  (wp: crunch_wps simp: if_apply_def2)

crunch wuc: flush_page "\<lambda>s. P (work_units_completed s)"
  (wp: crunch_wps simp: if_apply_def2)

crunch states_equiv_for: flush_page "states_equiv_for P Q R S X st"
  (wp: do_machine_op_mol_states_equiv_for crunch_wps ignore: do_machine_op simp: invalidateTLB_VAASID_def if_apply_def2)

lemma flush_page_reads_respects:
  "reads_respects aag l \<top> (flush_page page_size pd asid vptr)"
  apply (blast intro: reads_respects_unobservable_unit_return flush_page_states_equiv_for flush_page_cur_thread flush_page_cur_domain flush_page_sched_act flush_page_wuc flush_page_irq_state_of_state)
  done

(* clagged some help from unmap_page_respects in Arch_AC *)
lemma unmap_page_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and K (is_subject_asid aag asid \<and> vptr < kernel_base)) (unmap_page pgsz asid vptr pptr)"
  unfolding unmap_page_def catch_def fun_app_def cleanCacheRange_PoU_def
  apply (simp add: unmap_page_def swp_def cong: vmpage_size.case_cong)
  apply(wp dmo_mol_reads_respects dmo_cacheRangeOp_reads_respects
           store_pte_reads_respects[simplified] 
           check_mapping_pptr_reads_respects
           throw_on_false_reads_respects  lookup_pt_slot_reads_respects 
           lookup_pt_slot_authorised lookup_pt_slot_authorised2 
           store_pde_reads_respects[simplified] flush_page_reads_respects 
           find_pd_for_asid_reads_respects find_pd_for_asid_pd_slot_authorised
           mapM_ev''[
                     where m = "(\<lambda>a. store_pte a ARM_Structs_A.pte.InvalidPTE)" 
                       and P = "\<lambda>x s. is_subject aag (x && ~~ mask pt_bits)"]
           mapM_ev''[where m = "(\<lambda>a. store_pde a ARM_Structs_A.pde.InvalidPDE)" 
                       and P = "\<lambda>x s. is_subject aag (x && ~~ mask pd_bits)"]

       | wpc 
       | simp add: is_aligned_6_masks is_aligned_mask[symmetric] cleanByVA_PoU_def
       | wp_once hoare_drop_imps)+
  done

lemma dmo_mol_2_reads_respects:
  "reads_respects aag l \<top> (do_machine_op (machine_op_lift mop >>= (\<lambda> y. machine_op_lift mop')))"
  apply(rule use_spec_ev)
  apply(rule do_machine_op_spec_reads_respects)
  apply wp
     apply(rule machine_op_lift_ev)
    apply(rule machine_op_lift_ev)
   apply(rule wp_post_taut)
  by (wp | simp)+

lemma tl_subseteq: 
  "set (tl xs) \<subseteq> set xs"
  by (induct xs, auto)

lemma perform_page_invocation_reads_respects:
  "reads_respects aag l (pas_refined aag and K (authorised_page_inv aag pi) and valid_page_inv pi and valid_arch_objs and pspace_aligned and is_subject aag \<circ> cur_thread) (perform_page_invocation pi)"
  unfolding perform_page_invocation_def fun_app_def when_def cleanCacheRange_PoU_def
  apply(rule equiv_valid_guard_imp)
  apply wpc
      apply(simp add: mapM_discarded swp_def)
      apply (wp dmo_mol_reads_respects dmo_cacheRangeOp_reads_respects
                mapM_x_ev'' store_pte_reads_respects 
                set_cap_reads_respects mapM_ev'' store_pde_reads_respects 
                unmap_page_reads_respects set_vm_root_reads_respects 
                dmo_mol_2_reads_respects set_vm_root_for_flush_reads_respects get_cap_rev
                do_flush_reads_respects
            | simp add: cleanByVA_PoU_def | wpc | wp_once hoare_drop_imps[where R="\<lambda> r s. r"])+
  apply(clarsimp simp: authorised_page_inv_def valid_page_inv_def)
  apply (auto simp: cte_wp_at_caps_of_state is_arch_diminished_def valid_slots_def
                    cap_auth_conferred_def cap_rights_update_def acap_rights_update_def
                    update_map_data_def is_page_cap_def authorised_slots_def
                    valid_page_inv_def valid_cap_simps 
             dest!: diminished_PageCapD bspec[OF _ rev_subsetD[OF _ tl_subseteq]] 
       | auto dest!: clas_caps_of_state 
               simp: cap_links_asid_slot_def label_owns_asid_slot_def 
              dest!: pas_refined_Control)+
  done

lemma equiv_asids_arm_asid_table_update:
  "\<lbrakk>equiv_asids R s t; kheap s pool_ptr = kheap t pool_ptr\<rbrakk> \<Longrightarrow>
   equiv_asids R (s\<lparr>arch_state := arch_state s
                   \<lparr>arm_asid_table := arm_asid_table (arch_state s)
                      (asid_high_bits_of asid \<mapsto> pool_ptr)\<rparr>\<rparr>)
              (t\<lparr>arch_state := arch_state t
                   \<lparr>arm_asid_table := arm_asid_table (arch_state t)
                      (asid_high_bits_of asid \<mapsto> pool_ptr)\<rparr>\<rparr>)"
  apply(clarsimp simp: equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done


lemma arm_asid_table_update_reads_respects:
  "reads_respects aag l (K (is_subject aag pool_ptr))
        (do r \<leftarrow> gets (arm_asid_table \<circ> arch_state);
            modify
             (\<lambda>s. s\<lparr>arch_state := arch_state s
                      \<lparr>arm_asid_table := r(asid_high_bits_of asid \<mapsto> pool_ptr)\<rparr>\<rparr>)
         od)"
  apply(simp add: equiv_valid_def2)
  apply(rule_tac W="\<top>\<top>" and Q="\<lambda> rv s. is_subject aag pool_ptr \<and> rv = arm_asid_table (arch_state s)" in equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_guard_imp[OF equiv_valid_rv_trivial])
     apply wp
   apply(rule modify_ev2)
   apply clarsimp
   apply (drule(1) is_subject_kheap_eq[rotated])
   apply (auto simp add: reads_equiv_def2 affects_equiv_def2 states_equiv_for_def equiv_for_def intro!: equiv_asids_arm_asid_table_update)
   done


lemma my_bind_rewrite_lemma:
  "(f >>= g) =  (f >>= (\<lambda> r. (g r) >>= (\<lambda> x. return ())))"
  apply simp
  done

lemma delete_objects_reads_respects:
  "reads_respects aag l (\<lambda>_. True) (delete_objects p b)"
  apply (simp add: delete_objects_def)
  apply (wp detype_reads_respects dmo_freeMemory_reads_respects)
  apply simp
  done

lemma another_hacky_rewrite:
  "do a; (do x \<leftarrow> f; g x od); h; j od = do a; (f >>= g >>= (\<lambda>_. h)); j od"
  apply(simp add: bind_assoc[symmetric])
  done

lemma perform_asid_control_invocation_reads_respects:
  notes K_bind_ev[wp del]
  shows
  "reads_respects aag l (K (authorised_asid_control_inv aag aci))
  (perform_asid_control_invocation aci)"
  unfolding perform_asid_control_invocation_def
  apply(rule gen_asm_ev)
  apply(rule equiv_valid_guard_imp)
   (* we do some hacky rewriting here to separate out the bit that does interesting stuff from the rest *)
   apply(subst (6) my_bind_rewrite_lemma)
   apply(subst (1) bind_assoc[symmetric])
   apply(subst another_hacky_rewrite)
   apply(subst another_hacky_rewrite)
   apply(wpc)
   apply(rule bind_ev)
     apply(rule K_bind_ev)
     apply(rule_tac P'=\<top> in bind_ev)
       apply(rule K_bind_ev)
       apply(rule bind_ev)
         apply(rule bind_ev)
           apply(rule return_ev)
          apply(rule K_bind_ev)
          apply simp
          apply(rule arm_asid_table_update_reads_respects)
         apply (wp cap_insert_reads_respects retype_region_reads_respects
                   set_cap_reads_respects delete_objects_reads_respects get_cap_rev
               | simp add: authorised_asid_control_inv_def)+
  apply(auto dest!: is_aligned_no_overflow)
  done


lemma set_asid_pool_reads_respects:
  "reads_respects aag l \<top> (set_asid_pool ptr pool)"
  unfolding set_asid_pool_def
  apply(simp add: equiv_valid_def2)
  apply(rule equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_trivial, wp)
   apply(rule_tac Q="\<top>\<top>" and Q'="\<top>\<top>" in equiv_valid_2_bind)
      apply(fold equiv_valid_def2)
      apply(rule set_object_reads_respects)
     apply(rule assert_ev2, rule refl)
    apply (wp get_object_wp)
  apply(clarsimp, rule impI, rule TrueI)
  done
 
lemma perform_asid_pool_invocation_reads_respects:
  "reads_respects aag l (pas_refined aag and K (authorised_asid_pool_inv aag api))  (perform_asid_pool_invocation api)"
  unfolding perform_asid_pool_invocation_def
  apply(rule equiv_valid_guard_imp)
   apply(wp set_asid_pool_reads_respects set_cap_reads_respects
            get_asid_pool_rev get_cap_auth_wp[where aag=aag] get_cap_rev
        | wpc | simp)+
  apply(clarsimp simp: authorised_asid_pool_inv_def)
  done

lemma arch_perform_invocation_reads_respects:
  "reads_respects aag l (pas_refined aag and pspace_aligned and valid_arch_objs and K (authorised_arch_inv aag ai) and valid_arch_inv ai and is_subject aag \<circ> cur_thread) 
    (arch_perform_invocation ai)"
  unfolding arch_perform_invocation_def fun_app_def
  apply(wp perform_page_table_invocation_reads_respects perform_page_directory_invocation_reads_respects perform_page_invocation_reads_respects perform_asid_control_invocation_reads_respects perform_asid_pool_invocation_reads_respects | wpc)+
  apply(case_tac ai)
  apply(auto simp: authorised_arch_inv_def valid_arch_inv_def)
  done

lemma equiv_asids_arm_asid_table_delete:
  "\<lbrakk>equiv_asids R s t\<rbrakk> \<Longrightarrow>
   equiv_asids R (s\<lparr>arch_state := arch_state s
                   \<lparr>arm_asid_table :=
                        \<lambda>a. if a = asid_high_bits_of asid then None
                             else arm_asid_table (arch_state s) a\<rparr>\<rparr>)
              (t\<lparr>arch_state := arch_state t
                   \<lparr>arm_asid_table :=
                        \<lambda>a. if a = asid_high_bits_of asid then None
                             else arm_asid_table (arch_state t) a\<rparr>\<rparr>)"
  apply(clarsimp simp: equiv_asids_def equiv_asid_def asid_pool_at_kheap)
  done

lemma arm_asid_table_delete_ev2:
  "equiv_valid_2 (reads_equiv aag) (affects_equiv aag l) (affects_equiv aag l)
     \<top>\<top> (\<lambda>s. rv = arm_asid_table (arch_state s))
        (\<lambda>s. rv' = arm_asid_table (arch_state s))
          (modify
             (\<lambda>s. s\<lparr>arch_state := arch_state s
                      \<lparr>arm_asid_table :=
                        \<lambda>a. if a = asid_high_bits_of base then None
                             else rv a\<rparr>\<rparr>))
          (modify
             (\<lambda>s. s\<lparr>arch_state := arch_state s
                      \<lparr>arm_asid_table :=
                        \<lambda>a. if a = asid_high_bits_of base then None
                             else rv' a\<rparr>\<rparr>))"
  
   apply(rule modify_ev2)
   apply(auto simp: reads_equiv_def2 affects_equiv_def2 intro!: states_equiv_forI elim!: states_equiv_forE intro!: equiv_forI elim!: equiv_forE intro!: equiv_asids_arm_asid_table_delete elim: is_subject_kheap_eq[simplified reads_equiv_def2 states_equiv_for_def, rotated])
  done

crunch states_equiv_for: invalidate_asid_entry "states_equiv_for P Q R S x st"
crunch cur_thread: invalidate_asid_entry "\<lambda>s. P (cur_thread s)"
crunch sched_act: invalidate_asid_entry "\<lambda>s. P (scheduler_action s)"
crunch wuc: invalidate_asid_entry "\<lambda>s. P (work_units_completed s)"
crunch states_equiv_for: flush_space "states_equiv_for P Q R S x st"
  (wp: mol_states_equiv_for dmo_wp ignore: do_machine_op simp: invalidateTLB_ASID_def cleanCaches_PoU_def dsb_def invalidate_I_PoU_def clean_D_PoU_def)
crunch cur_thread: flush_space "\<lambda>s. P (cur_thread s)"
crunch sched_act: flush_space "\<lambda>s. P (scheduler_action s)"
crunch wuc: flush_space "\<lambda>s. P (work_units_completed s)"



  
lemma requiv_arm_asid_table_asid_high_bits_of_asid_eq':
  "\<lbrakk>(\<forall>asid'. asid' \<noteq> 0 \<and> asid_high_bits_of asid' = asid_high_bits_of base \<longrightarrow> is_subject_asid aag asid');reads_equiv aag s t\<rbrakk> \<Longrightarrow>
    arm_asid_table (arch_state s) (asid_high_bits_of base) =
    arm_asid_table (arch_state t) (asid_high_bits_of base)"
  apply (insert asid_high_bits_0_eq_1)
   apply(case_tac "base = 0")
    apply(subgoal_tac "is_subject_asid aag 1")
    apply simp
    apply (rule requiv_arm_asid_table_asid_high_bits_of_asid_eq[where aag=aag])
    apply (erule_tac x=1 in allE)
    apply simp+
    apply (rule requiv_arm_asid_table_asid_high_bits_of_asid_eq[where aag=aag])
    apply (erule_tac x=base in allE)
    apply simp+
done


lemma delete_asid_pool_reads_respects:
  "reads_respects aag l (K (\<forall>asid'. asid' \<noteq> 0 \<and> asid_high_bits_of asid' = asid_high_bits_of base \<longrightarrow> is_subject_asid aag asid')) (delete_asid_pool base ptr)"
  unfolding delete_asid_pool_def
  apply(rule equiv_valid_guard_imp)
   apply(rule bind_ev)
     apply(simp)
     apply(subst equiv_valid_def2)
     apply(rule_tac W="\<top>\<top>" and Q="\<lambda>rv s. rv = arm_asid_table (arch_state s)
        \<and> (\<forall>asid'. asid' \<noteq> 0 \<and> asid_high_bits_of asid' = asid_high_bits_of base \<longrightarrow> is_subject_asid aag asid')"
                     in equiv_valid_rv_bind)
       apply(rule equiv_valid_rv_guard_imp[OF equiv_valid_rv_trivial])
        apply(wp, simp)
      apply(simp add: when_def)
      apply(clarsimp | rule conjI)+
        apply(subst bind_assoc[symmetric])
        apply(subst (3) bind_assoc[symmetric])
        apply(rule equiv_valid_2_guard_imp)
          apply(rule equiv_valid_2_bind)
             apply(rule equiv_valid_2_bind)
                apply(rule equiv_valid_2_unobservable)
                   apply(wp set_vm_root_states_equiv_for set_vm_root_cur_thread)
               apply(rule arm_asid_table_delete_ev2)
              apply(wp)
            apply(rule equiv_valid_2_unobservable)
               apply(wp mapM_wp' invalidate_asid_entry_states_equiv_for flush_space_states_equiv_for invalidate_asid_entry_cur_thread invalidate_asid_entry_sched_act invalidate_asid_entry_wuc flush_space_cur_thread flush_space_sched_act flush_space_wuc | clarsimp)+
       apply( wp return_ev2 |
              drule (1) requiv_arm_asid_table_asid_high_bits_of_asid_eq' | 
              clarsimp   | rule conjI |
              simp add: equiv_valid_2_def )+
done

definition states_equal_except_kheap_asid :: "det_state \<Rightarrow> det_state \<Rightarrow> bool" where
  "states_equal_except_kheap_asid s s' \<equiv>
     arm_globals_frame (arch_state s) = arm_globals_frame (arch_state s') \<and> 
     equiv_machine_state \<top> {} (machine_state s) (machine_state s') \<and>
     equiv_for \<top> cdt s s' \<and>
     equiv_for \<top> cdt_list s s' \<and>
     equiv_for \<top> ekheap s s' \<and>
     equiv_for \<top> ready_queues s s' \<and>
     equiv_for \<top> is_original_cap s s' \<and>
     equiv_for \<top> interrupt_states s s' \<and>
     equiv_for \<top> interrupt_irq_node s s' \<and>
     cur_thread s = cur_thread s' \<and>
     cur_domain s = cur_domain s' \<and>
     scheduler_action s = scheduler_action s' \<and>
     work_units_completed s = work_units_completed s' \<and>
     irq_state_of_state s = irq_state_of_state s'"

lemma set_asid_pool_state_equal_except_kheap:
  "((), s') \<in> fst (set_asid_pool ptr pool s) \<Longrightarrow>
    states_equal_except_kheap_asid s s' \<and>
    (\<forall>p. p \<noteq> ptr \<longrightarrow> kheap s p = kheap s' p) \<and>
    kheap s' ptr = Some (ArchObj (ASIDPool pool)) \<and>
    (\<forall>asid. asid \<noteq> 0 \<longrightarrow>
      arm_asid_table (arch_state s) (asid_high_bits_of asid) =
      arm_asid_table (arch_state s') (asid_high_bits_of asid) \<and>
      (\<forall>pool_ptr. arm_asid_table (arch_state s) (asid_high_bits_of asid) = 
        Some pool_ptr \<longrightarrow>
          asid_pool_at pool_ptr s = asid_pool_at pool_ptr s' \<and>
          (\<forall>asid_pool asid_pool'. pool_ptr \<noteq> ptr \<longrightarrow>
            kheap s pool_ptr = Some (ArchObj (ASIDPool asid_pool)) \<and>
            kheap s' pool_ptr = Some (ArchObj (ASIDPool asid_pool')) \<longrightarrow>
              asid_pool (ucast asid) = asid_pool' (ucast asid))))"
  apply(clarsimp simp: set_asid_pool_def put_def bind_def get_object_def gets_def get_def return_def assert_def fail_def set_object_def split: split_if_asm)
  apply(clarsimp simp: states_equal_except_kheap_asid_def equiv_for_def obj_at_def)
  apply(case_tac "pool_ptr = ptr")
   apply(clarsimp simp: a_type_def split: kernel_object.splits arch_kernel_obj.splits)
  apply(clarsimp)
  done

lemma set_asid_pool_delete_ev2:
  "equiv_valid_2 (reads_equiv aag) (affects_equiv aag l) (affects_equiv aag l)
     \<top>\<top> (\<lambda>s. arm_asid_table (arch_state s) (asid_high_bits_of asid) = Some a \<and>
            kheap s a = Some (ArchObj (ASIDPool pool)) \<and> 
            asid \<noteq> 0 \<and> is_subject_asid aag asid)
        (\<lambda>s. arm_asid_table (arch_state s) (asid_high_bits_of asid) = Some a \<and>
            kheap s a = Some (ArchObj (ASIDPool pool')) \<and>
            asid \<noteq> 0 \<and> is_subject_asid aag asid)
          (set_asid_pool a (pool(ucast asid := None)))
          (set_asid_pool a (pool'(ucast asid := None)))"
  apply(clarsimp simp: equiv_valid_2_def)
  apply(frule_tac s'=b in set_asid_pool_state_equal_except_kheap)
  apply(frule_tac s'=ba in set_asid_pool_state_equal_except_kheap)
  apply(clarsimp simp: states_equal_except_kheap_asid_def)
  apply(rule conjI)
   apply(clarsimp simp: states_equiv_for_def reads_equiv_def equiv_for_def | rule conjI)+
     apply(case_tac "x=a")
      apply(clarsimp)
     apply(fastforce)
    apply(clarsimp simp: equiv_asids_def equiv_asid_def | rule conjI)+
     apply(case_tac "pool_ptr = a")
      apply(clarsimp)
      apply(erule_tac x="pasASIDAbs aag asid" in ballE)
       apply(clarsimp)
       apply(erule_tac x=asid in allE)+
       apply(clarsimp)
      apply(drule aag_can_read_own_asids, simp)
     apply(erule_tac x="pasASIDAbs aag asida" in ballE)
      apply(clarsimp)
      apply(erule_tac x=asida in allE)+
      apply(clarsimp)
     apply(clarsimp)
    apply(clarsimp)
    apply(case_tac "pool_ptr=a")
     apply(erule_tac x="pasASIDAbs aag asida" in ballE)
      apply(clarsimp)+
  apply(clarsimp simp: affects_equiv_def equiv_for_def states_equiv_for_def | rule conjI)+
   apply(case_tac "x=a")
    apply(clarsimp)
   apply(fastforce)
  apply(clarsimp simp: equiv_asids_def equiv_asid_def | rule conjI)+
   apply(case_tac "pool_ptr=a")
    apply(clarsimp)
    apply(erule_tac x=asid in allE)+
    apply(clarsimp simp: asid_pool_at_kheap)
   apply(erule_tac x=asida in allE)+
   apply(clarsimp)
  apply(clarsimp)
  apply(case_tac "pool_ptr=a")
   apply(clarsimp)+
   done

crunch kheap: invalidate_asid, invalidate_hw_asid_entry, load_hw_asid "\<lambda>s. kheap s x = y"

lemma delete_asid_reads_respects:
  "reads_respects aag l (K (asid \<noteq> 0 \<and> is_subject_asid aag asid))
    (delete_asid asid pd)"
  unfolding delete_asid_def
  apply(subst equiv_valid_def2)
  apply(rule_tac W="\<top>\<top>" and Q="\<lambda>rv s. rv = arm_asid_table (arch_state s)
        \<and> is_subject_asid aag asid \<and> asid \<noteq> 0" in equiv_valid_rv_bind)
    apply(rule equiv_valid_rv_guard_imp[OF equiv_valid_rv_trivial])
     apply(wp, simp)
   apply(case_tac "rv (asid_high_bits_of asid) =
                   rv' (asid_high_bits_of asid)")
    apply(simp)
    apply(case_tac "rv' (asid_high_bits_of asid)")
     apply(simp)
     apply(wp return_ev2, simp)
    apply(simp)
    apply(rule equiv_valid_2_guard_imp)
    apply(rule_tac R'="\<lambda>rv rv'. rv (ucast asid) = rv' (ucast asid)"
                in equiv_valid_2_bind)
       apply(simp add: when_def)
       apply(clarsimp | rule conjI)+
        apply(rule_tac R'="\<top>\<top>" in equiv_valid_2_bind)
           apply(rule_tac R'="\<top>\<top>" in equiv_valid_2_bind)
              apply(rule_tac R'="\<top>\<top>" in equiv_valid_2_bind)
                 apply(subst equiv_valid_def2[symmetric])
                 apply(rule reads_respects_unobservable_unit_return)
                  apply(wp set_vm_root_states_equiv_for set_vm_root_cur_thread)
                apply(rule set_asid_pool_delete_ev2)
               apply(wp)
             apply(rule equiv_valid_2_unobservable)
                apply(wp invalidate_asid_entry_states_equiv_for
                         invalidate_asid_entry_cur_thread)
            apply(simp add: invalidate_asid_entry_def 
                | wp invalidate_asid_kheap invalidate_hw_asid_entry_kheap 
                     load_hw_asid_kheap)+
          apply(rule equiv_valid_2_unobservable)
             apply(wp flush_space_states_equiv_for flush_space_cur_thread)
         apply(wp load_hw_asid_kheap | simp add: flush_space_def | wpc)+
       apply(clarsimp | rule return_ev2)+
      apply(rule equiv_valid_2_guard_imp)
        apply(wp get_asid_pool_revrv)
       apply(simp)+
     apply(wp)
   apply(clarsimp simp: obj_at_def)+
   apply(clarsimp simp: equiv_valid_2_def reads_equiv_def equiv_asids_def equiv_asid_def states_equiv_for_def)
   apply(erule_tac x="pasASIDAbs aag asid" in ballE)
    apply(clarsimp)
   apply(drule aag_can_read_own_asids)
   apply(clarsimp)+
   done


subsection "globals_equiv"


lemma set_endpoint_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> set_endpoint ptr ep \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_endpoint_def
  apply(wp set_object_globals_equiv get_object_wp | simp)+
  apply(fastforce simp: obj_at_def valid_ko_at_arm_def)
  done

lemma set_endpoint_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_endpoint ptr ep \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_endpoint_def set_object_def
  apply(wp get_object_wp | clarsimp simp: obj_at_def valid_ko_at_arm_def)+
  done

lemma set_thread_state_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> set_thread_state ref ts \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_thread_state_def
  apply(wp set_object_globals_equiv dxo_wp_weak |simp)+
  apply (intro impI conjI allI)
  apply(clarsimp simp: valid_ko_at_arm_def obj_at_def tcb_at_def2 get_tcb_def is_tcb_def dest: get_tcb_SomeD
                 split: option.splits kernel_object.splits)+
  done

lemma set_object_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm and (\<lambda>s. ptr = arm_global_pd (arch_state s) \<longrightarrow>
   a_type obj = AArch APageDirectory)\<rbrace>
     set_object ptr obj \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_object_def
  apply(wp, fastforce simp: valid_ko_at_arm_def obj_at_def dest: a_type_pdD)
  done

lemma valid_ko_at_arm_exst_update[simp]: "valid_ko_at_arm (trans_state f s) = valid_ko_at_arm s"
  apply (simp add: valid_ko_at_arm_def)
  done

lemma set_thread_state_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_thread_state ref ts \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_thread_state_def
  apply(wp set_object_valid_ko_at_arm dxo_wp_weak |simp)+
  apply(fastforce simp: valid_ko_at_arm_def get_tcb_ko_at obj_at_def)
  done

crunch globals_equiv: ep_cancel_badged_sends "globals_equiv s"
 (wp: filterM_preserved dxo_wp_weak ignore: reschedule_required tcb_sched_action)

lemma thread_set_globals_equiv:
  "(\<And>tcb. tcb_context (f tcb) = tcb_context tcb ) \<Longrightarrow> \<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> thread_set f tptr \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding thread_set_def
  apply(wp set_object_globals_equiv)
  apply simp
  apply (intro impI conjI allI)
  apply(fastforce simp: valid_ko_at_arm_def obj_at_def get_tcb_def)+
  apply (clarsimp simp: get_tcb_def tcb_at_def2 split: kernel_object.splits option.splits)
  done

lemma set_asid_pool_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> set_asid_pool ptr pool \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_asid_pool_def
  apply(wp set_object_globals_equiv get_object_wp)
  apply(fastforce simp: valid_ko_at_arm_def obj_at_def)
  done

lemma idle_equiv_arch_state_update[simp]: "idle_equiv st (s\<lparr>arch_state := x\<rparr>) = idle_equiv st s"
  apply (simp add: idle_equiv_def)
  done

crunch globals_equiv[wp]: invalidate_hw_asid_entry "globals_equiv s"
 (simp: globals_equiv_def)

crunch globals_equiv[wp]: invalidate_asid "globals_equiv s"
 (simp: globals_equiv_def)

lemma globals_equiv_arm_next_asid_update[simp]:
  "globals_equiv s (t\<lparr>arch_state := arch_state t\<lparr>arm_next_asid := x\<rparr>\<rparr>) = globals_equiv s t"
  by (simp add: globals_equiv_def)

lemma globals_equiv_arm_asid_map_update[simp]:
  "globals_equiv s (t\<lparr>arch_state := arch_state t\<lparr>arm_asid_map := x\<rparr>\<rparr>) = globals_equiv s t"
  by (simp add: globals_equiv_def)

lemma globals_equiv_arm_hwasid_table_update[simp]:
  "globals_equiv s (t\<lparr>arch_state := arch_state t\<lparr>arm_hwasid_table := x\<rparr>\<rparr>) = globals_equiv s t"
  by (simp add: globals_equiv_def)

lemma globals_equiv_arm_asid_table_update[simp]:
  "globals_equiv s (t\<lparr>arch_state := arch_state t\<lparr>arm_asid_table := x\<rparr>\<rparr>) = globals_equiv s t"
  by (simp add: globals_equiv_def)

lemma find_free_hw_asid_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> find_free_hw_asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding find_free_hw_asid_def
  apply(wp modify_wp invalidate_hw_asid_entry_globals_equiv 
          dmo_mol_globals_equiv invalidate_asid_globals_equiv
       | wpc | simp add: invalidateTLB_ASID_def)+
  done

lemma store_hw_asid_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> store_hw_asid asid hw_asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding store_hw_asid_def
  apply(wp find_pd_for_asid_assert_wp | rule modify_wp, simp)+
  apply(fastforce simp: globals_equiv_def)
  done

lemma get_hw_asid_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> get_hw_asid asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding get_hw_asid_def
  apply(wp store_hw_asid_globals_equiv find_free_hw_asid_globals_equiv load_hw_asid_wp | wpc | simp)+
  done

lemma set_current_asid_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> set_current_asid asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_current_asid_def setHardwareASID_def
  apply(wp dmo_mol_globals_equiv get_hw_asid_globals_equiv)
  done

lemma set_vm_root_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> set_vm_root tcb \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_vm_root_def fun_app_def setCurrentPD_def
  apply(wp dmo_mol_globals_equiv set_current_asid_globals_equiv whenE_inv| wpc)+
   apply(wp hoare_vcg_all_lift | wp_once hoare_drop_imps | clarsimp)+
   done

lemma invalidate_asid_entry_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> invalidate_asid_entry asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding invalidate_asid_entry_def
  apply(wp invalidate_hw_asid_entry_globals_equiv invalidate_asid_globals_equiv load_hw_asid_wp)
  apply(clarsimp)
  done

lemma flush_space_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> flush_space asid \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
unfolding flush_space_def
apply(wp dmo_mol_globals_equiv load_hw_asid_wp
    | wpc
    | simp add: invalidateTLB_ASID_def cleanCaches_PoU_def dsb_def invalidate_I_PoU_def clean_D_PoU_def dmo_bind_valid)+
done

lemma delete_asid_pool_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> delete_asid_pool base ptr \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding delete_asid_pool_def
  apply(wp set_vm_root_globals_equiv mapM_wp[OF _ subset_refl] modify_wp invalidate_asid_entry_globals_equiv flush_space_globals_equiv | simp)+
  done

crunch globals_equiv[wp]: invalidate_tlb_by_asid "globals_equiv s"
  (simp: invalidateTLB_ASID_def wp: dmo_mol_globals_equiv ignore: machine_op_lift do_machine_op)

lemma set_pt_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> set_pt ptr pt \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding  set_pt_def
  apply(wp set_object_globals_equiv get_object_wp)
  apply(fastforce simp: valid_ko_at_arm_def obj_at_def)
  done

crunch globals_equiv: store_pte "globals_equiv s"

lemma set_vm_root_for_flush_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> set_vm_root_for_flush pd asid \<lbrace>\<lambda>rv. globals_equiv s\<rbrace>"
  unfolding set_vm_root_for_flush_def setCurrentPD_def fun_app_def
  apply(wp dmo_mol_globals_equiv | wpc | simp)+
    apply(rule_tac Q="\<lambda>rv. globals_equiv s" in hoare_strengthen_post)
     apply(wp | simp)+
     done

lemma flush_table_globals_equiv[wp]:
  "\<lbrace>globals_equiv s\<rbrace> flush_table pd asid cptr pt \<lbrace>\<lambda>rv. globals_equiv s\<rbrace>"
  unfolding flush_table_def invalidateTLB_ASID_def fun_app_def
  apply (wp mapM_wp' dmo_mol_globals_equiv | wpc | simp add: do_machine_op_bind split del: split_if cong: if_cong)+
  done

lemma arm_global_pd_arm_asid_map_update[simp]:
  "arm_global_pd (arch_state s\<lparr>arm_asid_map := x\<rparr>) = arm_global_pd (arch_state s)"
  by (simp add: globals_equiv_def)

lemma arm_global_pd_arm_hwasid_table_update[simp]:
  "arm_global_pd (arch_state s\<lparr>arm_hwasid_table := x\<rparr>) = arm_global_pd (arch_state s)"
  by (simp add: globals_equiv_def)

crunch arm_global_pd[wp]: flush_table "\<lambda>s. P (arm_global_pd (arch_state s))"
  (wp: crunch_wps simp: crunch_simps)

crunch globals_equiv[wp]: page_table_mapped "globals_equiv st"

(*FIXME: duplicated, more reasonable version of not_in_global_refs_vs_lookup *)

lemma not_in_global_refs_vs_lookup2: "\<lbrakk>
  valid_vs_lookup s;
  valid_global_refs s;
  valid_arch_state s; valid_global_objs s; page_directory_at p s; (\<exists>\<rhd> p) s\<rbrakk> \<Longrightarrow>
  p \<notin> global_refs s"
  apply (insert not_in_global_refs_vs_lookup[where p=p and s=s])
  apply simp
done

(*FIXME: This should either be straightforward or moved somewhere else*)

lemma case_junk : "((case rv of Inl e \<Rightarrow> True | Inr r \<Rightarrow> P r) \<longrightarrow> (case rv of Inl e \<Rightarrow> True | Inr r \<Rightarrow> R r)) =
  (case rv of Inl e \<Rightarrow> True | Inr r \<Rightarrow> P r \<longrightarrow> R r)"
  apply (case_tac rv)
  apply simp+
done

(*FIXME: Same here*)
lemma hoare_add_postE : "\<lbrace>Q\<rbrace> f \<lbrace>\<lambda> r. P r\<rbrace>,- \<Longrightarrow> \<lbrace>Q\<rbrace> f \<lbrace>\<lambda> r s. (P r s) \<longrightarrow> (R r s) \<rbrace>,- \<Longrightarrow> \<lbrace>Q\<rbrace> f \<lbrace>\<lambda> r. R r\<rbrace>,-"
  unfolding validE_R_def validE_def
  apply (erule hoare_add_post)
   apply simp
  apply (erule hoare_post_imp[rotated])
  apply (simp add: case_junk)
done

lemma find_pd_for_asid_not_arm_global_pd:
  "\<lbrace>pspace_aligned and valid_arch_objs and valid_global_objs and valid_vs_lookup
  and valid_global_refs and valid_arch_state\<rbrace>
  find_pd_for_asid asid 
  \<lbrace>\<lambda>rv s. lookup_pd_slot rv vptr && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s)\<rbrace>, -"
  apply (rule hoare_add_postE)
   apply (wp find_pd_for_asid_aligned_pd_bits)
   apply clarsimp
  apply (rule hoare_pre)
   apply(wp find_pd_for_asid_lots)
  apply(simp)
  apply clarify
  apply (frule lookup_pd_slot_pd[where vptr=vptr])
  apply simp+
  apply (frule (4) not_in_global_refs_vs_lookup2)
   apply (auto simp: global_refs_def)
done

lemma find_pd_for_asid_not_arm_global_pd_large_page:
  "\<lbrace>pspace_aligned and valid_arch_objs and valid_global_objs and valid_vs_lookup
  and valid_global_refs and valid_arch_state\<rbrace>
  find_pd_for_asid asid 
  \<lbrace>\<lambda>rv s. 
  (lookup_pd_slot rv vptr && mask 6 = 0) \<longrightarrow>
  (\<forall> x \<in> set [0 , 4 .e. 0x3C]. 
  x + lookup_pd_slot rv vptr && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s))\<rbrace>, -"
  apply (rule hoare_add_postE)
   apply (wp find_pd_for_asid_aligned_pd_bits)
   apply clarsimp
  apply (rule hoare_pre)
   apply(wp find_pd_for_asid_lots)
  apply(simp)
  apply clarify
  apply (subst (asm) is_aligned_mask[symmetric])
  apply (frule is_aligned_6_masks[where bits=pd_bits])
  apply simp+
  apply (frule lookup_pd_slot_pd[where vptr=vptr])
  apply (frule (4) not_in_global_refs_vs_lookup2)
   apply (auto simp: global_refs_def)
done

declare dmo_mol_globals_equiv[wp]

lemma unmap_page_table_globals_equiv:
  "\<lbrace>pspace_aligned and valid_arch_objs and valid_global_objs and valid_vs_lookup
  and valid_global_refs and valid_arch_state and globals_equiv st\<rbrace> unmap_page_table asid vaddr pt \<lbrace>\<lambda>rv. globals_equiv st\<rbrace>"
  unfolding unmap_page_table_def page_table_mapped_def
  apply(wp store_pde_globals_equiv | wpc | simp add: cleanByVA_PoU_def)+
    apply(rule_tac Q="\<lambda>_. globals_equiv st and (\<lambda>sa. lookup_pd_slot pd vaddr && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state sa))" in hoare_strengthen_post)
     apply(wp | simp)+
  apply(rule hoare_validE_conj)
   apply(wp | simp)+
  apply(rule hoare_validE_cases)
   apply(rule validE_R_validE)
   apply(wp find_pd_for_asid_not_arm_global_pd hoare_post_imp_dc2E_actual | simp)+
   done

lemma set_pt_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_pt ptr pt \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_pt_def
  apply(wp get_object_wp)
  apply(clarsimp simp: valid_ko_at_arm_def obj_at_def)
  done

crunch valid_ko_at_arm[wp]: store_pte "valid_ko_at_arm"

lemma mapM_x_swp_store_pte_globals_equiv:
  " \<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace>
          mapM_x (swp store_pte A) slots 
          \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  apply(rule_tac Q="\<lambda>_. globals_equiv s and valid_ko_at_arm" in hoare_strengthen_post)
   apply(wp mapM_x_wp' store_pte_globals_equiv store_pte_valid_ko_at_arm | simp)+
   done

lemma mapM_x_swp_store_pte_valid_ko_at_arm[wp]:
  " \<lbrace>valid_ko_at_arm\<rbrace>
          mapM_x (swp store_pte A) slots 
          \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(wp mapM_x_wp' | simp add: swp_def)+
  done

lemma set_cap_globals_equiv'':
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace>
  set_cap cap p \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding set_cap_def
  apply(simp only: split_def)
  apply(wp set_object_globals_equiv hoare_vcg_all_lift get_object_wp | wpc | simp)+
   apply(fastforce simp: valid_ko_at_arm_def valid_ao_at_def obj_at_def is_tcb_def)+
  done

lemma do_machine_op_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> do_machine_op mol \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding do_machine_op_def machine_op_lift_def split_def valid_ko_at_arm_def
  apply(wp modify_wp, simp)
  done

lemma valid_ko_at_arm_next_asid[simp]:
  "valid_ko_at_arm (s\<lparr>arch_state := arch_state s\<lparr>arm_next_asid := x\<rparr>\<rparr>)
  = valid_ko_at_arm s"
  by (simp add: valid_ko_at_arm_def)

lemma valid_ko_at_arm_asid_map[simp]:
  "valid_ko_at_arm (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_map := x\<rparr>\<rparr>)
  = valid_ko_at_arm s"
  by (simp add: valid_ko_at_arm_def)

lemma valid_ko_at_arm_hwasid_table[simp]:
  "valid_ko_at_arm (s\<lparr>arch_state := arch_state s\<lparr>arm_hwasid_table := x\<rparr>\<rparr>)
  = valid_ko_at_arm s"
  by (simp add: valid_ko_at_arm_def)

lemma valid_ko_at_arm_asid_table[simp]:
  "valid_ko_at_arm
                (s\<lparr>arch_state := arch_state s
                     \<lparr>arm_asid_table := A\<rparr>\<rparr>) =
   valid_ko_at_arm s" by (simp add: valid_ko_at_arm_def)

lemma valid_ko_at_arm_interrupt_states[simp]:
  "valid_ko_at_arm (s\<lparr>interrupt_states := f\<rparr>)
  = valid_ko_at_arm s"
  by (simp add: valid_ko_at_arm_def)

lemma valid_ko_at_arm_arch[simp]:
  "arm_global_pd A = arm_global_pd (arch_state s) \<Longrightarrow>
   valid_ko_at_arm (s\<lparr>arch_state := A\<rparr>) = valid_ko_at_arm s"
  by (simp add: valid_ko_at_arm_def)

crunch valid_ko_at_arm[wp]: set_current_asid "valid_ko_at_arm"
  (wp: find_pd_for_asid_assert_wp)

lemma set_vm_root_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_vm_root tcb \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_vm_root_def
  apply(wp | wpc)+
      apply(simp add: whenE_def throwError_def returnOk_def)
      apply(rule conjI)
       apply(clarsimp | wp whenE_throwError_wp)+
    apply(rule hoare_drop_imps)
    apply(wp)
   apply(rule_tac Q="\<lambda>_. valid_ko_at_arm" in hoare_strengthen_post)
    apply(wp | fastforce)+
    done

lemma set_pd_valid_ko_at_armp[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_pd ptr pd \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding set_pd_def
  apply(wp get_object_wp, fastforce simp: a_type_def)
  done

crunch valid_ko_at_arm[wp]: unmap_page_table "valid_ko_at_arm"
  (wp: crunch_wps simp: crunch_simps)

definition authorised_for_globals_page_table_inv :: 
    "page_table_invocation \<Rightarrow> 'z state \<Rightarrow> bool" where
  "authorised_for_globals_page_table_inv pti \<equiv>
    \<lambda>s. case pti of PageTableMap cap ptr pde p
  \<Rightarrow> p && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s) | _ \<Rightarrow> True"

lemma perform_page_table_invocation_globals_equiv:
  "\<lbrace>valid_global_refs and valid_global_objs and valid_arch_state and
    globals_equiv st and pspace_aligned and valid_arch_objs and
    valid_vs_lookup and valid_kernel_mappings and authorised_for_globals_page_table_inv pti\<rbrace>
  perform_page_table_invocation pti \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  unfolding perform_page_table_invocation_def cleanCacheRange_PoU_def
  apply(rule hoare_weaken_pre)
   apply(wp store_pde_globals_equiv set_cap_globals_equiv'' dmo_cacheRangeOp_lift
            mapM_x_swp_store_pte_globals_equiv unmap_page_table_globals_equiv
           | wpc | simp add: cleanByVA_PoU_def)+
  apply(fastforce simp: authorised_for_globals_page_table_inv_def valid_arch_state_def valid_ko_at_arm_def obj_at_def dest: a_type_pdD)
  done

lemma do_flush_globals_equiv:
  "\<lbrace>globals_equiv st\<rbrace> do_machine_op (do_flush typ start end pstart)
    \<lbrace>\<lambda>rv. globals_equiv st\<rbrace>"
  apply (cases "typ")
     apply (wp dmo_cacheRangeOp_lift | simp add: do_flush_def cache_machine_op_defs do_flush_defs do_machine_op_bind when_def | clarsimp | rule conjI)+
     done

lemma perform_page_directory_invocation_globals_equiv:
  "\<lbrace>globals_equiv st\<rbrace>
  perform_page_directory_invocation pdi \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  unfolding perform_page_directory_invocation_def
  apply (cases pdi)
   apply (wp do_flush_globals_equiv | simp)+
   done

lemma flush_page_globals_equiv[wp]:
  "\<lbrace>globals_equiv st\<rbrace> flush_page page_size pd asid vptr \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  unfolding flush_page_def invalidateTLB_VAASID_def
  apply(wp | simp cong: if_cong split del: split_if)+
  done

lemma flush_page_arm_global_pd[wp]:
  "\<lbrace>\<lambda>s. P (arm_global_pd (arch_state s))\<rbrace>
     flush_page pgsz pd asid vptr 
   \<lbrace>\<lambda>rv s. P (arm_global_pd (arch_state s))\<rbrace>"
  unfolding flush_page_def
  apply(wp | simp cong: if_cong split del: split_if)+
  done

lemma mapM_swp_store_pte_globals_equiv:
  "\<lbrace>globals_equiv st and valid_ko_at_arm\<rbrace>
    mapM (swp store_pte A) slots \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  apply(rule_tac Q="\<lambda> _. globals_equiv st and valid_ko_at_arm"
        in hoare_strengthen_post)
   apply(wp mapM_wp' store_pte_globals_equiv | simp)+
   done

lemma mapM_swp_store_pde_globals_equiv:
  "\<lbrace>globals_equiv st and (\<lambda>s. \<forall>x \<in> set slots.
   x && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s))\<rbrace>
     mapM (swp store_pde A) slots \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  apply (rule_tac Q="\<lambda> _. globals_equiv st and (\<lambda> s. \<forall>x \<in> set slots.
                      x && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s))"
         in hoare_strengthen_post)
   apply (wp mapM_wp' store_pde_globals_equiv | simp)+
   done

lemma mapM_swp_store_pte_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> mapM (swp store_pte A) slots \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(wp mapM_wp' store_pte_valid_ko_at_arm | simp)+
  done

lemma mapM_x_swp_store_pde_globals_equiv :
  "\<lbrace>globals_equiv st and (\<lambda>s. \<forall>x \<in> set slots.
   x && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s))\<rbrace>
     mapM_x (swp store_pde A) slots \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  apply (rule_tac Q="\<lambda>_. globals_equiv st and (\<lambda> s. \<forall>x \<in> set slots.
                     x && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s))"
         in hoare_strengthen_post)
   apply (wp mapM_x_wp' store_pde_globals_equiv | simp)+
   done

crunch valid_ko_at_arm[wp]: flush_page "valid_ko_at_arm"
  (wp: crunch_wps simp: crunch_simps)

lemma unmap_page_globals_equiv:
  "\<lbrace>globals_equiv st and valid_arch_state and pspace_aligned and valid_arch_objs
  and valid_global_objs and valid_vs_lookup and valid_global_refs \<rbrace> unmap_page pgsz asid vptr pptr 
   \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  unfolding unmap_page_def cleanCacheRange_PoU_def
  apply (induct pgsz)
     prefer 4
     apply (simp only: vmpage_size.simps)
     apply(wp mapM_swp_store_pde_globals_equiv dmo_cacheRangeOp_lift | simp add: cleanByVA_PoU_def)+
        apply(rule hoare_drop_imps)
        apply(wp)
       apply(simp)
       apply(rule hoare_drop_imps)
       apply(wp)
     apply (rule hoare_pre)
      apply (rule_tac Q="\<lambda>x. globals_equiv st and (\<lambda>sa. lookup_pd_slot x vptr && mask 6 = 0 \<longrightarrow> (\<forall>xa\<in>set [0 , 4 .e. 0x3C]. xa + lookup_pd_slot x vptr && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state sa)))" and E="\<lambda>_. globals_equiv st" in hoare_post_impErr)
        apply(wp find_pd_for_asid_not_arm_global_pd_large_page)
       apply simp
      apply simp
     apply simp
    apply(wp store_pte_globals_equiv | simp add: cleanByVA_PoU_def)+
      apply(wp hoare_drop_imps)
     apply(wp_once lookup_pt_slot_inv)
     apply(wp_once lookup_pt_slot_inv)
     apply(wp_once lookup_pt_slot_inv)
     apply(wp_once lookup_pt_slot_inv)
    apply(simp)
    apply(rule hoare_pre)
     apply wp
    apply(simp add: valid_arch_state_ko_at_arm)
   apply(simp)
   apply(rule hoare_pre)
    apply(wp dmo_cacheRangeOp_lift mapM_swp_store_pde_globals_equiv store_pde_globals_equiv lookup_pt_slot_inv mapM_swp_store_pte_globals_equiv hoare_drop_imps | simp add: cleanByVA_PoU_def)+
   apply(simp add: valid_arch_state_ko_at_arm)
  apply(rule hoare_pre)
   apply(wp store_pde_globals_equiv | simp add: valid_arch_state_ko_at_arm cleanByVA_PoU_def)+
    apply(wp find_pd_for_asid_not_arm_global_pd hoare_drop_imps)
  apply(clarsimp) 
  done (* don't know what happened here. wp deleted globals_equiv from precon *)


lemma cte_wp_parent_not_global_pd: "valid_global_refs s \<Longrightarrow> cte_wp_at (parent_for_refs (Inr (a,b))) k s \<Longrightarrow> \<forall>x \<in> set b. x && ~~ mask pd_bits \<noteq> arm_global_pd (arch_state s)"
  apply (simp only: cte_wp_at_caps_of_state)
  apply (elim exE conjE)
  apply (drule valid_global_refsD2,simp)
  apply (unfold parent_for_refs_def)
  apply (simp add: image_def global_refs_def cap_range_def)
  apply (elim conjE)
  apply (intro ballI)
  apply clarsimp
  apply (subgoal_tac "arm_global_pd (arch_state s) \<in> set b") 
   apply auto
done

definition authorised_for_globals_page_inv :: "page_invocation \<Rightarrow> 'z::state_ext state \<Rightarrow> bool"
  where "authorised_for_globals_page_inv pi \<equiv>
    \<lambda>s. case pi of PageMap cap ptr m \<Rightarrow>
  \<exists>slot. cte_wp_at (parent_for_refs m) slot s | PageRemap m \<Rightarrow>
  \<exists>slot. cte_wp_at (parent_for_refs m) slot s | _ \<Rightarrow> True"

lemma set_cap_valid_ko_at_arm[wp]:
  "\<lbrace>valid_ko_at_arm\<rbrace> set_cap cap p \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(simp add: valid_ko_at_arm_def)
  apply(rule hoare_ex_wp)
  apply(rule hoare_pre)
   apply(simp add: set_cap_def split_def)
   apply(wp | wpc)+
     apply(simp add: set_object_def)
     apply(wp get_object_wp | wpc)+
  apply(fastforce simp: obj_at_def)
  done

crunch valid_ko_at_arm[wp]: unmap_page "valid_ko_at_arm"
  (wp: crunch_wps)

lemma perform_page_invocation_globals_equiv:
  "\<lbrace>authorised_for_globals_page_inv pi and valid_page_inv pi and globals_equiv st
    and valid_arch_state and pspace_aligned and valid_arch_objs and valid_global_objs
    and valid_vs_lookup and valid_global_refs\<rbrace> 
   perform_page_invocation pi 
   \<lbrace>\<lambda>_. globals_equiv st\<rbrace>"
  unfolding perform_page_invocation_def cleanCacheRange_PoU_def
  apply(rule hoare_weaken_pre)
  apply(wp mapM_swp_store_pte_globals_equiv hoare_vcg_all_lift dmo_cacheRangeOp_lift
        mapM_swp_store_pde_globals_equiv mapM_x_swp_store_pte_globals_equiv
        mapM_x_swp_store_pde_globals_equiv set_cap_globals_equiv''
        unmap_page_globals_equiv store_pte_globals_equiv store_pde_globals_equiv static_imp_wp
        do_flush_globals_equiv
       | wpc | simp add: do_machine_op_bind cleanByVA_PoU_def)+
  apply(auto simp: cte_wp_parent_not_global_pd authorised_for_globals_page_inv_def 
                   valid_page_inv_def valid_slots_def 
             dest: valid_arch_state_ko_at_arm 
            dest!:rev_subsetD[OF _ tl_subseteq])
  done

lemma retype_region_ASIDPoolObj_globals_equiv:
  "\<lbrace>globals_equiv s and (\<lambda>sa. ptr \<noteq> arm_global_pd (arch_state s)) and (\<lambda>sa. ptr \<noteq> idle_thread sa)\<rbrace>
  retype_region ptr 1 0 (ArchObject ASIDPoolObj) 
  \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding retype_region_def
  apply(wp modify_wp dxo_wp_weak | simp | fastforce simp: globals_equiv_def default_arch_object_def obj_bits_api_def)+
      apply (simp add: trans_state_update[symmetric] del: trans_state_update)
     apply wp
  apply (fastforce simp: globals_equiv_def idle_equiv_def tcb_at_def2)
  done

crunch valid_ko_at_arm[wp]: "set_untyped_cap_as_full" "valid_ko_at_arm"

lemma cap_insert_globals_equiv'':
  "\<lbrace>globals_equiv s and valid_global_objs and valid_ko_at_arm\<rbrace>
  cap_insert new_cap src_slot dest_slot \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding  cap_insert_def
  apply(wp set_original_globals_equiv update_cdt_globals_equiv set_cap_globals_equiv'' dxo_wp_weak | rule hoare_drop_imps | simp)+
  done

  

lemma retype_region_ASIDPoolObj_valid_ko_at_arm:
  "\<lbrace>valid_ko_at_arm and (\<lambda>s. ptr \<noteq> arm_global_pd (arch_state s))\<rbrace>
  retype_region ptr 1 0 (ArchObject ASIDPoolObj) 
  \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(simp add: retype_region_def)
  apply(wp modify_wp dxo_wp_weak |simp add: trans_state_update[symmetric] del: trans_state_update)+
  apply(clarsimp simp: valid_ko_at_arm_def)
  apply(rule_tac x=pd in exI)
  apply(fold fun_upd_def)
  apply(clarsimp simp: fun_upd_def obj_at_def)
  done

lemma detype_valid_ko_at_arm:
  "\<lbrace>valid_ko_at_arm and (\<lambda>s.
      arm_global_pd (arch_state s) \<notin> {ptr..ptr + 2 ^ bits - 1})\<rbrace>
   modify (detype {ptr..ptr + 2 ^ bits - 1}) \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(wp modify_wp)
  apply(fastforce simp: valid_ko_at_arm_def detype_def obj_at_def a_type_def)
  done

lemma detype_valid_arch_state:
  "\<lbrace>valid_arch_state and
    (\<lambda>s. arm_globals_frame (arch_state s) \<notin> {ptr..ptr + 2 ^ bits - 1} \<and>
         arm_global_pd (arch_state s) \<notin> {ptr..ptr + 2 ^ bits - 1} \<and>
    {ptr..ptr + 2 ^ bits - 1} \<inter> ran (arm_asid_table (arch_state s)) = {} \<and>
    {ptr..ptr + 2 ^ bits - 1} \<inter> set (arm_global_pts (arch_state s)) = {})\<rbrace>
   modify (detype {ptr..ptr + (1 << bits) - 1}) \<lbrace>\<lambda>_. valid_arch_state\<rbrace>"
  apply(wp modify_wp)
  apply(simp add: valid_arch_state_def)
  apply(rule conjI)
   apply(clarsimp simp: valid_asid_table_def)
   apply(erule_tac x=p in in_empty_interE)
    apply(simp)+
  apply(clarsimp simp: valid_global_pts_def)
  apply(erule_tac x=p and B="set (arm_global_pts (arch_state s))" in in_empty_interE)
   apply(simp)+
   done


lemma delete_objects_valid_ko_at_arm:
   "\<lbrace>valid_ko_at_arm and
   (\<lambda>s. arm_global_pd (arch_state s) \<notin> ptr_range p b) and
    K (is_aligned p b \<and>
        2 \<le> b \<and>
        b < word_bits)\<rbrace>
  delete_objects p b \<lbrace>\<lambda>_. valid_ko_at_arm\<rbrace>"
  apply(rule hoare_gen_asm)
  unfolding delete_objects_def
  apply(wp detype_valid_ko_at_arm do_machine_op_valid_ko_at_arm | simp add: ptr_range_def)+
  done
  

  
lemma perform_asid_control_invocation_globals_equiv:
  notes delete_objects_invs[wp del]
  notes blah[simp del] =  atLeastAtMost_iff atLeastatMost_subset_iff atLeastLessThan_iff
  shows
  "\<lbrace>globals_equiv s and invs and ct_active and valid_aci aci\<rbrace>
   perform_asid_control_invocation aci \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding perform_asid_control_invocation_def
  apply(rule hoare_pre)
   apply wpc
   apply (wp modify_wp cap_insert_globals_equiv''
             retype_region_ASIDPoolObj_globals_equiv[simplified]
             retype_region_invs_extras(5)[where sz=pageBits]
             retype_region_ASIDPoolObj_valid_ko_at_arm[simplified]
             set_cap_globals_equiv
             max_index_upd_invs_simple set_cap_no_overlap 
             set_cap_caps_no_overlap max_index_upd_caps_overlap_reserved
             region_in_kernel_window_preserved 
             hoare_vcg_all_lift  get_cap_wp static_imp_wp
         | simp)+
   (* factor out the implication -- we know what the relevant components of the
      cap referred to in the cte_wp_at are anyway from valid_aci, so just use
      those directly to simplify the reasoning later on *)
   apply(rule_tac Q="\<lambda> a b. globals_equiv s b \<and> 
                            invs b \<and> valid_ko_at_arm b \<and> word1 \<noteq> arm_global_pd (arch_state b) \<and> 
                            word1 \<noteq> idle_thread b \<and>
                            (\<exists> idx. cte_wp_at (op = (UntypedCap word1 pageBits idx)) prod2 b) \<and> 
                             descendants_of prod2 (cdt b) = {} \<and>
                             pspace_no_overlap word1 pageBits b" 
         in hoare_strengthen_post)
    prefer 2
    apply (clarsimp simp: globals_equiv_def invs_valid_global_objs)
    apply (drule cte_wp_at_eqD2, assumption)
    apply clarsimp
    apply (clarsimp simp: empty_descendants_range_in)
    apply (rule conjI, fastforce simp: cte_wp_at_def)
    apply (clarsimp simp: obj_bits_api_def default_arch_object_def)
    apply (frule untyped_cap_aligned, simp add: invs_valid_objs)
    apply(rule conjI, rule descendants_range_caps_no_overlapI)
       apply assumption
      apply(simp add: is_aligned_neg_mask_eq)
     apply(simp add: is_aligned_neg_mask_eq empty_descendants_range_in)
    apply(rule conjI, drule cap_refs_in_kernel_windowD2)
      apply(simp add: invs_cap_refs_in_kernel_window)
     apply(fastforce simp: cap_range_def is_aligned_neg_mask_eq)
    apply(clarsimp simp: range_cover_def)
    apply(subst is_aligned_neg_mask_eq[THEN sym], assumption)
    apply(simp add: mask_neg_mask_is_zero pageBits_def)
   apply(wp delete_objects_invs_ex delete_objects_pspace_no_overlap
            delete_objects_globals_equiv delete_objects_valid_ko_at_arm
            hoare_vcg_ex_lift 
        | simp add: page_bits_def)+
  apply (clarsimp simp: conj_ac invs_valid_ko_at_arm invs_psp_aligned invs_valid_objs valid_aci_def)
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (frule_tac cap="UntypedCap ?a ?b ?c" in caps_of_state_valid, assumption)
  apply (clarsimp simp: valid_cap_def cap_aligned_def)
  apply (frule_tac slot="(aa,ba)" in untyped_caps_do_not_overlap_global_refs[rotated, OF invs_valid_global_refs])
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply ((rule conjI |rule refl)+)[1]
  apply(rule conjI)
   apply(clarsimp simp: global_refs_def ptr_range_memI)
  apply(rule conjI)
   apply(clarsimp simp: global_refs_def ptr_range_memI)
  apply(rule conjI, fastforce simp: global_refs_def)
  apply(rule conjI, fastforce simp: global_refs_def)
  apply(rule conjI)
   apply(drule untyped_slots_not_in_untyped_range)
        apply(blast intro!: empty_descendants_range_in)
       apply(simp add: cte_wp_at_caps_of_state)
      apply simp
     apply(rule refl)
    apply(rule subset_refl)
   apply(simp)
  apply(rule conjI)
   apply(frule untyped_caps_do_not_overlap_arm_globals_frame[rotated, OF invs_valid_objs])
      apply(simp add: invs_arch_state)
     apply(simp add: invs_valid_global_refs)
    apply(simp add: cte_wp_at_caps_of_state)
   apply assumption
  apply (auto intro: empty_descendants_range_in simp: descendants_range_def2 cap_range_def)
  done


lemma perform_asid_pool_invocation_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm\<rbrace> perform_asid_pool_invocation api \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding perform_asid_pool_invocation_def
  apply(rule hoare_weaken_pre)
   apply(wp modify_wp set_asid_pool_globals_equiv set_cap_globals_equiv''
        get_cap_wp | wpc | simp)+
  done

definition 
  authorised_for_globals_arch_inv :: "arch_invocation \<Rightarrow> ('z::state_ext) state \<Rightarrow> bool" where 
  "authorised_for_globals_arch_inv ai \<equiv> case ai of
  InvokePageTable oper \<Rightarrow> authorised_for_globals_page_table_inv oper |
  InvokePage oper \<Rightarrow> authorised_for_globals_page_inv oper |
  _ \<Rightarrow> \<top>"

lemma diminished_PageDirectoryCapD:
  "diminished (ArchObjectCap (PageDirectoryCap p x)) cap \<Longrightarrow>
  cap = ArchObjectCap (PageDirectoryCap p x)"
  apply(cases cap, auto simp: diminished_def mask_cap_def cap_rights_update_def)
  apply(auto simp: acap_rights_update_def split:  arch_cap.splits)
  done

lemma arch_perform_invocation_globals_equiv:
  "\<lbrace>globals_equiv s and invs and ct_active and valid_arch_inv ai and authorised_for_globals_arch_inv ai\<rbrace>
  arch_perform_invocation ai \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding arch_perform_invocation_def
  apply wp
  apply(rule hoare_weaken_pre)
   apply(wpc)
      apply(wp perform_page_table_invocation_globals_equiv perform_page_directory_invocation_globals_equiv perform_page_invocation_globals_equiv perform_asid_control_invocation_globals_equiv perform_asid_pool_invocation_globals_equiv)
  apply(auto simp: authorised_for_globals_arch_inv_def dest: valid_arch_state_ko_at_arm simp: invs_def valid_state_def valid_arch_inv_def invs_valid_vs_lookup)
  done

lemma find_pd_for_asid_authority3:
  "\<lbrace>\<lambda>s. \<forall>pd. (pspace_aligned s \<and> valid_arch_objs s \<longrightarrow> is_aligned pd pd_bits)
           \<and> (\<exists>\<rhd> pd) s
           \<longrightarrow> Q pd s\<rbrace> find_pd_for_asid asid \<lbrace>Q\<rbrace>, -"
  (is "\<lbrace>?P\<rbrace> ?f \<lbrace>Q\<rbrace>,-")
  apply (clarsimp simp: validE_R_def validE_def valid_def imp_conjL[symmetric])
  apply (frule in_inv_by_hoareD[OF find_pd_for_asid_inv], clarsimp)
  apply (drule spec, erule mp)
  apply (simp add: use_validE_R[OF _ find_pd_for_asid_authority1]
                   use_validE_R[OF _ find_pd_for_asid_aligned_pd_bits]
                   use_validE_R[OF _ find_pd_for_asid_lookup])
  done

lemma decode_arch_invocation_authorised_for_globals:
  "\<lbrace>invs and cte_wp_at (diminished (cap.ArchObjectCap cap)) slot
        and (\<lambda>s. \<forall>(cap, slot) \<in> set excaps. cte_wp_at (diminished cap) slot s)\<rbrace>
  arch_decode_invocation label msg x_slot slot cap excaps 
  \<lbrace>\<lambda>rv. authorised_for_globals_arch_inv rv\<rbrace>, -"
  unfolding arch_decode_invocation_def authorised_for_globals_arch_inv_def
  apply (rule hoare_pre)
   apply (simp add: split_def Let_def
     cong: cap.case_cong arch_cap.case_cong if_cong option.case_cong split del: split_if)
   apply (wp select_wp select_ext_weak_wp whenE_throwError_wp check_vp_wpR unlessE_wp get_pde_wp get_master_pde_wp
             find_pd_for_asid_authority3 create_mapping_entries_parent_for_refs
           | wpc
           | simp add:  authorised_for_globals_page_inv_def
                  del: hoare_post_taut hoare_True_E_R
                  split del: split_if)+
           apply(simp cong: if_cong)
           apply(wp hoare_vcg_if_lift2)
     apply(rule hoare_conjI)
      apply(rule hoare_drop_imps)
      apply(simp add: authorised_for_globals_page_table_inv_def)
      apply(wp)
     apply(rule hoare_drop_imps)
     apply((wp hoare_TrueI hoare_vcg_all_lift hoare_drop_imps | wpc | simp)+)[3]
  apply (clarsimp simp: authorised_asid_pool_inv_def authorised_page_table_inv_def
                        neq_Nil_conv invs_psp_aligned invs_arch_objs cli_no_irqs)
  apply (drule diminished_cte_wp_at_valid_cap, clarsimp+)
  apply (cases cap, simp_all)
   -- "PageCap"
    apply (clarsimp simp: valid_cap_simps cli_no_irqs)
    apply (cases "invocation_type label", simp_all)
   -- "Map"
       apply(clarsimp simp: isPageFlush_def isPDFlush_def | rule conjI)+
        apply(drule diminished_cte_wp_at_valid_cap)
         apply(clarsimp simp: invs_def valid_state_def)
        apply(simp add: valid_cap_def)
       apply(simp add: vmsz_aligned_def)
       apply(drule_tac ptr="msg ! 0" and off="2 ^ pageBitsForSize vmpage_size - 1" in is_aligned_no_wrap')
        apply(insert pbfs_less_wb)
        apply(clarsimp)
       apply(fastforce simp: x_power_minus_1)
   -- "Remap"
      apply(clarsimp)
      apply(fastforce dest: diminished_cte_wp_at_valid_cap simp: invs_def valid_state_def valid_cap_def)
   -- "Unmap"
     apply(simp add: authorised_for_globals_page_inv_def)+
   apply(clarsimp)
   -- "PageTableCap"
   apply(simp add: authorised_for_globals_page_table_inv_def)
   apply(clarsimp)
   apply(frule_tac vptr="msg ! 0" in pd_shifting')
   apply(clarsimp)
   apply(clarsimp simp: invs_def valid_state_def valid_global_refs_def valid_refs_def global_refs_def)
   apply(erule_tac x=aa in allE)
   apply(erule_tac x=b in allE)
   apply(drule_tac P'="\<lambda>c. idle_thread s \<in> cap_range c \<or>
                 arm_globals_frame (arch_state s) \<in> cap_range c \<or>
                 arm_global_pd (arch_state s) \<in> cap_range c \<or>
                 (range (interrupt_irq_node s) \<union>
                  set (arm_global_pts (arch_state s))) \<inter>
                 cap_range c \<noteq>
                 {}" in cte_wp_at_weakenE)
    apply(drule diminished_PageDirectoryCapD)
    apply(clarsimp simp: cap_range_def)
   apply(simp)
  apply(fastforce)
  done

lemma as_user_globals_equiv:
  "\<lbrace>globals_equiv s and valid_ko_at_arm and (\<lambda>s. tptr \<noteq> idle_thread s)\<rbrace> as_user tptr f
    \<lbrace>\<lambda>_. globals_equiv s\<rbrace>"
  unfolding as_user_def
  apply(wp)
     apply(simp add: split_def)
     apply(wp set_object_globals_equiv)
     apply(clarsimp simp: valid_ko_at_arm_def get_tcb_def obj_at_def)
  done

lemma as_user_valid_ko_at_arm[wp]:
  "\<lbrace> valid_ko_at_arm \<rbrace>
  as_user thread f
  \<lbrace> \<lambda>_. valid_ko_at_arm\<rbrace>"
  unfolding as_user_def
  apply wp
     apply (case_tac x)
     apply (simp | wp select_wp)+
  apply(fastforce simp: valid_ko_at_arm_def get_tcb_ko_at obj_at_def)
done

lemma arm_global_pd_not_tcb:
  "valid_ko_at_arm s \<Longrightarrow> get_tcb (arm_global_pd (arch_state s)) s = None"
  unfolding valid_ko_at_arm_def
  apply (case_tac "get_tcb (arm_global_pd (arch_state s)) s")
  apply simp
  apply(clarsimp simp: valid_ko_at_arm_def get_tcb_ko_at obj_at_def)
done

(*FIXME: Not sure where these should go. Proved while working on Tcb_IF but not needed anymore.*)
lemma valid_arch_arm_asid_table_unmap:
  "valid_arch_state s
       \<and> tab = arm_asid_table (arch_state s)
     \<longrightarrow> valid_arch_state (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := tab(asid_high_bits_of base := None)\<rparr>\<rparr>)"
  apply (clarsimp simp: valid_state_def valid_arch_state_unmap_strg)
done

crunch valid_arch_state[wp]: load_hw_asid "valid_arch_state"

lemma valid_arch_objs_arm_asid_table_unmap:
  "valid_arch_objs s
       \<and> tab = arm_asid_table (arch_state s)
     \<longrightarrow> valid_arch_objs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := tab(asid_high_bits_of base := None)\<rparr>\<rparr>)"
  apply (clarsimp simp: valid_state_def valid_arch_objs_unmap_strg)
done

crunch valid_arch_objs[wp]: set_vm_root "valid_arch_objs"
crunch valid_arch_objs[wp]: invalidate_asid_entry "valid_arch_objs"
crunch valid_arch_objs[wp]: flush_space "valid_arch_objs"

lemma delete_asid_pool_valid_arch_obsj[wp]:
  "\<lbrace>valid_arch_objs\<rbrace>
    delete_asid_pool base pptr
  \<lbrace>\<lambda>_. valid_arch_objs\<rbrace>"
  unfolding delete_asid_pool_def
  apply (wp)
       apply (wp modify_wp)
     apply (strengthen valid_arch_objs_arm_asid_table_unmap)
     apply simp
     apply (rule hoare_vcg_conj_lift)
      apply (wp mapM_wp' | simp)+
done

crunch pspace_aligned[wp]: cap_swap_for_delete, set_cap, empty_slot "pspace_aligned" (ignore: empty_slot_ext wp: dxo_wp_weak)
crunch pspace_aligned[wp]: finalise_cap "pspace_aligned"
  (wp: mapM_x_wp' select_wp hoare_vcg_if_lift2 hoare_drop_imps modify_wp mapM_wp' dxo_wp_weak
   simp: unless_def crunch_simps arch_update.pspace_aligned_update
   ignore: tcb_sched_action reschedule_required)

crunch valid_arch_objs[wp]: cap_swap_for_delete "valid_arch_objs"
crunch valid_arch_objs[wp]: empty_slot "valid_arch_objs"

lemma set_asid_pool_arch_objs_unmap'':
 "\<lbrace>(valid_arch_objs and ko_at (ArchObj (ASIDPool ap)) p) and K(f = (ap |` S))\<rbrace> set_asid_pool p f \<lbrace>\<lambda>_. valid_arch_objs\<rbrace>"
  apply (rule hoare_gen_asm)
  apply simp
  apply (rule set_asid_pool_arch_objs_unmap)
done


lemma restrict_eq_asn_none: "f(N := None) = f |` {s. s \<noteq> N}"
  apply (rule ext)
  apply (case_tac "x = N")
   apply (simp add: restrict_map_def)+
  done

lemma delete_asid_valid_arch_objs[wp]:
  "\<lbrace>valid_arch_objs and pspace_aligned\<rbrace> delete_asid a b \<lbrace>\<lambda>_. valid_arch_objs\<rbrace>"
  unfolding delete_asid_def
  apply (wp | wpc | simp)+
       apply (wp set_asid_pool_arch_objs_unmap'')[2]
     apply (rule hoare_strengthen_post)
      prefer 2
      apply (subst restrict_eq_asn_none)
      apply simp
     apply wp
  apply fastforce
done

crunch valid_arch_objs[wp]: finalise_cap "valid_arch_objs"
  (wp: mapM_wp' mapM_x_wp' select_wp hoare_vcg_if_lift2 dxo_wp_weak hoare_drop_imps store_pde_arch_objs_unmap
   simp: crunch_simps pde_ref_def unless_def
   ignore: tcb_sched_action reschedule_required)

lemma get_cap_not_global_refs[wp]: "\<lbrace>valid_global_refs\<rbrace> get_cap a \<lbrace>\<lambda>rv s. global_refs s \<inter> cap_range rv = {}\<rbrace>"
  apply (induct a)
  apply (rule hoare_add_post)
    apply (rule get_cap_cte_wp_at)
   apply simp
  apply (unfold get_cap_def)
  apply simp
  apply wp
   prefer 2
   apply (rule get_object_inv)
  apply (case_tac x,simp_all)
   apply wp
   apply (clarsimp simp: valid_global_refs_def valid_refs_def cte_wp_at_def | wp)+
done

crunch valid_global_refs[wp]: cap_swap_for_delete "valid_global_refs"
  (wp: set_cap_globals dxo_wp_weak
   simp: crunch_simps
   ignore: set_object cap_swap_ext)

crunch valid_global_refs[wp]: empty_slot "valid_global_refs"
  (wp: hoare_drop_imps set_cap_globals dxo_wp_weak
   simp: cap_range_def
   ignore: set_object empty_slot_ext)

lemma thread_set_fault_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs\<rbrace> thread_set (tcb_fault_update A) thread \<lbrace>\<lambda>_. valid_global_refs\<rbrace>"
  apply (wp thread_set_global_refs_triv thread_set_refs_trivial thread_set_obj_at_impossible | simp)+
  apply (rule ball_tcb_cap_casesI, simp+)
done


lemma cap_swap_for_delete_valid_arch_caps[wp]:
  "\<lbrace>valid_arch_caps\<rbrace> cap_swap_for_delete a b \<lbrace>\<lambda>_. valid_arch_caps\<rbrace>"
  unfolding cap_swap_for_delete_def
  apply (wp get_cap_wp)
  apply (clarsimp simp: cte_wp_at_weakenE)
done

lemma mapM_x_swp_store_pte_reads_respects':
  "reads_respects aag l (invs and (cte_wp_at (op = (ArchObjectCap (PageTableCap word option))) slot) and K (is_subject aag word))
                        (mapM_x (swp store_pte InvalidPTE) [word , word + 4 .e. word + 2 ^ pt_bits - 1])"
  apply (rule gen_asm_ev)
  apply (wp mapM_x_ev)
   apply simp
   apply (rule equiv_valid_guard_imp)
    apply (wp store_pte_reads_respects)
   apply simp
   apply (elim conjE)
   apply (subgoal_tac "is_aligned word pt_bits")
    apply (frule (1) word_aligned_pt_slots)
    apply simp
   apply (frule cte_wp_valid_cap)
    apply (rule invs_valid_objs)
    apply simp
   apply (simp add: valid_cap_def cap_aligned_def pt_bits_def pageBits_def)
  apply simp
  apply wp
   apply simp
  apply (fastforce simp: is_cap_simps dest!: cte_wp_at_pt_exists_cap[OF invs_valid_objs])
  done

lemma mapM_x_swp_store_pde_reads_respects':
  "reads_respects aag l (cte_wp_at (op = (ArchObjectCap (PageDirectoryCap word option))) slot and valid_objs and K(is_subject aag word))
             (mapM_x (swp store_pde InvalidPDE)
               (map ((\<lambda>x. x + word) \<circ> swp op << 2) [0.e.(kernel_base >> 20) - 1]))"
  apply (wp mapM_x_ev)
   apply simp
   apply (rule equiv_valid_guard_imp)
   apply (wp store_pde_reads_respects)
   apply clarsimp
   apply (subgoal_tac "is_aligned word pd_bits")
   apply (simp add: pd_bits_store_pde_helper)
   apply (frule (1) cte_wp_valid_cap)
   apply (simp add: valid_cap_def cap_aligned_def pd_bits_def pageBits_def)
   apply simp
   apply wp
   apply (clarsimp simp: wellformed_pde_def)+
done

lemma mapM_x_swp_store_pte_pas_refined_simple:
  "invariant  (mapM_x (swp store_pte InvalidPTE) A) (pas_refined aag)"
  apply (wp mapM_x_wp')
  apply simp
  apply (wp store_pte_pas_refined_simple)
done

lemma mapM_x_swp_store_pde_pas_refined_simple:
  "invariant (mapM_x (swp store_pde InvalidPDE) A) (pas_refined aag)"
  apply (wp mapM_x_wp')
  apply simp
  apply (wp store_pde_pas_refined_simple)
done

crunch states_equiv_for: invalidate_tlb_by_asid "states_equiv_for P Q R S X st"
  (wp: do_machine_op_mol_states_equiv_for ignore: do_machine_op simp: invalidateTLB_ASID_def)

crunch cur_thread[wp]: invalidate_tlb_by_asid "\<lambda>s. P (cur_thread s)"
crunch cur_domain[wp]: invalidate_tlb_by_asid "\<lambda>s. P (cur_domain s)"
crunch sched_act[wp]: invalidate_tlb_by_asid "\<lambda>s. P (scheduler_action s)"
crunch wuc[wp]: invalidate_tlb_by_asid "\<lambda>s. P (work_units_completed s)"

lemma invalidate_tlb_by_asid_reads_respects:
  "reads_respects aag l (\<lambda>_. True) (invalidate_tlb_by_asid asid)"
  apply(rule reads_respects_unobservable_unit_return)
      apply (rule invalidate_tlb_by_asid_states_equiv_for)
     apply wp
  done

end