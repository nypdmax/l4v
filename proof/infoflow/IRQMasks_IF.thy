(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(NICTA_GPL)
 *)

theory IRQMasks_IF
imports "../access-control/DomainSepInv"
begin

abbreviation irq_masks_of_state :: "det_ext state \<Rightarrow> irq \<Rightarrow> bool" where
  "irq_masks_of_state s \<equiv> irq_masks (machine_state s)"

lemma resetTimer_irq_masks[wp]:
  "\<lbrace>\<lambda>s. P (irq_masks s)\<rbrace> resetTimer \<lbrace>\<lambda>_ s. P (irq_masks s)\<rbrace>"
  apply(simp add: resetTimer_def | wp)+
  done

lemma storeWord_irq_masks[wp]:
  "\<lbrace>\<lambda>s. P (irq_masks s)\<rbrace> storeWord x y \<lbrace>\<lambda>_ s. P (irq_masks s)\<rbrace>"
  apply(wp del: no_irq | simp add: storeWord_def)+
  done


crunch irq_masks[wp]: send_async_ipc "\<lambda>s. P (irq_masks_of_state s)"  
  (wp: crunch_wps ignore: do_machine_op wp: dmo_wp simp: crunch_simps)

lemma handle_interrupt_irq_masks:
  notes no_irq[wp del]
  shows
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace>
   handle_interrupt irq
   \<lbrace>\<lambda>rv s. P (irq_masks_of_state s)\<rbrace>"
  apply(simp add: handle_interrupt_def)
  apply(wp dmo_wp | simp add: ackInterrupt_def maskInterrupt_def split del: split_if | wpc | simp add: get_irq_state_def)+
  apply(fastforce simp: domain_sep_inv_def)
  done

crunch irq_masks[wp]: cap_insert "\<lambda>s. P (irq_masks_of_state s)"
  (wp: crunch_wps)


lemma invoke_irq_handler_irq_masks:
  shows
  "\<lbrace>domain_sep_inv False st and (\<lambda>s. (\<exists>ptr'. cte_wp_at (op = (IRQHandlerCap irq)) ptr' s))\<rbrace> 
    invoke_irq_handler blah 
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(clarsimp simp: valid_def domain_sep_inv_def)
  done

lemma detype_irq_masks[simp]:
  "irq_masks (machine_state (detype S s)) = irq_masks_of_state s"
  apply(simp add: detype_def)
  done

lemma delete_objects_irq_masks[wp]:
  "\<lbrace>\<lambda>s. P (irq_masks_of_state s)\<rbrace> delete_objects param_a param_b 
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(simp add: delete_objects_def)
  apply(wp dmo_wp no_irq_mapM_x | simp add: freeMemory_def no_irq_storeWord)+
  done
  

crunch irq_masks[wp]: invoke_untyped "\<lambda>s. P (irq_masks_of_state s)"
  (ignore: delete_objects wp: crunch_wps dmo_wp simp: crunch_simps no_irq_clearMemory no_irq_cleanCacheRange_PoU mapM_x_def_bak)

crunch irq_masks[wp]: set_extra_badge "\<lambda>s. P (irq_masks_of_state s)"

crunch irq_masks[wp]: send_ipc "\<lambda>s. P (irq_masks_of_state s)"
  (wp: crunch_wps simp: crunch_simps ignore: const_on_failure wp: transfer_caps_loop_pres)

lemma empty_slot_irq_masks:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and K (irq_opt = None)\<rbrace> 
   empty_slot slot irq_opt
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(rule hoare_gen_asm)
  apply(simp add: empty_slot_def | wp)+
  done

crunch irq_masks[wp]: do_reply_transfer "\<lambda>s. P (irq_masks_of_state s)"
  (wp: crunch_wps empty_slot_irq_masks simp: crunch_simps unless_def)

crunch irq_masks[wp]: finalise_cap "\<lambda>s. P (irq_masks_of_state s)"
  (wp: select_wp crunch_wps dmo_wp simp: crunch_simps no_irq_setHardwareASID no_irq_setCurrentPD no_irq_invalidateTLB_ASID no_irq_invalidateTLB_VAASID no_irq_cleanByVA_PoU)

crunch irq_masks[wp]: cap_swap_for_delete "\<lambda>s. P (irq_masks_of_state s)"

(* Clagged from re_del_domain_sep_inv' -- would Dan's annotations be good here? *)
lemma rec_del_irq_masks':
  notes drop_spec_valid[wp_split del] drop_spec_validE[wp_split del]
         rec_del.simps[simp del]
  shows
  "s \<turnstile> \<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace>
     (rec_del call)
   \<lbrace>\<lambda> a s. (case call of (FinaliseSlotCall x y) \<Rightarrow> y \<or> fst a \<longrightarrow> snd a = None | _ \<Rightarrow> True) \<and> domain_sep_inv False st s \<and> P (irq_masks_of_state s)\<rbrace>,\<lbrace>\<lambda>_. domain_sep_inv False st and (\<lambda>s. P (irq_masks_of_state s))\<rbrace>"
  proof (induct s arbitrary: rule: rec_del.induct, simp_all only: rec_del_fails hoare_fail_any)
  case (1 slot exposed s) show ?case
    apply(simp add: split_def rec_del.simps)
    apply(wp empty_slot_domain_sep_inv empty_slot_irq_masks drop_spec_validE[OF returnOk_wp] drop_spec_validE[OF liftE_wp] | simp)+
    apply(rule spec_strengthen_postE[OF "1.hyps", simplified])
    apply fastforce
    done
  next
  case (2 slot exposed s) show ?case
    apply(simp add: rec_del.simps split del: split_if)
    apply(rule hoare_pre_spec_validE)
     apply(wp drop_spec_validE[OF returnOk_wp] drop_spec_validE[OF liftE_wp] set_cap_domain_sep_inv
          |simp add: split_def split del: split_if)+
           apply(rule spec_strengthen_postE)
            apply(rule "2.hyps"[simplified], fastforce+)
          apply(rule drop_spec_validE, (wp preemption_point_inv | simp)+)[1]
         apply simp
         apply(rule spec_strengthen_postE)
          apply(rule "2.hyps"[simplified], fastforce+)
         apply(wp  finalise_cap_domain_sep_inv_cap get_cap_wp 
                   finalise_cap_returns_None[where irqs=False, simplified]
                   drop_spec_validE[OF liftE_wp] set_cap_domain_sep_inv
               |simp add: without_preemption_def split del: split_if
               |wp_once hoare_drop_imps)+
    apply(blast dest: cte_wp_at_domain_sep_inv_cap)
    done
  next
  case (3 ptr bits n slot s) show ?case
    apply(simp add: rec_del.simps)
    apply (wp drop_spec_validE[OF returnOk_wp] drop_spec_validE[OF liftE_wp])
    apply(rule hoare_pre_spec_validE)
    apply (wp drop_spec_validE[OF assertE_wp])
    apply(fastforce)
    done
  next
  case (4 ptr bits n slot s) show ?case
    apply(simp add: rec_del.simps)
    apply (wp drop_spec_validE[OF returnOk_wp] drop_spec_validE[OF liftE_wp] set_cap_domain_sep_inv
              drop_spec_validE[OF assertE_wp] get_cap_wp | simp add: without_preemption_def)+
    apply (rule spec_strengthen_postE[OF "4.hyps", simplified])
     apply(simp add: returnOk_def return_def)
    apply(clarsimp simp: domain_sep_inv_cap_def)
    done
  qed

lemma spec_strengthen_errE:
  "\<lbrakk>s \<turnstile> \<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace>, \<lbrace>E'\<rbrace>; \<And>s r. E' s r \<Longrightarrow> E s r\<rbrakk> \<Longrightarrow> s \<turnstile> \<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace>, \<lbrace>E\<rbrace>"
  apply(auto simp: spec_validE_def validE_def valid_def split: sum.splits)
  done


lemma rec_del_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace>
     (rec_del call)
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>,\<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(rule use_spec)
  apply(rule hoare_pre_spec_validE)
   apply(rule spec_strengthen_postE)
   apply(rule spec_strengthen_errE[OF rec_del_irq_masks'])
  apply auto
  done

lemma cap_delete_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace>
     cap_delete blah
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>,\<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(simp add: cap_delete_def | wp rec_del_irq_masks)+
  done

lemma invoke_irq_control_irq_masks:
  "\<lbrace>domain_sep_inv False st and irq_control_inv_valid invok\<rbrace>
   invoke_irq_control invok
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(case_tac invok)
   apply(clarsimp simp: irq_control_inv_valid_def domain_sep_inv_def valid_def)+
  done

lemma no_irq_do_flush:
  "no_irq (do_flush flush_type vstart vend pstart)"
  apply (clarsimp simp: no_irq_def)
  apply (cases "flush_type")
     apply (wp dmo_cacheRangeOp_lift | simp add: do_flush_def cache_machine_op_defs do_flush_defs do_machine_op_bind when_def | clarsimp | rule conjI)+
     done
      
crunch irq_masks[wp]: arch_perform_invocation "\<lambda>s. P (irq_masks_of_state s)"
  (wp: dmo_wp crunch_wps simp: crunch_simps no_irq_cleanByVA_PoU no_irq_invalidateTLB_ASID no_irq_do_flush)

crunch irq_masks[wp]: restart "\<lambda>s. P (irq_masks_of_state s)"

lemma checked_insert_irq_masks[wp]:
  "\<lbrace>\<lambda> s. P (irq_masks_of_state s)\<rbrace>
   check_cap_at a b
           (check_cap_at c d
             (cap_insert e f g))
          \<lbrace>\<lambda>r s. P (irq_masks_of_state s)\<rbrace>"
  apply(wp | simp add: check_cap_at_def)+
  done

(* FIXME: remove duplication in this proof -- requires getting the wp 
          automation to do the right thing with dropping imps in validE
          goals *)
lemma invoke_tcb_irq_masks:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and
    tcb_inv_wf tinv\<rbrace>
   invoke_tcb tinv
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(case_tac tinv)
       apply((wp restart_irq_masks hoare_vcg_if_lift  mapM_x_wp[OF _ subset_refl]
            | wpc
            | simp split del: split_if add: check_cap_at_def 
            | clarsimp)+)[3]
    defer
    apply((wp | simp )+)[2]
  (* just ThreadControl left *)
  apply (simp add: split_def cong: option.case_cong)

  apply (wp hoare_vcg_all_lift_R 
            hoare_vcg_all_lift hoare_vcg_const_imp_lift_R
            checked_cap_insert_domain_sep_inv
            cap_delete_deletes 
            cap_delete_valid_cap cap_delete_cte_at 
        |wpc
        |simp add: emptyable_def tcb_cap_cases_def tcb_cap_valid_def
                  tcb_at_st_tcb_at
        |strengthen use_no_cap_to_obj_asid_strg)+
     apply(rule hoare_post_impErr[OF cap_delete_irq_masks[where P=P]])
      apply blast
     apply blast
    apply (wp hoare_vcg_all_lift_R 
              hoare_vcg_all_lift hoare_vcg_const_imp_lift_R
              checked_cap_insert_domain_sep_inv
              cap_delete_deletes 
              cap_delete_valid_cap cap_delete_cte_at 
          |wpc
          |simp add: emptyable_def tcb_cap_cases_def tcb_cap_valid_def
                    tcb_at_st_tcb_at
          |strengthen use_no_cap_to_obj_asid_strg)+
    apply(rule_tac Q="\<lambda> r s. domain_sep_inv False st s \<and> P (irq_masks_of_state s)" and E="\<lambda>_ s. P (irq_masks_of_state s)" in hoare_post_impErr)
      apply(wp hoare_vcg_conj_liftE1 cap_delete_irq_masks)
     apply fastforce
    apply blast
   apply (wp static_imp_wp hoare_vcg_all_lift_R 
             hoare_vcg_all_lift hoare_vcg_const_imp_lift_R
             checked_cap_insert_domain_sep_inv
             cap_delete_deletes 
             cap_delete_valid_cap cap_delete_cte_at 
         |wpc
         |simp add: emptyable_def tcb_cap_cases_def tcb_cap_valid_def
                   tcb_at_st_tcb_at
         |strengthen use_no_cap_to_obj_asid_strg)+
   apply(rule_tac Q="\<lambda> r s. domain_sep_inv False st s \<and> P (irq_masks_of_state s)" and E="\<lambda>_ s. P (irq_masks_of_state s)" in hoare_post_impErr)
     apply(wp hoare_vcg_conj_liftE1 cap_delete_irq_masks)
    apply fastforce
   apply blast
  apply(rule hoare_pre)
  apply(simp add: option_update_thread_def tcb_cap_cases_def
       | wp static_imp_wp hoare_vcg_all_lift 
            thread_set_emptyable 
            thread_set_valid_cap 
            thread_set_cte_at  thread_set_no_cap_to_trivial
       | wpc)+
  apply fastforce+
  done

crunch irq_masks[wp]: cap_move "\<lambda>s. P (irq_masks_of_state s)"

lemma irq_state_independent_irq_masks:
  "irq_state_independent (\<lambda>s. P (irq_masks s))"
  apply(clarsimp simp: irq_state_independent_def)
  done

lemma preemption_point_irq_masks[wp]:
  "\<lbrace>\<lambda>s. P (irq_masks_of_state s)\<rbrace> preemption_point \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  by (wp preemption_point_inv, simp+)

lemma cap_revoke_irq_masks':
  notes drop_spec_valid[wp_split del] drop_spec_validE[wp_split del]
  shows
  "s \<turnstile> \<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace>
   cap_revoke slot
   \<lbrace> \<lambda>_ s. P (irq_masks_of_state s)\<rbrace>, \<lbrace> \<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  proof(induct rule: cap_revoke.induct[where ?a1.0=s])
  case (1 slot s)
  show ?case
  apply(subst cap_revoke.simps)
  apply(rule hoare_pre_spec_validE)
   apply (wp "1.hyps", assumption+)
           apply(wp spec_valid_conj_liftE2 | simp)+
           apply(wp drop_spec_validE[OF valid_validE[OF preemption_point_irq_masks]]
                    drop_spec_validE[OF valid_validE[OF preemption_point_domain_sep_inv]] 
                    cap_delete_domain_sep_inv cap_delete_irq_masks
                    drop_spec_validE[OF assertE_wp] drop_spec_validE[OF returnOk_wp]
                    drop_spec_validE[OF liftE_wp] select_wp
                    drop_spec_validE[OF  hoare_vcg_conj_liftE1]
                | simp | wp_once hoare_drop_imps)+
  apply fastforce
  done
  qed

lemmas cap_revoke_irq_masks = use_spec(2)[OF cap_revoke_irq_masks']

crunch irq_masks[wp]: recycle_cap "\<lambda>s. P (irq_masks_of_state s)"
  (wp: crunch_wps dmo_wp simp: filterM_mapM crunch_simps no_irq_clearMemory no_irq_invalidateTLB_ASID
   ignore: filterM)

lemma finalise_slot_irq_masks:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace> finalise_slot p e \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"     
  apply(simp add: finalise_slot_def | wp rec_del_irq_masks)+
  done

lemma cap_recycle_irq_masks:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st\<rbrace> cap_recycle blah \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"     
  apply(simp add: cap_recycle_def)
  apply(wp hoare_unless_wp  finalise_slot_irq_masks[where st=st] | simp add: conj_ac)+
  apply(rule hoare_pre(2)[OF hoare_vcg_conj_liftE1])
  apply(rule validE_validE_R[OF hoare_post_impErr, OF cap_revoke_domain_sep_inv], simp+)
  apply(wp cap_revoke_irq_masks, auto)
  done

lemma invoke_cnode_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and 
     valid_cnode_inv ci\<rbrace> 
   invoke_cnode ci 
   \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  unfolding invoke_cnode_def
  apply(case_tac ci)
        apply(wp cap_insert_irq_masks cap_move_irq_masks cap_revoke_irq_masks[where st=st] cap_delete_irq_masks[where st=st] | simp split del: split_if)+
    apply(rule hoare_pre)
     apply(wp hoare_vcg_all_lift cap_recycle_irq_masks | simp | wpc | wp_once hoare_drop_imps)+
  by auto

fun irq_of_handler_inv where
  "irq_of_handler_inv (ACKIrq irq) = irq" |
  "irq_of_handler_inv (ClearIRQHandler irq) = irq" |
  "irq_of_handler_inv (SetIRQHandler irq _ _) = irq"

crunch irq_masks[wp]: invoke_domain "\<lambda>s. P (irq_masks_of_state s)"

lemma perform_invocation_irq_masks:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and (\<lambda>s. (\<forall> blah. oper = InvokeIRQHandler blah \<longrightarrow>  (\<exists>ptr'. cte_wp_at (op = (IRQHandlerCap (irq_of_handler_inv blah))) ptr' s))) and domain_sep_inv False st and valid_invocation oper\<rbrace>
  perform_invocation blocking calling oper
  \<lbrace>\<lambda>_ s. P (irq_masks_of_state s)\<rbrace>"
  apply(case_tac oper)
          apply(simp | wp invoke_tcb_irq_masks invoke_cnode_irq_masks[where st=st] invoke_irq_control_irq_masks[where st=st] invoke_irq_handler_irq_masks[where st=st])+
   apply blast
  apply(simp | wp)+
  done

crunch irq_masks[wp]: handle_fault "\<lambda>s. P (irq_masks_of_state s)"
  (simp: crunch_simps wp: crunch_wps)

crunch irq_masks[wp]: reply_from_kernel "\<lambda>s. P (irq_masks_of_state s)"
  (simp: crunch_simps wp: crunch_wps)



lemma decode_invocation_IRQHandlerCap:
  "\<lbrace> cte_wp_at (diminished cap) slot \<rbrace>
   decode_invocation label args cap_index slot cap blah
       \<lbrace>\<lambda>rv s.
           (\<forall>x. rv = InvokeIRQHandler x \<longrightarrow>
                (\<exists>a b. cte_wp_at
                        (op = (IRQHandlerCap (irq_of_handler_inv x)))
                        (a, b) s))\<rbrace>,-"
  apply(simp add: decode_invocation_def split del: split_if)
  apply(rule hoare_pre)
   apply (wp | wpc | simp add: o_def del: split_if)+
       apply (rule hoare_post_imp_R[where Q'="\<top>\<top>"])
        apply wp
       apply (clarsimp simp: uncurry_def)
      apply(wp | wpc | simp add: decode_irq_handler_invocation_def o_def split del: split_if)+
  apply (safe | rule TrueI | simp add: diminished_IRQHandler op_equal | rule exI[where x="fst slot"], rule exI[where x="snd slot"])+
  done

lemma handle_invocation_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and invs\<rbrace>
   handle_invocation calling blocking
   \<lbrace> \<lambda> rv s. P (irq_masks_of_state s) \<rbrace>"
  apply (simp add: handle_invocation_def ts_Restart_case_helper split_def
                   liftE_liftM_liftME liftME_def bindE_assoc
              split del: split_if)
  apply(wp static_imp_wp syscall_valid perform_invocation_irq_masks[where st=st] hoare_vcg_all_lift hoare_vcg_ex_lift decode_invocation_IRQHandlerCap
       | simp split del: split_if)+
  apply(simp add: invs_valid_objs)
  done

crunch irq_masks[wp]: handle_reply "\<lambda>s. P (irq_masks_of_state s)"

crunch irq_masks[wp]: handle_wait "\<lambda>s. P (irq_masks_of_state s)"
  (wp: crunch_wps simp: crunch_simps)

crunch irq_masks[wp]: handle_vm_fault "\<lambda>s. P (irq_masks_of_state s)"
  (wp: dmo_wp ignore: getFAR getDFSR getIFSR simp: no_irq_getDFSR no_irq_getFAR no_irq_getIFSR)

lemma dmo_getActiveIRQ_irq_masks[wp]:
  "\<lbrace>(\<lambda>s. P (irq_masks_of_state s))\<rbrace>
    do_machine_op getActiveIRQ 
    \<lbrace>\<lambda>x s. P (irq_masks_of_state s)\<rbrace>" 
  apply(rule hoare_pre, rule dmo_wp)
  apply(simp add: getActiveIRQ_def | wp | simp add: no_irq_def | clarsimp)+
  done

lemma handle_yield_irq_masks_of_state[wp]: "\<lbrace>(\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and invs\<rbrace> handle_yield \<lbrace>\<lambda>rv s. P (irq_masks_of_state s)\<rbrace>"
  apply (simp add: handle_yield_def)
  apply wp
  apply simp
  done

lemma handle_event_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and invs\<rbrace>
   handle_event ev
   \<lbrace> \<lambda> rv s. P (irq_masks_of_state s) \<rbrace>"
  apply(case_tac ev)
      apply(case_tac syscall)
             apply(simp add: handle_send_def handle_call_def | wp handle_invocation_irq_masks[where st=st] handle_interrupt_irq_masks[where st=st] hoare_vcg_all_lift | wpc | wp_once hoare_drop_imps)+
  done

crunch irq_masks[wp]: activate_thread "\<lambda>s. P (irq_masks_of_state s)"

crunch irq_masks[wp]: schedule "\<lambda>s. P (irq_masks_of_state s)"
  (wp: dmo_wp alternative_wp select_wp crunch_wps simp: clearExMonitor_def)

lemma call_kernel_irq_masks:
  "\<lbrace> (\<lambda>s. P (irq_masks_of_state s)) and domain_sep_inv False st and einvs and (\<lambda>s. ev \<noteq> Interrupt \<longrightarrow> ct_active s)\<rbrace>
   call_kernel ev
   \<lbrace> \<lambda> rv s. P (irq_masks_of_state s) \<rbrace>"
  apply(simp add: call_kernel_def)
  apply (wp handle_interrupt_irq_masks[where st=st])+
   apply(rule_tac Q="\<lambda>_ s. P (irq_masks_of_state s) \<and> domain_sep_inv False st s" in hoare_strengthen_post)
    apply(wp | simp)+
  apply(rule_tac Q="\<lambda> x s. P (irq_masks_of_state s) \<and> domain_sep_inv False st s" and F="?E" in hoare_post_impErr)
    apply(rule valid_validE)
    apply(wp handle_event_irq_masks[where st=st] valid_validE[OF handle_event_domain_sep_inv] | simp)+
  done

end (* a comment *)