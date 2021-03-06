(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory Finalise_AI
imports
  IpcCancel_AI
  InterruptAcc_AI
  Retype_AI
begin

text {* Properties about empty_slot *}

definition
 "halted_if_tcb \<equiv> \<lambda>t s. tcb_at t s \<longrightarrow> st_tcb_at halted t s"


lemma halted_emptyable:
  "\<And>ref. halted_if_tcb t s \<Longrightarrow> emptyable (t, ref) s"
  by (simp add: halted_if_tcb_def emptyable_def)


lemma tcb_cap_valid_NullCapD:
  "\<And>cap sl. \<lbrakk> tcb_cap_valid cap sl s; \<not> is_master_reply_cap cap \<rbrakk> \<Longrightarrow>
   tcb_cap_valid cap.NullCap sl s"
  apply (clarsimp simp: tcb_cap_valid_def valid_ipc_buffer_cap_def
                 elim!: st_tcb_weakenE split: option.splits)
  apply (rename_tac get set restr)
  apply (subgoal_tac "(get, set, restr) \<in> ran tcb_cap_cases")
   apply (fastforce simp: ran_tcb_cap_cases is_cap_simps
                  split: Structures_A.thread_state.split)
  apply (simp add: ranI)
  done


lemma emptyable_valid_NullCapD:
  "\<lbrakk> emptyable sl s; valid_objs s \<rbrakk> \<Longrightarrow> tcb_cap_valid cap.NullCap sl s"
  apply (clarsimp simp: emptyable_def tcb_cap_valid_def
                        valid_ipc_buffer_cap_def)
  apply (clarsimp simp: st_tcb_at_def obj_at_def is_tcb split: option.split)
  apply (erule(1) valid_objsE)
  apply (clarsimp simp: valid_obj_def valid_tcb_def tcb_cap_cases_def
                 split: Structures_A.thread_state.split)
  done


lemma emptyable_valid_NullCap_strg:
  "emptyable sl s \<and> valid_objs s \<longrightarrow> tcb_cap_valid cap.NullCap sl s"
  by (simp add: emptyable_valid_NullCapD)


lemma tcb_cap_valid_pspaceI[intro]:
  "\<lbrakk> tcb_cap_valid cap sl s; kheap s = kheap s' \<rbrakk> \<Longrightarrow> tcb_cap_valid cap sl s'"
  by (clarsimp simp: tcb_cap_valid_def obj_at_def st_tcb_at_def)


crunch valid_objs[wp]: deleted_irq_handler "valid_objs"


lemma emptyable_rvk[simp]:
  "emptyable sl (is_original_cap_update f s) = emptyable sl s"
  by (simp add: emptyable_def)


lemma set_cdt_emptyable[wp]:
  "\<lbrace>emptyable sl\<rbrace> set_cdt m \<lbrace>\<lambda>rv. emptyable sl\<rbrace>"
  by (simp add: set_cdt_def emptyable_def | wp)+

lemma emptyable_more_update[simp]:
  "emptyable sl (trans_state f s) = emptyable sl s"
  by (simp add: emptyable_def)

lemma tcb_cp_valid_trans_state_update[simp]: "tcb_cap_valid cap sl
         (trans_state f s) = tcb_cap_valid cap sl s"
  apply (simp add: tcb_cap_valid_def)
  done

lemma empty_slot_valid_objs[wp]:
  "\<lbrace>valid_objs and emptyable sl\<rbrace> empty_slot sl irqopt \<lbrace>\<lambda>rv. valid_objs\<rbrace>"
  apply (simp add: empty_slot_def)
  apply (rule hoare_pre)
   apply (wp set_cap_valid_objs set_cdt_valid_objs set_cdt_valid_cap
                 | simp add: trans_state_update[symmetric] del: trans_state_update| wpcw
                 | strengthen emptyable_valid_NullCap_strg
                 | wp_once hoare_drop_imps)+
  done


lemmas empty_slot_valid_cap[wp] = valid_cap_typ [OF empty_slot_typ_at]


locale mdb_empty_abs = vmdb_abs +
  fixes slot
  fixes n::cdt
  defines "n \<equiv> (\<lambda>p. (if m p = Some slot then m slot else m p)) (slot := None)"


lemma (in mdb_empty_abs) parency:
  "n \<Turnstile> p \<rightarrow> p' = (p \<noteq> slot \<and> p' \<noteq> slot \<and> m \<Turnstile> p \<rightarrow> p')"
proof
  assume n: "n \<Turnstile> p \<rightarrow> p'"

  from n
  have "p \<noteq> slot"
    by (clarsimp dest!: tranclD simp: n_def cdt_parent_of_def
                 split: split_if_asm)
  moreover
  from n
  have "p' \<noteq> slot"
    by (clarsimp dest!: tranclD2 simp: n_def cdt_parent_of_def )
  moreover
  from n
  have "m \<Turnstile> p \<rightarrow> p'"
  proof induct
    case (base x)
    thus ?case
      apply (clarsimp simp: cdt_parent_of_def n_def split: split_if_asm)
       apply (rule trancl_trans)
        apply (fastforce simp: cdt_parent_of_def)+
      done
  next
    case (step y z)
    thus ?case
      apply (clarsimp simp: cdt_parent_of_def n_def split: split_if_asm)
       apply (erule trancl_trans)
       apply (rule trancl_trans)
        apply (fastforce simp: cdt_parent_of_def)
       apply (fastforce simp: cdt_parent_of_def)
      apply (erule trancl_trans)
      apply (fastforce simp: cdt_parent_of_def)
      done
  qed
  ultimately
  show "p \<noteq> slot \<and> p' \<noteq> slot \<and> m \<Turnstile> p \<rightarrow> p'" by simp
next
  assume asm: "p \<noteq> slot \<and> p' \<noteq> slot \<and> m \<Turnstile> p \<rightarrow> p'"

  from asm have p: "p \<noteq> slot" ..
  from asm have p': "p' \<noteq> slot" by simp

  from asm
  have m: "m \<Turnstile> p \<rightarrow> p'" by simp
  hence neq: "p \<noteq> p'" by clarsimp
  from m
  have "if p' = slot then
          \<exists>p''. (p, p'') \<in> (cdt_parent_rel m)^* \<and> m \<Turnstile> p'' \<leadsto> p' \<and> (p, p'') \<in> (cdt_parent_rel n)^*
        else
          n \<Turnstile> p \<rightarrow> p'"
  proof induct
    case (base y)
    thus ?case
      apply (clarsimp simp: cdt_parent_of_def simp del: split_paired_Ex)
      apply (fastforce simp: cdt_parent_of_def n_def p)
      done
  next
    case (step y z)
    thus ?case
      apply (clarsimp simp: cdt_parent_of_def simp del: split_paired_Ex)
      apply (rule conjI)
       apply (clarsimp simp del: split_paired_Ex)
       apply (cases "y = slot", simp)
       apply fastforce
      apply (clarsimp simp del: split_paired_Ex)
      apply (cases "y = slot")
       apply (simp del: split_paired_Ex)
       apply (elim exE conjE)
       apply (drule rtranclD [where R="cdt_parent_rel n"])
       apply (erule disjE)
        apply simp
        apply (rule r_into_trancl)
        apply (clarsimp simp: cdt_parent_of_def n_def)
       apply clarsimp
       apply (erule trancl_trans)
       apply (fastforce simp: cdt_parent_of_def n_def)
      apply simp
      apply (erule trancl_trans)
      apply (fastforce simp: cdt_parent_of_def n_def)
      done
  qed
  with p'
  show "n \<Turnstile> p \<rightarrow> p'" by simp
qed


lemma (in mdb_empty_abs) descendants:
  "descendants_of p n =
  (if p = slot then {} else descendants_of p m - {slot})"
  by (auto simp add: descendants_of_def parency)


lemma (in mdb_empty_abs) no_mloop_n:
  "no_mloop n"
  by (simp add: no_mloop_def parency)


lemma final_mdb_update[simp]:
  "is_final_cap' cap (cdt_update f s) = is_final_cap' cap s"
  by (clarsimp simp: is_final_cap'_def2)


lemma no_cap_to_obj_with_diff_cdt_update[simp]:
  "no_cap_to_obj_with_diff_ref cap S (cdt_update f s)
        = no_cap_to_obj_with_diff_ref cap S s"
  by (simp add: no_cap_to_obj_with_diff_ref_def)


lemma no_cap_to_obj_with_diff_rvk_update[simp]:
  "no_cap_to_obj_with_diff_ref cap S (is_original_cap_update f s)
        = no_cap_to_obj_with_diff_ref cap S s"
  by (simp add: no_cap_to_obj_with_diff_ref_def)


lemma reachable_pg_cap_cdt_update[simp]:
  "reachable_pg_cap x (cdt_update f s) = reachable_pg_cap x s"
  by (simp add: reachable_pg_cap_def)


lemma replaceable_cdt_update[simp]:
  "replaceable (cdt_update f s) = replaceable s"
  by (clarsimp simp: replaceable_def tcb_cap_valid_def   intro!: ext)


lemma valid_pspace_cdt_update[simp]:
  "valid_pspace (cdt_update f s) = valid_pspace s"
  by (fastforce elim!: valid_pspace_eqI)


lemma ifunsafe_cdt_update[simp]:
  "if_unsafe_then_cap (cdt_update f s) = if_unsafe_then_cap s"
  by (fastforce elim!: ifunsafe_pspaceI)


lemma reachable_pg_cap_is_original_cap_update[simp]:
  "reachable_pg_cap x (is_original_cap_update f s) = reachable_pg_cap x s"
  by (simp add: reachable_pg_cap_def)


lemma replaceable_revokable_update[simp]:
  "replaceable (is_original_cap_update f s) = replaceable s"
  by (clarsimp intro!: ext
                 simp: replaceable_def is_final_cap'_def2
                       tcb_cap_valid_def)


lemma zombies_final_cdt_update[simp]:
  "zombies_final (cdt_update f s) = zombies_final s"
  by (fastforce elim!: zombies_final_pspaceI)


lemma opt_deleted_irq_handler_invs:
  "\<lbrace>\<lambda>s. invs s \<and> (\<forall>irq. opt = Some irq \<longrightarrow> cap.IRQHandlerCap irq \<notin> ran (caps_of_state s))\<rbrace>
     case opt of Some irq \<Rightarrow> deleted_irq_handler irq | _ \<Rightarrow> return ()
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: deleted_irq_handler_def cong: option.case_cong)
  apply (rule hoare_pre)
   apply (wp | wpc)+
  apply clarsimp
  done


lemma emptyable_no_reply_cap:
  assumes e: "emptyable sl s"
  and   mdb: "reply_caps_mdb (mdb s) (caps_of_state s)"
  and    vr: "valid_reply_caps s"
  and    vm: "valid_reply_masters s"
  and    vo: "valid_objs s"
  and    rc: "caps_of_state s sl' = Some (cap.ReplyCap t False)"
  and    rp: "mdb s sl' = Some sl"
  shows      "False"
proof -
  have rm:
    "caps_of_state s sl = Some (cap.ReplyCap t True)"
    using mdb rc rp unfolding reply_caps_mdb_def
    by fastforce
  have tcb_slot:
    "sl = (t, tcb_cnode_index 2)"
    using vm rm unfolding valid_reply_masters_def
    by (fastforce simp: cte_wp_at_caps_of_state)
  have tcb_halted:
    "st_tcb_at halted t s"
    using vo rm tcb_slot e unfolding emptyable_def
    by (fastforce dest: caps_of_state_valid_cap simp: valid_cap_def)
  have tcb_not_halted:
    "st_tcb_at (Not \<circ> halted) t s"
    using vr rc unfolding valid_reply_caps_def
    by (fastforce simp add: has_reply_cap_def cte_wp_at_caps_of_state
                 simp del: split_paired_Ex
                    elim!: st_tcb_weakenE)
  show ?thesis
    using tcb_halted tcb_not_halted
    by (clarsimp simp: st_tcb_def2)
qed

lemma tcb_cap_valid_more_update[simp]:
  "tcb_cap_valid cap sl (trans_state f s) = tcb_cap_valid cap sl s"
  by (simp add: tcb_cap_valid_def)

lemma reachable_pg_cap_update[simp]:
  "reachable_pg_cap cap' (trans_state f s) = reachable_pg_cap cap' s"
  by (simp add:reachable_pg_cap_def vs_lookup_pages_def
    vs_lookup_pages1_def obj_at_def)

lemma reachable_pg_cap_exst_update[simp]:
  "reachable_pg_cap cap' (trans_state f s) = reachable_pg_cap cap' s"
  by (simp add:reachable_pg_cap_def)

lemma replaceable_more_update[simp]:
  "replaceable (trans_state f s) sl cap cap' = replaceable s sl cap cap'"
  by (simp add: replaceable_def)


(* FIXME: move *)
lemma obj_ref_ofI: "obj_refs cap = {x} \<Longrightarrow> obj_ref_of cap = x"
  by (case_tac cap, simp_all) (case_tac arch_cap, simp_all)
lemmas obj_ref_ofI' = obj_ref_ofI[OF obj_ref_elemD]


lemma vs_lookup_pages_eq:
  "\<lbrakk>valid_arch_objs s; valid_asid_table (arm_asid_table (arch_state s)) s;
    valid_cap cap s; table_cap_ref cap = Some vref; oref \<in> obj_refs cap\<rbrakk>
   \<Longrightarrow> (vref \<unrhd> oref) s = (vref \<rhd> oref) s"
  apply (clarsimp simp: table_cap_ref_def
                        vs_lookup_pages_eq_at[symmetric, THEN fun_cong]
                        vs_lookup_pages_eq_ap[symmetric, THEN fun_cong]
                 split: cap.splits arch_cap.splits option.splits)
  apply (rule iffI[rotated, OF vs_lookup_pages_vs_lookupI], assumption)
  apply (simp add: valid_cap_def)
  apply (erule vs_lookup_vs_lookup_pagesI', clarsimp+)
  done


lemma empty_slot_invs:
  "\<lbrace>\<lambda>s. invs s \<and> cte_wp_at (replaceable s sl cap.NullCap) sl s \<and>
        emptyable sl s \<and>
        (\<forall>irq. irqopt = Some irq \<longrightarrow>
            cap.IRQHandlerCap irq \<notin>
            ran ((caps_of_state s) (sl \<mapsto> cap.NullCap)))\<rbrace>
     empty_slot sl irqopt
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: empty_slot_def set_cdt_def bind_assoc cong: if_cong)
  apply (wp opt_deleted_irq_handler_invs)
        apply (simp add: invs_def valid_state_def valid_mdb_def2)
        apply (wp replace_cap_valid_pspace set_cap_caps_of_state2
                  replace_cap_ifunsafe get_cap_wp
                  set_cap_idle valid_irq_node_typ set_cap_typ_at
                  set_cap_irq_handlers set_cap_valid_arch_caps | simp add: trans_state_update[symmetric] del: trans_state_update fun_upd_apply split del: split_if )+
  apply (clarsimp simp: is_final_cap'_def2 simp del: fun_upd_apply)
  apply (clarsimp simp: conj_ac invs_def valid_state_def valid_mdb_def2)
  apply (subgoal_tac "mdb_empty_abs s")
   prefer 2
   apply (rule mdb_empty_abs.intro)
   apply (rule vmdb_abs.intro)
   apply (simp add: valid_mdb_def swp_def cte_wp_at_caps_of_state conj_ac)
  apply (clarsimp simp: untyped_mdb_def mdb_empty_abs.descendants mdb_empty_abs.no_mloop_n
                        valid_pspace_def cap_range_def)
  apply (clarsimp simp: untyped_inc_def mdb_empty_abs.descendants mdb_empty_abs.no_mloop_n)
  apply (simp add: ut_revocable_def cur_tcb_def valid_irq_node_def
                   no_cap_to_obj_with_diff_ref_Null)
  apply (rule conjI)
   apply (clarsimp simp: cte_wp_at_cte_at)
  apply (rule conjI)
   apply (clarsimp simp: irq_revocable_def)
  apply (rule conjI)
   apply (clarsimp simp: reply_master_revocable_def)
  apply (thin_tac "\<forall>irq. irqopt = Some irq \<longrightarrow> ?P irq")
  apply (rule conjI)
   apply (clarsimp simp: valid_machine_state_def)
  apply (rule conjI)
   apply (clarsimp simp:descendants_inc_def mdb_empty_abs.descendants)
  apply (rule conjI)
   apply (clarsimp simp: reply_mdb_def)
   apply (rule conjI)
    apply (unfold reply_caps_mdb_def)[1]
    apply (rule allEI, assumption)
    apply (fold reply_caps_mdb_def)[1]
    apply (case_tac "sl = ptr", simp)
    apply (simp add: fun_upd_def split del: split_if del: split_paired_Ex)
    apply (erule allEI, rule impI, erule(1) impE)
    apply (erule exEI)
    apply (simp, rule ccontr)
    apply (erule(5) emptyable_no_reply_cap)
    apply simp
   apply (unfold reply_masters_mdb_def)[1]
   apply (elim allEI)
   apply (clarsimp simp: mdb_empty_abs.descendants)
  apply (rule conjI)
   apply (simp add: valid_ioc_def)
  apply (rule conjI)
   apply (clarsimp simp: tcb_cap_valid_def
                  dest!: emptyable_valid_NullCapD)
  apply (rule conjI)
   apply (clarsimp simp: mdb_cte_at_def cte_wp_at_caps_of_state)
   apply (cases sl)
   apply (rule conjI, clarsimp)
    apply (rule conjI)
     apply clarsimp
     apply (subgoal_tac "cdt s \<Turnstile> (ab,bb) \<rightarrow> (ab,bb)")
      apply (simp add: no_mloop_def)
     apply (rule r_into_trancl)
     apply (simp add: cdt_parent_of_def)
    apply fastforce
   apply fastforce
  apply (clarsimp simp: cte_wp_at_caps_of_state replaceable_def
                        vs_cap_ref_simps table_cap_ref_simps
                   del: allI)
  apply (case_tac "is_final_cap' cap s")
   apply auto[1]
  apply (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state)
  done

crunch cte_wp_at[wp]: deleted_irq_handler "cte_wp_at P p"

lemma empty_slot_deletes[wp]:
  "\<lbrace>\<top>\<rbrace> empty_slot sl opt \<lbrace>\<lambda>rv. cte_wp_at (\<lambda>c. c = cap.NullCap) sl\<rbrace>"
  apply (simp add: empty_slot_def)
  apply (wp set_cap_sets get_cap_wp opt_return_pres_lift|simp)+
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done


lemma get_cap_sp:
  "\<lbrace>P\<rbrace> get_cap p \<lbrace>\<lambda>rv. P and cte_wp_at (\<lambda>c. c = rv) p\<rbrace>"
  apply (wp get_cap_cte_wp_at)
  apply simp
  done


crunch caps_of_state[wp]: deleted_irq_handler "\<lambda>s. P (caps_of_state s)"


lemma empty_slot_final_cap_at:
  "\<lbrace>(\<lambda>s. cte_wp_at (\<lambda>c. obj_refs c \<noteq> {} \<and> is_final_cap' c s) p s) and K (p \<noteq> p')\<rbrace>
      empty_slot p' opt \<lbrace>\<lambda>rv s. cte_wp_at (\<lambda>c. is_final_cap' c s) p s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: empty_slot_def final_cap_at_eq cte_wp_at_conj)
  apply (simp add: cte_wp_at_caps_of_state)
  apply (wp opt_return_pres_lift | simp split del: split_if)+
  apply (rule hoare_strengthen_post [OF get_cap_sp])
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  done


crunch st_tcb_at[wp]: empty_slot "st_tcb_at P t"


declare if_cong[cong]

lemma set_cap_revokable_update:
  "((),s') \<in> fst (set_cap c p s) \<Longrightarrow>
  ((),is_original_cap_update f s') \<in> fst (set_cap c p (is_original_cap_update f s))"
  apply (cases p)
  apply (clarsimp simp add: set_cap_def in_monad get_object_def)
  apply (case_tac y)
  apply (auto simp add: in_monad set_object_def split: split_if_asm)
  done


lemma set_cap_cdt_update:
  "((),s') \<in> fst (set_cap c p s) \<Longrightarrow> ((),cdt_update f s') \<in> fst (set_cap c p (cdt_update f s))"
  apply (cases p)
  apply (clarsimp simp add: set_cap_def in_monad get_object_def)
  apply (case_tac y)
  apply (auto simp add: in_monad set_object_def split: split_if_asm)
  done


definition
  fst_cte_ptrs :: "cap \<Rightarrow> cslot_ptr set"
where
 "fst_cte_ptrs cap \<equiv> (case cap of
    cap.CNodeCap r bits guard \<Rightarrow> {(r, replicate bits False)}
  | cap.ThreadCap r           \<Rightarrow> {(r, tcb_cnode_index 0)}
  | cap.Zombie r zb n         \<Rightarrow> {(r, replicate (zombie_cte_bits zb) False)}
  | _                         \<Rightarrow> {})"


lemma tcb_cap_cases_lt:
  "n < 5 \<Longrightarrow> tcb_cap_cases (nat_to_cref 3 n) \<noteq> None"
  unfolding tcb_cnode_index_def2[symmetric]
  by (simp add: tcb_cap_cases_def
         | erule less_handy_casesE)+


lemma nat_to_cref_unat_of_bl':
  "\<lbrakk> length xs < 32; n = length xs \<rbrakk> \<Longrightarrow>
   nat_to_cref n (unat (of_bl xs :: word32)) = xs"
  apply (simp add: nat_to_cref_def word_bits_def)
  apply (rule nth_equalityI)
   apply simp
  apply clarsimp
  apply (subst to_bl_nth)
   apply (simp add: word_size)
  apply (simp add: word_size)
  apply (simp add: test_bit_of_bl rev_nth)
  apply fastforce
  done


lemmas nat_to_cref_unat_of_bl = nat_to_cref_unat_of_bl' [OF _ refl]


lemma dom_tcb_cap_cases_lt:
  "dom tcb_cap_cases = {xs. length xs = 3 \<and> unat (of_bl xs :: word32) < 5}"
  apply (rule set_eqI, rule iffI)
   apply clarsimp
   apply (simp add: tcb_cap_cases_def tcb_cnode_index_def to_bl_1 split: split_if_asm)
  apply clarsimp
  apply (frule tcb_cap_cases_lt)
  apply (clarsimp simp: nat_to_cref_unat_of_bl')
  done


lemma cte_refs_CNode_Zombie_helper[simp]:
  "{xs. length xs = n \<and> unat (of_bl xs :: word32) < 2 ^ n}
     = {xs. length xs = n}"
  apply safe
  apply (rule unat_of_bl_length)
  done


lemma empty_slot_caps_of_state:
  "\<lbrace>\<lambda>s. P ((caps_of_state s) (slot \<mapsto> cap.NullCap))\<rbrace>
     empty_slot slot opt
   \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (simp add: empty_slot_def set_cdt_def)
  apply (wp get_cap_wp opt_return_pres_lift | simp)+
  apply (clarsimp simp: cte_wp_at_caps_of_state
                        fun_upd_def[symmetric]
                        fun_upd_idem)
  done

crunch caps_of_state[wp]: ep_cancel_all "\<lambda>s. P (caps_of_state s)"
  (wp: mapM_x_wp' crunch_wps)

crunch caps_of_state[wp]: aep_cancel_all "\<lambda>s. P (caps_of_state s)"
  (wp: mapM_x_wp' crunch_wps)

lemma fast_finalise_caps_of_state[wp]:
"\<lbrace>\<lambda>s. P (caps_of_state s)\<rbrace> fast_finalise a f \<lbrace>\<lambda>_ s. P (caps_of_state s)\<rbrace>"
  apply (case_tac a,simp_all)
  apply (wp | clarsimp)+
  done


(* why the following does not work?
  crunch caps_of_state[wp]: fast_finalise "\<lambda>s. P (caps_of_state s)"
  (wp: mapM_x_wp' crunch_wps)
*)

lemma cap_delete_one_caps_of_state:
  "\<lbrace>\<lambda>s. cte_wp_at can_fast_finalise p s
           \<longrightarrow> P ((caps_of_state s) (p \<mapsto> cap.NullCap))\<rbrace>
     cap_delete_one p
   \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def
                   is_final_cap_def)
  apply (rule hoare_seq_ext [OF _ get_cap_sp])
  apply (case_tac "can_fast_finalise cap")
   apply (wp empty_slot_caps_of_state get_cap_wp)
   apply (clarsimp simp: cte_wp_at_caps_of_state
                         fun_upd_def[symmetric]
                         fun_upd_idem)
  apply (simp add: fast_finalise_def2)
  apply wp
  apply (clarsimp simp: can_fast_finalise_def)
  done


crunch caps_of_state[wp]: blocked_ipc_cancel, async_ipc_cancel
    "\<lambda>s. P (caps_of_state s)"


lemma ipc_cancel_caps_of_state:
  "\<lbrace>\<lambda>s. (\<forall>p. cte_wp_at can_fast_finalise p s
           \<longrightarrow> P ((caps_of_state s) (p \<mapsto> cap.NullCap)))
           \<and> P (caps_of_state s)\<rbrace>
     ipc_cancel t
   \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (simp add: ipc_cancel_def reply_ipc_cancel_def
             cong: Structures_A.thread_state.case_cong)
  apply (wp cap_delete_one_caps_of_state select_wp
       | wpc)+
     apply (rule_tac Q="\<lambda>_ s. (\<forall>p. cte_wp_at can_fast_finalise p s
                                \<longrightarrow> P ((caps_of_state s) (p \<mapsto> cap.NullCap)))
                                \<and> P (caps_of_state s)"
                  in hoare_post_imp)
      apply (clarsimp simp: fun_upd_def[symmetric] split_paired_Ball)
     apply (simp add: cte_wp_at_caps_of_state)
     apply (wp hoare_vcg_all_lift hoare_convert_imp
               thread_set_caps_of_state_trivial
          | clarsimp simp: tcb_cap_cases_def)+
  apply (rule hoare_strengthen_post [OF gts_sp])
  apply (clarsimp simp: fun_upd_def[symmetric] cte_wp_at_caps_of_state)
  done


lemma suspend_caps_of_state:
  "\<lbrace>\<lambda>s. (\<forall>p. cte_wp_at can_fast_finalise p s
           \<longrightarrow> P ((caps_of_state s) (p \<mapsto> cap.NullCap)))
           \<and> P (caps_of_state s)\<rbrace>
     suspend t
   \<lbrace>\<lambda>rv s. P (caps_of_state s)\<rbrace>"
  apply (simp add: suspend_def)
  apply (wp, simp, wp ipc_cancel_caps_of_state)
  apply (simp add: fun_upd_def[symmetric])
  done


lemma suspend_final_cap:
  "\<lbrace>\<lambda>s. is_final_cap' cap s \<and> \<not> can_fast_finalise cap
            \<and> cte_wp_at (op = cap) sl s\<rbrace>
     suspend t
   \<lbrace>\<lambda>rv s. is_final_cap' cap s\<rbrace>"
  apply (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state
              del: split_paired_Ex split_paired_All)
  apply (wp suspend_caps_of_state)
  apply (clarsimp simp del: split_paired_Ex split_paired_All)
  apply (rule_tac x=sl in exI)
  apply (intro allI impI conjI)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (subgoal_tac "(aa, ba) = sl")
   apply clarsimp
  apply (frule_tac x="(aa, ba)" in spec)
  apply (drule_tac x=sl in spec)
  apply clarsimp
  done


lemma cap_delete_one_final_cap:
  "\<lbrace>\<lambda>s. cte_wp_at (op = cap) slot s
        \<and> \<not> can_fast_finalise cap
        \<and> is_final_cap' cap s\<rbrace>
     cap_delete_one slot'
   \<lbrace>\<lambda>rv s. is_final_cap' cap s\<rbrace>"
  apply (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state
              del: split_paired_All split_paired_Ex)
  apply (wp cap_delete_one_caps_of_state)
  apply (clarsimp simp: cte_wp_at_caps_of_state
              simp del: split_paired_Ex split_paired_All)
  apply (subgoal_tac "slot = (a, b)")
   apply (rule_tac x=slot in exI)
   apply clarsimp
  apply (frule_tac x=slot in spec)
  apply (drule_tac x="(a, b)" in spec)
  apply clarsimp
  done


lemma deleting_irq_handler_final:
  "\<lbrace>is_final_cap' cap and cte_wp_at (op = cap) slot
          and K (\<not> can_fast_finalise cap)\<rbrace>
      deleting_irq_handler irq
   \<lbrace>\<lambda>rv. is_final_cap' cap\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: deleting_irq_handler_def)
  apply (wp cap_delete_one_final_cap[where slot=slot])
  apply simp
  done


lemma finalise_cap_cases1:
  "\<lbrace>\<lambda>s. final \<longrightarrow> is_final_cap' cap s
         \<and> cte_wp_at (op = cap) slot s\<rbrace>
     finalise_cap cap final
   \<lbrace>\<lambda>rv s. fst rv = cap.NullCap
         \<and> snd rv = (if final then cap_irq_opt cap else None)
         \<and> (snd rv \<noteq> None \<longrightarrow> is_final_cap' cap s)
     \<or>
       is_zombie (fst rv) \<and> is_final_cap' cap s
        \<and> snd rv = None
        \<and> appropriate_cte_cap (fst rv) = appropriate_cte_cap cap
        \<and> cte_refs (fst rv) = cte_refs cap
        \<and> obj_refs (fst rv) = obj_refs cap
        \<and> obj_size (fst rv) = obj_size cap
        \<and> cap_irqs (fst rv) = cap_irqs cap
        \<and> fst_cte_ptrs (fst rv) = fst_cte_ptrs cap
        \<and> vs_cap_ref cap = None\<rbrace>"
  apply (cases cap, simp_all split del: split_if)
            apply (wp suspend_final_cap[where sl=slot]
                      deleting_irq_handler_final[where slot=slot]
                      | simp add: o_def is_cap_simps fst_cte_ptrs_def
                                  dom_tcb_cap_cases_lt tcb_cnode_index_def
                                  can_fast_finalise_def
                                  appropriate_cte_cap_def
                                  vs_cap_ref_def
                      | intro impI TrueI ext conjI)+
  apply (simp add: arch_finalise_cap_def)
  apply (rule hoare_pre)
   apply (wp | wpc | simp only: simp_thms)+
  done


lemma finalise_cap_cases:
  "\<lbrace>\<lambda>s. final \<longrightarrow> is_final_cap' cap s
         \<and> cte_wp_at (op = cap) slot s\<rbrace>
     finalise_cap cap final
   \<lbrace>\<lambda>rv s. fst rv = cap.NullCap
            \<and> snd rv = (if final then cap_irq_opt cap else None)
            \<and> (snd rv \<noteq> None \<longrightarrow> is_final_cap' cap s)
     \<or>
       is_zombie (fst rv) \<and> is_final_cap' cap s
        \<and> is_final_cap' (fst rv) s
        \<and> snd rv = None
        \<and> appropriate_cte_cap (fst rv) = appropriate_cte_cap cap
        \<and> cte_refs (fst rv) = cte_refs cap
        \<and> obj_refs (fst rv) = obj_refs cap
        \<and> obj_size (fst rv) = obj_size cap
        \<and> cap_irqs (fst rv) = cap_irqs cap
        \<and> fst_cte_ptrs (fst rv) = fst_cte_ptrs cap
        \<and> vs_cap_ref cap = None\<rbrace>"
  apply (rule hoare_strengthen_post,
         rule finalise_cap_cases1)
  apply (erule disjEI)
   apply (auto simp: is_final_cap'_def)
  done


lemma is_final_cap'_objrefsE:
  "\<lbrakk> is_final_cap' cap s; obj_refs cap = obj_refs cap';
       cap_irqs cap = cap_irqs cap' \<rbrakk>
     \<Longrightarrow> is_final_cap' cap' s"
  by (simp add: is_final_cap'_def)

crunch typ_at[wp]: deleting_irq_handler "\<lambda>s. P (typ_at T p s)"
  (wp:crunch_wps simp:crunch_simps unless_def assertE_def)

crunch typ_at[wp]: arch_finalise_cap "\<lambda>s. P (typ_at T p s)"
  (wp: crunch_wps simp: crunch_simps unless_def assertE_def
        ignore: maskInterrupt )

crunch typ_at[wp]: finalise_cap "\<lambda>s. P (typ_at T p s)"

lemma valid_cap_Null_ext:
  "valid_cap cap.NullCap = \<top>"
  by (rule ext) simp

lemma finalise_cap_new_valid_cap[wp]:
  "\<lbrace>valid_cap cap\<rbrace> finalise_cap cap x \<lbrace>\<lambda>rv. valid_cap (fst rv)\<rbrace>"
  apply (cases cap, simp_all)
            apply (wp suspend_valid_cap
                     | simp add: o_def valid_cap_def cap_aligned_def
                                 valid_cap_Null_ext
                            del: hoare_post_taut
           (* removing hoare_post_taut so wp doesn't include
              completely random irrelevant wp lemmas in the proof *)
                           split del: if_splits
                     | clarsimp | rule conjI)+
  apply (simp add: arch_finalise_cap_def)
  apply (rule hoare_pre)
  apply (wp|simp add: o_def valid_cap_def cap_aligned_def
                 del: hoare_post_taut
                 split del: if_splits|clarsimp|wpc)+
  done

lemma invs_arm_asid_table_unmap:
  "invs s \<and> is_aligned base asid_low_bits \<and> base \<le> mask asid_bits
       \<and> (\<forall>x\<in>set [0.e.2 ^ asid_low_bits - 1]. arm_asid_map (arch_state s) (base + x) = None)
       \<and> tab = arm_asid_table (arch_state s)
     \<longrightarrow> invs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := tab(asid_high_bits_of base := None)\<rparr>\<rparr>)"
  apply (clarsimp simp: invs_def valid_state_def valid_arch_caps_def)
  apply (strengthen valid_asid_map_unmap valid_arch_objs_unmap_strg
                    valid_vs_lookup_unmap_strg valid_arch_state_unmap_strg)
  apply (simp add: valid_irq_node_def valid_kernel_mappings_def
                   valid_global_objs_arch_update)
  apply (simp add: valid_table_caps_def valid_machine_state_def)
  done

lemma delete_asid_pool_invs[wp]:
  "\<lbrace>invs and K (base \<le> mask asid_bits)\<rbrace>
     delete_asid_pool base pptr
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: delete_asid_pool_def)
  apply wp
  apply (strengthen invs_arm_asid_table_unmap)
  apply simp
  apply (rule hoare_vcg_conj_lift,
           (rule mapM_invalidate[where ptr=pptr])?,
           ((wp mapM_wp' | simp add: if_apply_def2)+)[1])+
    apply wp
  apply (clarsimp simp: is_aligned_mask[symmetric])
  apply (rule conjI)
   apply (rule vs_lookupI)
    apply (erule vs_asid_refsI)
   apply simp
  apply clarsimp
  done

lemma delete_asid_invs[wp]:
  "\<lbrace>invs and K (asid \<le> mask asid_bits)\<rbrace>
     delete_asid asid pd
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: delete_asid_def cong: option.case_cong)
  apply (wp set_asid_pool_invs_unmap | wpc)+
     apply (simp add: invalidate_asid_entry_def invalidate_asid_def invalidate_hw_asid_entry_def)
     apply (wp load_hw_asid_wp)
    apply (simp add: flush_space_def)
    apply (wp load_hw_asid_wp|wpc)+
  apply (clarsimp simp del: fun_upd_apply)
  apply (subgoal_tac "valid_asid_table (arm_asid_table (arch_state s)) s")
   prefer 2
   apply fastforce
  apply (clarsimp simp: valid_asid_table_def)
  apply (rule conjI)
   apply clarsimp
   apply (subgoal_tac "asid_high_bits_of asid = asid_high_bits_of asida")
    prefer 2
    apply (fastforce elim!: inj_onD)
   apply (drule asid_low_high_bits', simp)
     apply (simp add: mask_def)
    apply (simp add: mask_def)
   apply blast
  apply clarsimp
  apply (subgoal_tac "asid_high_bits_of asid = asid_high_bits_of asida")
   prefer 2
   apply (fastforce elim!: inj_onD)
  apply (drule asid_low_high_bits', simp)
    apply (simp add: mask_def)
   apply (simp add: mask_def)
  apply blast
  done


lemma arch_finalise_cap_invs[wp]:
  "\<lbrace>invs and valid_cap (cap.ArchObjectCap cap)\<rbrace>
     arch_finalise_cap cap final
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: arch_finalise_cap_def)
  apply (rule hoare_pre)
   apply (wp unmap_page_invs | wpc)+
  apply (clarsimp simp: valid_cap_def cap_aligned_def)
  apply (auto simp: mask_def vmsz_aligned_def)
  done

crunch invs[wp]: fast_finalise "invs"

crunch invs: page_table_mapped "invs"

lemma cnode_at_unlive[elim!]:
  "s \<turnstile> cap.CNodeCap ptr bits gd \<Longrightarrow> obj_at (\<lambda>ko. \<not> live ko) ptr s"
  by (clarsimp simp: valid_cap_def is_cap_table
              elim!: obj_at_weakenE)


lemma set_thread_state_final_cap[wp]:
  "\<lbrace>is_final_cap' cap\<rbrace> set_thread_state st t \<lbrace>\<lambda>rv. is_final_cap' cap\<rbrace>"
  by (simp add: is_final_cap'_def2 cte_wp_at_caps_of_state, wp)


lemma tcb_cap_valid_imp':
  "((\<forall>(get, set, restr)\<in>ran tcb_cap_cases.
          \<forall>ptr st. restr ptr st cap \<longrightarrow> restr ptr st newcap)
            \<and> (\<forall>ptr. valid_ipc_buffer_cap cap ptr
                       \<longrightarrow> valid_ipc_buffer_cap newcap ptr))
     \<longrightarrow> (tcb_cap_valid cap sl s \<longrightarrow> tcb_cap_valid newcap sl s)"
  by (fastforce simp: tcb_cap_valid_def elim!: st_tcb_weakenE
              split: option.split)


lemma tcb_cap_valid_imp_NullCap:
  "(\<not> is_master_reply_cap cap)
     \<longrightarrow> (tcb_cap_valid cap sl s \<longrightarrow> tcb_cap_valid cap.NullCap sl s)"
  apply (strengthen tcb_cap_valid_imp')
  apply (clarsimp simp: ran_tcb_cap_cases valid_ipc_buffer_cap_def
                 split: Structures_A.thread_state.split_asm)
  done


lemma delete_asid_pool_unmapped[wp]:
  "\<lbrace>\<top>\<rbrace>
     delete_asid_pool asid poolptr
   \<lbrace>\<lambda>rv s. \<not> ([VSRef (ucast (asid_high_bits_of asid)) None] \<rhd> poolptr) s\<rbrace>"
  apply (simp add: delete_asid_pool_def)
  apply wp
    apply (rule hoare_strengthen_post [where Q="\<lambda>_. \<top>"])
     apply wp
    defer
    apply wp
   apply (clarsimp simp: vs_lookup_def vs_asid_refs_def
                  dest!: graph_ofD)
   apply (erule rtranclE)
    apply (simp add: up_ucast_inj_eq)
   apply (drule vs_lookup1D)
   apply clarsimp
   apply (clarsimp simp: vs_refs_def
                  split: Structures_A.kernel_object.split_asm arch_kernel_obj.splits
                  dest!: graph_ofD)
  apply (clarsimp simp: vs_lookup_def vs_asid_refs_def
                 dest!: graph_ofD
                 split: split_if_asm)
  apply (erule rtranclE)
   apply (simp add: up_ucast_inj_eq)
  apply (drule vs_lookup1D)
  apply clarsimp
  apply (clarsimp simp: vs_refs_def
                 split: Structures_A.kernel_object.split_asm arch_kernel_obj.splits
                 dest!: graph_ofD)
 done


lemma set_asid_pool_unmap:
  "\<lbrace>[VSRef highbits None] \<rhd> poolptr\<rbrace>
     set_asid_pool poolptr (pool(lowbits := None))
   \<lbrace>\<lambda>rv s. \<not> ([VSRef (ucast lowbits) (Some AASIDPool),
                   VSRef highbits None] \<rhd> x) s\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: vs_lookup_def vs_asid_refs_def
                 dest!: graph_ofD vs_lookup1_rtrancl_iterations)
  apply (clarsimp simp: vs_lookup1_def obj_at_def up_ucast_inj_eq)
  apply (fastforce simp: vs_refs_def up_ucast_inj_eq
                 dest!: graph_ofD)
  done


lemma delete_asid_unmapped[wp]:
  "\<lbrace>\<top>\<rbrace>
      delete_asid asid pd
   \<lbrace>\<lambda>rv s.  \<not> ([VSRef (asid && mask asid_low_bits) (Some AASIDPool),
                VSRef (ucast (asid_high_bits_of asid)) None]  \<rhd> pd) s\<rbrace>"
  apply (simp add: delete_asid_def
                   mask_asid_low_bits_ucast_ucast
             cong: option.case_cong)
  apply (wp set_asid_pool_unmap load_hw_asid_wp | wpc)+
  apply simp
  apply (intro allI conjI impI)
    apply (fastforce simp: vs_lookup_def vs_asid_refs_def up_ucast_inj_eq
                   dest!: graph_ofD vs_lookup1_rtrancl_iterations
                          vs_lookup1D)
   apply (erule vs_lookup_atI)
  apply (clarsimp simp: vs_lookup_def vs_asid_refs_def up_ucast_inj_eq
                 dest!: graph_ofD vs_lookup1_rtrancl_iterations
                        vs_lookup1D)
  apply (clarsimp simp: obj_at_def vs_refs_def up_ucast_inj_eq
                 dest!: graph_ofD)
  done


lemma a_type_arch_live:
  "a_type ko = AArch tp \<Longrightarrow> \<not> live ko"
  by (simp add: a_type_def
         split: Structures_A.kernel_object.split_asm)

lemma obj_at_not_live_valid_arch_cap_strg:
  "(s \<turnstile> cap.ArchObjectCap cap \<and> aobj_ref cap = Some r)
        \<longrightarrow> obj_at (\<lambda>ko. \<not> live ko) r s"
  by (clarsimp simp: valid_cap_def obj_at_def
                     a_type_arch_live
              split: arch_cap.split_asm)


lemma set_pt_tcb_at:
  "\<lbrace>\<lambda>s. P (ko_at (TCB tcb) t s)\<rbrace> set_pt a b \<lbrace>\<lambda>_ s. P (ko_at (TCB tcb) t s)\<rbrace>"
  by (clarsimp simp: simpler_set_pt_def valid_def obj_at_def)


lemma set_pd_tcb_at:
  "\<lbrace>\<lambda>s. P (ko_at (TCB tcb) t s)\<rbrace> set_pd a b \<lbrace>\<lambda>_ s. P (ko_at (TCB tcb) t s)\<rbrace>"
  by (clarsimp simp: simpler_set_pd_def valid_def obj_at_def)


crunch tcb_at: unmap_page "\<lambda>s. P (ko_at (TCB tcb) t s)"
  (simp: crunch_simps wp: crunch_wps set_pt_tcb_at set_pd_tcb_at)


lemma st_tcb_at_def2:
  "st_tcb_at P t \<equiv> \<lambda>s. \<exists>tcb. ko_at (TCB tcb) t s \<and> P (tcb_state tcb)"
  by (rule eq_reflection, rule ext) (fastforce simp: st_tcb_at_def obj_at_def)


lemma unmap_page_tcb_cap_valid:
 "\<lbrace>\<lambda>s. tcb_cap_valid cap r s\<rbrace>
  unmap_page sz asid vaddr pptr
  \<lbrace>\<lambda>rv s. tcb_cap_valid cap r s\<rbrace>"
  apply (rule tcb_cap_valid_typ_st)
  apply wp
  apply (simp add: st_tcb_at_def2)
  apply (wp unmap_page_tcb_at hoare_vcg_ex_lift hoare_vcg_all_lift)
  done


lemma imp_and_strg: "Q \<and> C \<longrightarrow> (A \<longrightarrow> Q \<and> C) \<and> C" by blast

lemma and_not_not_or_imp: "(~ A & ~ B | C) = ((A | B) \<longrightarrow> C)" by blast

lemma arch_finalise_cap_replaceable[wp]:
  notes strg = tcb_cap_valid_imp_NullCap
               obj_at_not_live_valid_arch_cap_strg[where cap=cap]
  notes simps = replaceable_def and_not_not_or_imp
                vs_lookup_pages_eq_at[THEN fun_cong, symmetric]
                vs_lookup_pages_eq_ap[THEN fun_cong, symmetric]
                is_cap_simps vs_cap_ref_def
                no_cap_to_obj_with_diff_ref_Null o_def
  notes wps = hoare_drop_imp[where R="%_. is_final_cap' cap", standard]
              unmap_page_table_unmapped3 valid_cap_typ
  shows
    "\<lbrace>\<lambda>s. s \<turnstile> cap.ArchObjectCap cap \<and>
          x = is_final_cap' (cap.ArchObjectCap cap) s \<and>
          pspace_aligned s \<and> valid_arch_objs s \<and> valid_objs s \<and>
          valid_asid_table (arm_asid_table (arch_state s)) s\<rbrace>
     arch_finalise_cap cap x
   \<lbrace>\<lambda>rv s. replaceable s sl rv (cap.ArchObjectCap cap)\<rbrace>"
  apply (simp add: arch_finalise_cap_def)
  apply (rule hoare_pre)
   apply (simp add: simps split: option.splits vmpage_size.splits)
   apply (wp wps
          | strengthen strg
          | simp add: simps
               split: option.splits vmpage_size.splits
          | intro impI conjI allI
          | wpc)
       apply ((wp wps
              | strengthen strg
              | simp add: simps reachable_pg_cap_def
                   split: option.splits vmpage_size.splits
              | intro impI conjI allI
              | wpc)+)[2]
     apply (wpc | wp)+
     apply (simp add: simps
               split: option.splits vmpage_size.splits)
     apply (strengthen strg)+
     apply (simp add: reachable_pg_cap_def is_master_reply_cap_def
                      is_pg_cap_def vs_cap_ref_simps)
     apply (strengthen imp_and_strg)
     apply (intro impI conjI)
        apply ((wp unmap_page_tcb_cap_valid unmap_page_page_unmapped
                   unmap_page_section_unmapped | simp)+)[4]
    apply (wp wps
           | strengthen strg imp_and_strg tcb_cap_valid_imp_NullCap
           | simp add: simps is_master_reply_cap_def reachable_pg_cap_def
           | wpc)+
  apply (auto simp: valid_cap_def obj_at_def simps is_master_reply_cap_def
             elim!: tcb_cap_valid_imp_NullCap[rule_format, rotated]
             split: cap.splits arch_cap.splits vmpage_size.splits)[1]
  done

lemmas tcb_cap_valid_imp = mp [OF mp [OF tcb_cap_valid_imp'], rotated]

crunch irq_node[wp]: ep_cancel_all "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps simp: crunch_simps unless_def)

crunch irq_node[wp]: aep_cancel_all "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps simp: crunch_simps unless_def)

lemma fast_finalise_irq_node[wp]:
"\<lbrace>\<lambda>s. P (interrupt_irq_node s)\<rbrace> fast_finalise a f \<lbrace>\<lambda>_ s. P (interrupt_irq_node s)\<rbrace>"
  apply (case_tac a,simp_all)
  apply (wp ep_cancel_all_irq_node | clarsimp)+
  done

crunch irq_node[wp]: cap_delete_one "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps simp: crunch_simps unless_def)


lemma deleting_irq_handler_empty:
  "\<lbrace>\<top>\<rbrace>
     deleting_irq_handler irq
   \<lbrace>\<lambda>rv s. cte_wp_at (op = cap.NullCap) (interrupt_irq_node s irq, []) s\<rbrace>"
  apply (simp add: deleting_irq_handler_def cte_wp_at_caps_of_state
                   get_irq_slot_def)
  apply (wp hoare_use_eq_irq_node [OF cap_delete_one_irq_node cap_delete_one_caps_of_state])
  apply clarsimp
  done


lemmas obj_irq_refs_empty2 = trans [OF eq_commute obj_irq_refs_empty]


lemma cnode_zombie_thread_appropriate[simp]:
  "appropriate_cte_cap cp (cap.CNodeCap a b c)"
  "appropriate_cte_cap cp (cap.ThreadCap f)"
  "appropriate_cte_cap cp (cap.Zombie h i j)"
  by (simp add: appropriate_cte_cap_def split: cap.splits)+


lemma deleting_irq_handler_slot_not_irq_node:
  "\<lbrace>if_unsafe_then_cap and valid_global_refs
           and cte_wp_at (\<lambda>cp. cap_irqs cp \<noteq> {}) sl\<rbrace>
     deleting_irq_handler irq
   \<lbrace>\<lambda>rv s. (interrupt_irq_node s irq, []) \<noteq> sl\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply wp
  apply clarsimp
  apply (drule(1) if_unsafe_then_capD)
   apply clarsimp
  apply (clarsimp simp: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply (drule cte_refs_obj_refs_elem)
  apply (erule disjE)
   apply simp
   apply (drule(1) valid_global_refsD[OF _ caps_of_state_cteD])
    prefer 2
    apply (erule notE, simp add: cap_range_def, erule disjI2)
   apply (simp add: global_refs_def)
  apply (clarsimp simp: appropriate_cte_cap_def split: cap.split_asm)
  done


lemma no_cap_to_obj_with_diff_ref_finalI:
  "\<lbrakk> cte_wp_at (op = cap) p s; is_final_cap' cap s;
            obj_refs cap' = obj_refs cap \<rbrakk>
      \<Longrightarrow> no_cap_to_obj_with_diff_ref cap' {p} s"
  apply (case_tac "obj_refs cap = {}")
   apply (case_tac "cap_irqs cap = {}")
    apply (simp add: is_final_cap'_def)
   apply (case_tac cap, simp_all)
   apply (clarsimp simp add: no_cap_to_obj_with_diff_ref_def
                             cte_wp_at_caps_of_state
                             vs_cap_ref_def
                      dest!: obj_ref_none_no_asid[rule_format])
  apply (clarsimp simp: no_cap_to_obj_with_diff_ref_def
                        is_final_cap'_def2
              simp del: split_paired_All)
  apply (frule_tac x=p in spec)
  apply (drule_tac x="(a, b)" in spec)
  apply (clarsimp simp: cte_wp_at_caps_of_state
                        obj_irq_refs_Int)
  done


lemma suspend_no_cap_to_obj_ref[wp]:
  "\<lbrace>no_cap_to_obj_with_diff_ref cap S\<rbrace>
     suspend t
   \<lbrace>\<lambda>rv. no_cap_to_obj_with_diff_ref cap S\<rbrace>"
  apply (simp add: no_cap_to_obj_with_diff_ref_def
                   cte_wp_at_caps_of_state)
  apply (wp suspend_caps_of_state)
  apply (clarsimp simp: table_cap_ref_simps
                 dest!: obj_ref_none_no_asid[rule_format])
  done


lemma finalise_cap_replaceable:
  "\<lbrace>\<lambda>s. s \<turnstile> cap \<and> x = is_final_cap' cap s
        \<and> cte_wp_at (op = cap) sl s
        \<and> (cap_irqs cap \<noteq> {} \<longrightarrow> if_unsafe_then_cap s \<and> valid_global_refs s)
        \<and> (is_arch_cap cap \<longrightarrow> pspace_aligned s \<and>
                               valid_arch_objs s \<and> valid_objs s \<and>
                               valid_arch_state s)\<rbrace>
     finalise_cap cap x
   \<lbrace>\<lambda>rv s. replaceable s sl (fst rv) cap\<rbrace>"
  apply (cases cap, simp_all add: replaceable_def reachable_pg_cap_def
                       split del: split_if)
            prefer 10
            (* TS: this seems to be necessary for deleting_irq_handler,
                   kind of nasty, not sure how to sidestep *)
            apply (rule hoare_pre)
            apply (wp suspend_unlive[unfolded o_def]
                      suspend_final_cap[where sl=sl]
                   | clarsimp simp: o_def dom_tcb_cap_cases_lt
                                     ran_tcb_cap_cases is_cap_simps
                                     cap_range_def
                                     can_fast_finalise_def
                                     obj_irq_refs_subset
                                     vs_cap_ref_def
                                     is_pt_cap_def is_pd_cap_def
                                     valid_ipc_buffer_cap_def
                              dest!: tcb_cap_valid_NullCapD
                              split: Structures_A.thread_state.split_asm
                   | simp cong: conj_cong
                   | simp cong: rev_conj_cong add: no_cap_to_obj_with_diff_ref_Null
                   | strengthen tcb_cap_valid_imp_NullCap tcb_cap_valid_imp'
                   | rule conjI
                   | erule cte_wp_at_weakenE
                   | erule(1) no_cap_to_obj_with_diff_ref_finalI
                   | (rule hoare_drop_imps,
                       rule ep_cancel_all_unlive[unfolded o_def]
                           aep_cancel_all_unlive[unfolded o_def])
                   | ((wp_once hoare_drop_imps)?,
                      (wp_once hoare_drop_imps)?,
                      wp_once deleting_irq_handler_empty))+
  apply (rule hoare_chain)
    apply (rule arch_finalise_cap_replaceable[where sl=sl])
   apply (clarsimp simp: replaceable_def reachable_pg_cap_def
                         o_def cap_range_def valid_arch_state_def
                         ran_tcb_cap_cases is_cap_simps
                         obj_irq_refs_subset
                         vs_cap_ref_def is_pt_cap_def is_pd_cap_def)+
  apply (fastforce split: option.splits vmpage_size.splits)
  done

lemma empty_slot_cte_wp_elsewhere:
  "\<lbrace>(\<lambda>s. cte_wp_at P p s) and K (p \<noteq> p')\<rbrace> empty_slot p' opt \<lbrace>\<lambda>rv s. cte_wp_at P p s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: empty_slot_def cte_wp_at_caps_of_state)
  apply (wp opt_return_pres_lift | simp split del: split_if)+
  done


lemma fast_finalise_lift:
assumes ep:"\<And>r. \<lbrace>P\<rbrace>ep_cancel_all r \<lbrace>\<lambda>r s. P s\<rbrace>"
and aep:"\<And>r. \<lbrace>P\<rbrace>aep_cancel_all r \<lbrace>\<lambda>r s. P s\<rbrace>"
shows "\<lbrace>P\<rbrace> fast_finalise cap final \<lbrace>\<lambda>r s. P s\<rbrace>"
  apply (case_tac cap,simp_all)
  apply (wp ep aep | clarsimp)+
  done

crunch cte_wp_at[wp]: fast_finalise "cte_wp_at P p"
  (wp:fast_finalise_lift)

lemma cap_delete_one_cte_wp_at_preserved:
  assumes x: "\<And>cap flag. P cap \<Longrightarrow> \<not> can_fast_finalise cap"
  shows "\<lbrace>cte_wp_at P p\<rbrace> cap_delete_one ptr \<lbrace>\<lambda>rv s. cte_wp_at P p s\<rbrace>"
  apply (simp add: cte_wp_at_caps_of_state)
  apply (wp cap_delete_one_caps_of_state)
  apply (clarsimp simp: cte_wp_at_caps_of_state x)
  done


lemma deleting_irq_handler_cte_preserved:
  assumes x: "\<And>cap flag. P cap \<Longrightarrow> \<not> can_fast_finalise cap"
  shows "\<lbrace>cte_wp_at P p\<rbrace> deleting_irq_handler irq \<lbrace>\<lambda>rv. cte_wp_at P p\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply (wp cap_delete_one_cte_wp_at_preserved | simp add: x)+
  done


crunch cte_wp_at[wp]: arch_finalise_cap "\<lambda>s. P (cte_wp_at P' p s)"
  (simp: crunch_simps assertE_def wp: crunch_wps set_object_cte_at)


interpretation delete_one_pre
  by (unfold_locales, wp cap_delete_one_cte_wp_at_preserved)


lemma finalise_cap_equal_cap[wp]:
  "\<lbrace>cte_wp_at (op = cap) sl\<rbrace>
     finalise_cap cap fin
   \<lbrace>\<lambda>rv. cte_wp_at (op = cap) sl\<rbrace>"
  apply (cases cap, simp_all split del: split_if)
       apply (wp suspend_cte_wp_at_preserved
                 deleting_irq_handler_cte_preserved
               | clarsimp simp: can_fast_finalise_def)+
  done

lemma fast_finalise_replaceable[wp]:
  "\<lbrace>\<lambda>s. s \<turnstile> cap \<and> x = is_final_cap' cap s
     \<and> cte_wp_at (op = cap) sl s \<and> valid_asid_table (arm_asid_table (arch_state s)) s\<rbrace>
     fast_finalise cap x
   \<lbrace>\<lambda>rv s. cte_wp_at (replaceable s sl cap.NullCap) sl s\<rbrace>"
  apply (cases "cap_irqs cap = {}")
   apply (simp add: fast_finalise_def2)
   apply wp
    apply (rule hoare_strengthen_post)
     apply (rule hoare_vcg_conj_lift)
      apply (rule finalise_cap_replaceable[where sl=sl])
     apply (rule finalise_cap_equal_cap[where sl=sl])
    apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply wp
   apply (clarsimp simp: is_cap_simps can_fast_finalise_def)
  apply (clarsimp simp: cap_irqs_def cap_irq_opt_def split: cap.split_asm)
  done

lemma emptyable_lift:
  assumes typ_at: "\<And>P T t. \<lbrace>\<lambda>s. P (typ_at T t s)\<rbrace> f \<lbrace>\<lambda>_ s. P (typ_at T t s)\<rbrace>"
  assumes st_tcb: "\<And>t. \<lbrace>st_tcb_at halted t\<rbrace> f \<lbrace>\<lambda>_. st_tcb_at halted t\<rbrace>"
  shows "\<lbrace>emptyable t\<rbrace> f \<lbrace>\<lambda>_. emptyable t\<rbrace>"
  unfolding emptyable_def
  apply (subst imp_conv_disj)+
  apply (rule hoare_vcg_disj_lift)
   apply (simp add: tcb_at_typ)
   apply (rule typ_at)
  apply (rule st_tcb)
  done


crunch emptyable[wp]: set_endpoint, set_async_ep "emptyable sl"
  (wp: emptyable_lift)


lemma sts_emptyable:
  "\<lbrace>emptyable sl and st_tcb_at (\<lambda>st. \<not> halted st) t\<rbrace>
    set_thread_state t st
   \<lbrace>\<lambda>rv. emptyable sl\<rbrace>"
  apply (simp add: emptyable_def)
  apply (subst imp_conv_disj)+
  apply (wp hoare_vcg_disj_lift sts_st_tcb_at_cases | simp add: tcb_at_typ)+
  apply (clarsimp simp: st_tcb_at_def obj_at_def)
  done


lemma cancel_all_emptyable_helper:
  "\<lbrace>emptyable sl and (\<lambda>s. \<forall>t \<in> set q. st_tcb_at (\<lambda>st. \<not> halted st) t s)\<rbrace>
     mapM_x (\<lambda>t. do y \<leftarrow> set_thread_state t Structures_A.Restart;
                    do_extended_op (tcb_sched_enqueue_ext t) od) q
   \<lbrace>\<lambda>rv. emptyable sl\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (rule mapM_x_wp [where S="set q", simplified])
    apply (wp, simp, wp hoare_vcg_const_Ball_lift sts_emptyable sts_st_tcb_at_cases)
     apply simp+
  done


lemma aep_cancel_all_emptyable[wp]:
  "\<lbrace>invs and emptyable sl\<rbrace> aep_cancel_all ptr \<lbrace>\<lambda>_. emptyable sl\<rbrace>"
  apply (simp add: aep_cancel_all_def)
  apply (rule hoare_seq_ext [OF _ get_aep_sp])
  apply (case_tac aep, simp_all)
    apply (wp, simp)
   apply (wp, simp, wp cancel_all_emptyable_helper hoare_vcg_const_Ball_lift)
    apply (clarsimp simp: invs_def valid_state_def valid_pspace_def
                          aep_queued_st_tcb_at obj_at_def)
   apply (simp)
  apply (wp, simp)
  done


lemma ep_cancel_all_emptyable[wp]:
  "\<lbrace>invs and emptyable sl\<rbrace> ep_cancel_all ptr \<lbrace>\<lambda>_. emptyable sl\<rbrace>"
  apply (simp add: ep_cancel_all_def)
  apply (rule hoare_seq_ext [OF _ get_endpoint_sp])
  apply (case_tac ep, simp_all)
    apply (wp, simp)
   apply (wp cancel_all_emptyable_helper hoare_vcg_const_Ball_lift
        | simp add: get_ep_queue_def
        | clarsimp simp: invs_def valid_state_def valid_pspace_def
                         ep_queued_st_tcb_at)+
  done



lemma fast_finalise_emptyable[wp]:
  "\<lbrace>invs and emptyable sl\<rbrace> fast_finalise cap fin \<lbrace>\<lambda>rv. emptyable sl\<rbrace>"
  apply (simp add: fast_finalise_def2)
  apply (case_tac cap, simp_all add: can_fast_finalise_def)
      apply (wp | simp add: o_def)+
  done

lemma cap_delete_one_invs[wp]:
  "\<lbrace>invs and emptyable ptr\<rbrace> cap_delete_one ptr \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def is_final_cap_def)
  apply (rule hoare_pre)
  apply (wp empty_slot_invs get_cap_wp)
  apply clarsimp
  apply (drule cte_wp_at_valid_objs_valid_cap, clarsimp+)
  done

lemma cap_delete_one_deletes[wp]:
  "\<lbrace>\<top>\<rbrace> cap_delete_one ptr \<lbrace>\<lambda>rv. cte_wp_at (\<lambda>c. c = cap.NullCap) ptr\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def)
  apply (wp get_cap_wp)
  apply (clarsimp elim!: cte_wp_at_weakenE)
  done

interpretation delete_one_abs
  by (unfold_locales, wp cap_delete_one_deletes cap_delete_one_caps_of_state)

lemma cap_delete_one_deletes_reply:
  "\<lbrace>cte_wp_at (op = (cap.ReplyCap t False)) slot and valid_reply_caps\<rbrace>
    cap_delete_one slot
   \<lbrace>\<lambda>rv s. \<not> has_reply_cap t s\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def is_final_cap_def)
  apply wp
     apply (rule_tac Q="\<lambda>rv s. \<forall>sl'. if (sl' = slot)
                               then cte_wp_at (\<lambda>c. c = cap.NullCap) sl' s
                               else caps_of_state s sl' \<noteq> Some (cap.ReplyCap t False)"
                  in hoare_post_imp)
      apply (clarsimp simp add: has_reply_cap_def cte_wp_at_caps_of_state
                      simp del: split_paired_All split_paired_Ex
                         split: split_if_asm elim!: allEI)
     apply (rule hoare_vcg_all_lift)
     apply simp
     apply (wp static_imp_wp empty_slot_deletes empty_slot_caps_of_state get_cap_wp)
  apply (fastforce simp: cte_wp_at_caps_of_state valid_reply_caps_def
                        is_cap_simps unique_reply_caps_def
              simp del: split_paired_All)
  done


lemma cap_delete_one_reply_st_tcb_at:
  "\<lbrace>st_tcb_at P t and cte_wp_at (op = (cap.ReplyCap t' False)) slot\<rbrace>
    cap_delete_one slot
   \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def is_final_cap_def)
  apply (rule hoare_seq_ext [OF _ get_cap_sp])
  apply (rule hoare_assume_pre)
  apply (clarsimp simp: cte_wp_at_caps_of_state when_def)
  apply wp
  apply simp
  done


lemma get_irq_slot_emptyable[wp]:
  "\<lbrace>invs\<rbrace> get_irq_slot irq \<lbrace>emptyable\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (rule get_irq_slot_real_cte)
  apply (clarsimp simp: emptyable_def is_cap_table is_tcb elim!: obj_atE)
  done

crunch invs[wp]: deleting_irq_handler "invs"

lemma finalise_cap_invs:
  shows "\<lbrace>invs and cte_wp_at (op = cap) slot\<rbrace> finalise_cap cap x \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (cases cap, simp_all split del: split_if)
         apply (wp ep_cancel_all_invs aep_cancel_all_invs
                  | simp add: o_def split del: split_if cong: if_cong)+
      apply clarsimp (* thread *)
      apply (frule cte_wp_at_valid_objs_valid_cap, clarsimp)
      apply (clarsimp simp: valid_cap_def)
      apply (frule(1) valid_global_refsD[OF invs_valid_global_refs])
       apply (simp add: global_refs_def, rule disjI1, rule refl)
      apply (simp add: cap_range_def)
     apply (wp deleting_irq_handler_invs  | simp | intro conjI impI)+
  apply (auto dest: cte_wp_at_valid_objs_valid_cap)
  done

crunch irq_node[wp]: suspend "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps select_wp simp: crunch_simps)

crunch irq_node[wp]: deleting_irq_handler "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps select_wp simp: crunch_simps)

crunch irq_node[wp]: arch_finalise_cap "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps select_wp simp: crunch_simps)

lemma finalise_cap_irq_node:
"\<lbrace>\<lambda>s. P (interrupt_irq_node s)\<rbrace> finalise_cap a b \<lbrace>\<lambda>_ s. P (interrupt_irq_node s)\<rbrace>"
  apply (case_tac a,simp_all)
  apply (wp | clarsimp)+
  done

crunch irq_node[wp]: finalise_cap "\<lambda>s. P (interrupt_irq_node s)"
  (wp: crunch_wps select_wp simp: crunch_simps)

lemmas ep_cancel_all_cte_irq_node[wp]
    = hoare_use_eq_irq_node [OF ep_cancel_all_irq_node ep_cancel_all_cte_wp_at]

lemmas aep_cancel_all_cte_irq_node[wp]
    = hoare_use_eq_irq_node [OF aep_cancel_all_irq_node aep_cancel_all_cte_wp_at]

lemmas suspend_cte_irq_node[wp]
    = hoare_use_eq_irq_node [OF suspend_irq_node suspend_cte_wp_at_preserved]

lemmas arch_finalise_cte_irq_node[wp]
    = hoare_use_eq_irq_node [OF arch_finalise_cap_irq_node arch_finalise_cap_cte_wp_at]

lemmas deleting_irq_handler_cte_preserved_irqn
  = hoare_use_eq_irq_node [OF deleting_irq_handler_irq_node
                              deleting_irq_handler_cte_preserved]


lemma finalise_cap_cte_cap_to[wp]:
  "\<lbrace>ex_cte_cap_wp_to P sl\<rbrace> finalise_cap cap fin \<lbrace>\<lambda>rv. ex_cte_cap_wp_to P sl\<rbrace>"
  apply (cases cap, simp_all add: ex_cte_cap_wp_to_def split del: split_if)
       apply (wp hoare_vcg_ex_lift
                 deleting_irq_handler_cte_preserved_irqn
                 | simp
                 | clarsimp simp: can_fast_finalise_def
                           split: cap.split_asm)+
  done


lemma finalise_cap_zombie_cap[wp]:
  "\<lbrace>cte_wp_at (\<lambda>cp. is_zombie cp \<and> P cp) sl\<rbrace>
     finalise_cap cap fin
   \<lbrace>\<lambda>rv. cte_wp_at (\<lambda>cp. is_zombie cp \<and> P cp) sl\<rbrace>"
  apply (cases cap, simp_all split del: split_if)
       apply (wp deleting_irq_handler_cte_preserved
               | clarsimp simp: is_cap_simps can_fast_finalise_def)+
  done


crunch st_tcb_at[wp]: arch_finalise_cap "st_tcb_at P t"
  (simp: crunch_simps wp: crunch_wps)


lemma fast_finalise_st_tcb_at:
  "\<lbrace>st_tcb_at P t and K (\<forall>st. active st \<longrightarrow> P st)\<rbrace>
     fast_finalise cap fin
   \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (cases cap, simp_all)
     apply (wp ep_cancel_all_st_tcb_at
               aep_cancel_all_st_tcb_at
             | simp)+
  done


lemma cap_delete_one_st_tcb_at:
  "\<lbrace>st_tcb_at P t and K (\<forall>st. active st \<longrightarrow> P st)\<rbrace>
     cap_delete_one ptr
   \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (simp add: cap_delete_one_def unless_def
                   is_final_cap_def)
  apply (wp fast_finalise_st_tcb_at get_cap_wp)
  apply simp
  done


crunch st_tcb_at[wp]: set_irq_state "st_tcb_at P t"


lemma deleting_irq_handler_st_tcb_at:
  "\<lbrace>st_tcb_at P t and K (\<forall>st. simple st \<longrightarrow> P st)\<rbrace>
     deleting_irq_handler irq
   \<lbrace>\<lambda>rv. st_tcb_at P t\<rbrace>"
  apply (simp add: deleting_irq_handler_def)
  apply (wp cap_delete_one_st_tcb_at)
  apply simp
  done



lemma irq_node_global_refs:
  "interrupt_irq_node s irq \<in> global_refs s"
  by (simp add: global_refs_def)


lemma get_irq_slot_fast_finalisable[wp]:
  "\<lbrace>invs\<rbrace> get_irq_slot irq \<lbrace>cte_wp_at can_fast_finalise\<rbrace>"
  apply (simp add: get_irq_slot_def)
  apply wp
  apply (clarsimp simp: invs_def valid_state_def valid_irq_node_def)
  apply (drule spec[where x=irq], drule cap_table_at_cte_at[where offset="[]"])
   apply simp
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (case_tac "cap = cap.NullCap")
   apply (simp add: can_fast_finalise_def)
  apply (frule(1) if_unsafe_then_capD [OF caps_of_state_cteD])
   apply simp
  apply (clarsimp simp: ex_cte_cap_wp_to_def)
  apply (drule cte_wp_at_norm, clarsimp)
  apply (drule(1) valid_global_refsD [OF _ _ irq_node_global_refs[where irq=irq]])
  apply (case_tac c, simp_all)
     apply (clarsimp simp: cap_range_def)
    apply (clarsimp simp: cap_range_def)
   apply (clarsimp simp: appropriate_cte_cap_def can_fast_finalise_def split: cap.split_asm)
  apply (clarsimp simp: cap_range_def)
  done


lemma can_fast_finalise_Null:
  "can_fast_finalise cap.NullCap"
  by (simp add: can_fast_finalise_def)


lemmas finalise_cap_cte_at[wp] = valid_cte_at_typ [OF finalise_cap_typ_at]


lemma finalise_cap_fast_Null:
  "\<lbrace>\<lambda>s. can_fast_finalise cap\<rbrace> finalise_cap cap final \<lbrace>\<lambda>rv s. rv = (cap.NullCap, None)\<rbrace>"
  apply (cases cap, simp_all add: can_fast_finalise_def)
     apply (wp | simp only: o_def simp_thms cases_simp if_cancel fst_conv)+
  done


declare empty_fail_clearMemory[simp]


lemma tcb_cap_valid_pagetable:
  "tcb_cap_valid (cap.ArchObjectCap (arch_cap.PageTableCap word (Some v))) slot
    = tcb_cap_valid (cap.ArchObjectCap (arch_cap.PageTableCap word None)) slot"
  apply (rule ext)
  apply (simp add: tcb_cap_valid_def tcb_cap_cases_def
                   is_cap_simps valid_ipc_buffer_cap_def
            split: Structures_A.thread_state.split)
  done


lemma tcb_cap_valid_pagedirectory:
  "tcb_cap_valid (cap.ArchObjectCap (arch_cap.PageDirectoryCap word (Some v))) slot
    = tcb_cap_valid (cap.ArchObjectCap (arch_cap.PageDirectoryCap word None)) slot"
  apply (rule ext)
  apply (simp add: tcb_cap_valid_def tcb_cap_cases_def
                   is_cap_simps valid_ipc_buffer_cap_def
            split: Structures_A.thread_state.split)
  done


lemma store_pde_unmap_empty:
  "\<lbrace>\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>
    store_pde pd_slot ARM_Structs_A.pde.InvalidPDE
   \<lbrace>\<lambda>rv s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (clarsimp simp: store_pde_def set_pd_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: obj_at_def empty_table_def pde_ref_def valid_pde_mappings_def)
  done


crunch empty[wp]: find_free_hw_asid, store_hw_asid, load_hw_asid, set_vm_root_for_flush, page_table_mapped, invalidate_tlb_by_asid
  "\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s"



lemma store_pte_unmap_empty:
  "\<lbrace>\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>
    store_pte xa ARM_Structs_A.pte.InvalidPTE
   \<lbrace>\<lambda>rv s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (wp get_object_wp | simp add: store_pte_def set_pt_def set_object_def)+
  apply (clarsimp simp: obj_at_def empty_table_def)
  done


crunch caps_of_state[wp]: invalidate_tlb_by_asid
  "\<lambda>s. P (caps_of_state s)"


lemma invalidate_tlb_by_asid_pspace_aligned:
  "\<lbrace>pspace_aligned\<rbrace> invalidate_tlb_by_asid aa \<lbrace>\<lambda>_. pspace_aligned\<rbrace>"
  apply (simp add: invalidate_tlb_by_asid_def load_hw_asid_def | wp | wpc)+
  done


crunch valid_arch_objs[wp]: invalidate_tlb_by_asid, page_table_mapped
  "valid_arch_objs"


crunch executable_arch_objs[wp]: invalidate_tlb_by_asid, page_table_mapped
  "executable_arch_objs"


crunch cte_wp_at[wp]: invalidate_tlb_by_asid, page_table_mapped
  "\<lambda>s. P (cte_wp_at P' p s)"


lemmas cases_simp_option[simp] = cases_simp[where P="x = None", simplified, standard]


lemma flush_table_empty:
  "\<lbrace>\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>
    flush_table ac aa b word
   \<lbrace>\<lambda>rv s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (clarsimp simp: flush_table_def set_vm_root_def)
  apply (wp do_machine_op_obj_at set_current_asid_empty hoare_whenE_wp
    | wpc
    | simp
    | wps)+
  apply (rule_tac Q="\<lambda>pd' s.
              (if worda \<noteq> pd'
               then (\<lambda>s. obj_at
                         (empty_table (set (arm_global_pts (arch_state s)))) word
                         s)
               else (\<lambda>_. True))
               s \<and>
              (if worda \<noteq> pd' then \<lambda>s. True
               else (\<lambda>s. obj_at
                         (empty_table (set (arm_global_pts (arch_state s)))) word
                         s))
               s"
    and Q'="\<lambda>_ s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s"
    in hoare_post_imp_R)
  prefer 2 apply simp
  apply (wp find_pd_for_asid_inv mapM_wp
    | simp
    | wpc
    | rule_tac
        Q="\<lambda>_ s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s"
        in hoare_strengthen_post)+
  done


lemma unmap_page_table_empty:
  "\<lbrace>\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>
    unmap_page_table aa b word
   \<lbrace>\<lambda>rv s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (simp add: unmap_page_table_def)
  apply (wp store_pde_unmap_empty flush_table_empty page_table_mapped_empty | simp | wpc)+
  done


lemma mapM_x_store_pte_valid_arch_objs:
  "\<lbrace>invs and (\<lambda>s. \<exists>p' cap. caps_of_state s p' = Some cap \<and> is_pt_cap cap \<and>
    (\<forall>x \<in> set pteptrs. x && ~~ mask pt_bits \<in> obj_refs cap)) \<rbrace>
    mapM_x (\<lambda>p. store_pte p ARM_Structs_A.InvalidPTE) pteptrs
   \<lbrace>\<lambda>rv. valid_arch_objs\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (wp  mapM_x_wp')
    apply (fastforce simp: is_pt_cap_def)+
  done


lemma mapM_x_store_pte_executable_arch_objs [wp]:
  "\<lbrace>executable_arch_objs\<rbrace> 
    mapM_x (\<lambda>p. store_pte p ARM_Structs_A.InvalidPTE) pteptrs 
   \<lbrace>\<lambda>rv. executable_arch_objs\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (wp  mapM_x_wp')
    apply (fastforce simp: is_pt_cap_def)+
  done


lemma mapM_x_swp_store_empty_table_set:
  "\<lbrace>page_table_at p
    and pspace_aligned
    and K ((UNIV :: word8 set) \<subseteq> (\<lambda>sl. ucast ((sl && mask pt_bits) >> 2)) ` set slots
                       \<and> (\<forall>x\<in>set slots. x && ~~ mask pt_bits = p))\<rbrace>
    mapM_x (swp store_pte ARM_Structs_A.InvalidPTE) slots
   \<lbrace>\<lambda>rv s. obj_at (empty_table (S s)) p s\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (rule mapM_x_swp_store_empty_table)
  apply (clarsimp simp: obj_at_def empty_table_def)
  apply (clarsimp split: Structures_A.kernel_object.split_asm arch_kernel_obj.splits)
  done


(* FIXME: move *)
lemma invs_pspace_alignedI:
  "invs s \<Longrightarrow> pspace_aligned s"
  apply (simp add: invs_def valid_state_def valid_pspace_def)
  done

definition
  replaceable_or_arch_update
where
  "replaceable_or_arch_update \<equiv> \<lambda>s slot cap cap'.
   if is_pg_cap cap then is_arch_update cap cap' \<and>
        (\<forall>vref. vs_cap_ref cap' = Some vref \<longrightarrow>
          vs_cap_ref cap = Some vref \<and>
          obj_refs cap = obj_refs cap' \<or>
          (\<forall>oref\<in>obj_refs cap'. \<not> (vref \<unrhd> oref) s))
   else replaceable s slot cap cap'"


lemma replaceable_same:
  "replaceable s slot cap cap"
  by (simp add: replaceable_def)


lemma replaceable_or_arch_update_same:
  "replaceable_or_arch_update s slot cap cap"
  by (clarsimp simp: replaceable_or_arch_update_def
                replaceable_def is_arch_update_def is_cap_simps)


lemma cte_wp_at_disj:
  "cte_wp_at (\<lambda>c. P c \<or> P' c) sl s =
   (cte_wp_at (\<lambda>c. P c) sl s \<or> cte_wp_at (\<lambda>c. P' c) sl s)"
  unfolding cte_wp_at_def
  by fastforce


lemma hoare_pre_disj':
  "\<lbrakk>\<lbrace>\<lambda>s. P s \<and> R s\<rbrace> f \<lbrace>T\<rbrace>;
   \<lbrace>\<lambda>s. Q s \<and> R s\<rbrace> f \<lbrace>T\<rbrace> \<rbrakk> \<Longrightarrow>
  \<lbrace>\<lambda>s. (P s \<or> Q s) \<and> R s\<rbrace> f \<lbrace>T\<rbrace>"
  apply (rule hoare_pre)
  apply (erule (1) hoare_pre_disj)
  apply simp
  done


lemma replace_cap_invs_arch_update:
  "\<lbrace>\<lambda>s. cte_wp_at (replaceable_or_arch_update s p cap) p s
        \<and> invs s
        \<and> cap \<noteq> cap.NullCap
        \<and> ex_cte_cap_wp_to (appropriate_cte_cap cap) p s
        \<and> s \<turnstile> cap\<rbrace>
     set_cap cap p
   \<lbrace>\<lambda>rv s. invs s\<rbrace>"
  apply (simp add:replaceable_or_arch_update_def)
  apply (cases "is_pg_cap cap")
   apply (wp hoare_pre_disj[OF arch_update_cap_invs_unmap_page arch_update_cap_invs_map])
   apply (simp add:replaceable_or_arch_update_def replaceable_def cte_wp_at_caps_of_state)
   apply (clarsimp simp: cte_wp_at_caps_of_state is_cap_simps obj_irq_refs_def
                         cap_master_cap_simps is_arch_update_def)
  apply (wp replace_cap_invs)
  apply simp
  done

lemma is_final_cap_pt_asid_eq:
  "is_final_cap' (cap.ArchObjectCap (arch_cap.PageTableCap p y)) s \<Longrightarrow>
   is_final_cap' (cap.ArchObjectCap (arch_cap.PageTableCap p x)) s"
  apply (clarsimp simp: is_final_cap'_def)
  done


lemma is_final_cap_pd_asid_eq:
  "is_final_cap' (cap.ArchObjectCap (arch_cap.PageDirectoryCap p y)) s \<Longrightarrow>
   is_final_cap' (cap.ArchObjectCap (arch_cap.PageDirectoryCap p x)) s"
  apply (clarsimp simp: is_final_cap'_def)
  done


lemma cte_wp_at_obj_refs_singleton_page_table:
  "\<lbrakk>cte_wp_at
      (\<lambda>cap'. obj_refs cap' = {p}
            \<and> (\<exists>p asid. cap' = cap.ArchObjectCap (arch_cap.PageTableCap p asid)))
      (a, b) s\<rbrakk> \<Longrightarrow>
   \<exists>asid. cte_wp_at (op = (cap.ArchObjectCap (arch_cap.PageTableCap p asid))) (a,b) s"
  apply (clarsimp simp: cte_wp_at_def)
  done


lemma cte_wp_at_obj_refs_singleton_page_directory:
  "\<lbrakk>cte_wp_at
      (\<lambda>cap'. obj_refs cap' = {p}
            \<and> (\<exists>p asid. cap' = cap.ArchObjectCap (arch_cap.PageDirectoryCap p asid)))
      (a, b) s\<rbrakk> \<Longrightarrow>
   \<exists>asid. cte_wp_at
            (op = (cap.ArchObjectCap (arch_cap.PageDirectoryCap p asid))) (a,b) s"
  apply (clarsimp simp: cte_wp_at_def)
  done


lemma final_cap_pt_slot_eq:
  "\<lbrakk>is_final_cap' (cap.ArchObjectCap (arch_cap.PageTableCap p asid)) s;
    cte_wp_at (op = (cap.ArchObjectCap (arch_cap.PageTableCap p asid'))) slot s;
    cte_wp_at (op = (cap.ArchObjectCap (arch_cap.PageTableCap p asid''))) slot' s\<rbrakk> \<Longrightarrow>
   slot' = slot"
  apply (clarsimp simp:is_final_cap'_def2)
  apply (case_tac "(a,b) = slot'")
   apply (case_tac "(a,b) = slot")
    apply simp
   apply (erule_tac x="fst slot" in allE)
   apply (erule_tac x="snd slot" in allE)
   apply (clarsimp simp: obj_irq_refs_def cap_irqs_def cte_wp_at_def)
  apply (erule_tac x="fst slot'" in allE)
  apply (erule_tac x="snd slot'" in allE)
  apply (clarsimp simp: obj_irq_refs_def cap_irqs_def cte_wp_at_def)
  done


lemma final_cap_pd_slot_eq:
  "\<lbrakk>is_final_cap' (cap.ArchObjectCap (arch_cap.PageDirectoryCap p asid)) s;
    cte_wp_at (op = (cap.ArchObjectCap (arch_cap.PageDirectoryCap p asid'))) slot s;
    cte_wp_at (op = (cap.ArchObjectCap (arch_cap.PageDirectoryCap p asid''))) slot' s\<rbrakk>
  \<Longrightarrow> slot' = slot"
  apply (clarsimp simp:is_final_cap'_def2)
  apply (case_tac "(a,b) = slot'")
   apply (case_tac "(a,b) = slot")
    apply simp
   apply (erule_tac x="fst slot" in allE)
   apply (erule_tac x="snd slot" in allE)
   apply (clarsimp simp: obj_irq_refs_def cap_irqs_def cte_wp_at_def)
  apply (erule_tac x="fst slot'" in allE)
  apply (erule_tac x="snd slot'" in allE)
  apply (clarsimp simp: obj_irq_refs_def cap_irqs_def cte_wp_at_def)
  done


lemma is_arch_update_reset_page:
  "is_arch_update
     (cap.ArchObjectCap (arch_cap.PageCap p r sz m))
     (cap.ArchObjectCap (arch_cap.PageCap p r' sz m'))"
  apply (simp add: is_arch_update_def is_arch_cap_def cap_master_cap_def)
  done


lemma replaceable_reset_pt:
  "\<lbrakk>cap = arch_cap.PageTableCap p m \<and>
   cte_wp_at (op = (cap.ArchObjectCap cap)) slot s \<and>
   (\<forall>vs. vs_cap_ref (cap.ArchObjectCap cap) = Some vs \<longrightarrow> \<not> (vs \<unrhd> p) s) \<and>
   is_final_cap' (cap.ArchObjectCap cap) s \<and>
   obj_at (empty_table (set (arm_global_pts (arch_state s)))) p s\<rbrakk> \<Longrightarrow>
   replaceable s slot (cap.ArchObjectCap (arch_cap.PageTableCap p None))
                      (cap.ArchObjectCap cap)"
  apply (elim conjE)
  apply (cases m, simp_all add: replaceable_def obj_irq_refs_def cap_range_def
                                is_cap_simps tcb_cap_valid_pagetable)
  apply (rule conjI)
   apply (frule is_final_cap_pt_asid_eq) defer
   apply clarsimp
   apply (drule cte_wp_at_obj_refs_singleton_page_table)
   apply (erule exE)
   apply (drule_tac x="asid" in is_final_cap_pt_asid_eq)
   apply (drule final_cap_pt_slot_eq)
     apply simp_all
  apply (rule_tac
    cap="(cap.ArchObjectCap cap)"
    in  no_cap_to_obj_with_diff_ref_finalI)
  apply simp_all
  done


lemma replaceable_reset_pd:
  "\<lbrakk>cap = arch_cap.PageDirectoryCap p m \<and>
   cte_wp_at (op = (cap.ArchObjectCap cap)) slot s \<and>
   (\<forall>vs. vs_cap_ref (cap.ArchObjectCap cap) = Some vs \<longrightarrow> \<not> (vs \<unrhd> p) s) \<and>
   is_final_cap' (cap.ArchObjectCap cap) s \<and>
   obj_at (empty_table (set (arm_global_pts (arch_state s)))) p s\<rbrakk> \<Longrightarrow>
   replaceable s slot (cap.ArchObjectCap (arch_cap.PageDirectoryCap p None))
                      (cap.ArchObjectCap cap)"
  apply (elim conjE)
  apply (cases m, simp_all add: replaceable_def obj_irq_refs_def cap_range_def is_cap_simps
                           tcb_cap_valid_pagedirectory)
  apply (rule conjI)
   apply (frule is_final_cap_pd_asid_eq) defer
   apply clarsimp
   apply (drule cte_wp_at_obj_refs_singleton_page_directory)
   apply (erule exE)
   apply (drule_tac x="asid" in is_final_cap_pd_asid_eq)
   apply (drule final_cap_pd_slot_eq)
     apply simp_all
  apply (rule_tac
    cap="(cap.ArchObjectCap cap)"
    in  no_cap_to_obj_with_diff_ref_finalI)
  apply simp_all
  done


crunch caps_of_state [wp]: arch_finalise_cap "\<lambda>s. P (caps_of_state s)"
   (wp: crunch_wps)


crunch obj_at[wp]: set_vm_root, invalidate_tlb_by_asid "\<lambda>s. P' (obj_at P p s)"
  (wp: hoare_whenE_wp simp: crunch_simps)


crunch arm_global_pts[wp]: set_vm_root, invalidate_asid_entry "\<lambda>s. P' (arm_global_pts (arch_state s))"
  (wp: hoare_whenE_wp simp: crunch_simps)


lemma delete_asid_empty_table_pd:
  "\<lbrace>\<lambda>s. page_directory_at word s
      \<and> obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>
    delete_asid a word
   \<lbrace>\<lambda>_ s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
   apply (simp add: delete_asid_def)
   apply (wp | wpc)+
         apply wps
         apply wp
       apply (simp add: set_asid_pool_def)
       apply wp
         apply (case_tac "aa = word")
          defer
          apply wps
          apply (rule set_object_at_obj)
         apply (wp get_object_ret | wps)+
   apply (clarsimp simp: obj_at_def empty_table_def)+
  done


lemma page_directory_at_def2:
  "page_directory_at p s = (\<exists>pd. ko_at (ArchObj (PageDirectory pd)) p s)"
  apply (simp add: a_type_def obj_at_def)
  apply (rule iffI)
   apply (erule exE)
   apply (case_tac ko) apply (simp_all add: split_if_eq1)
   apply (case_tac arch_kernel_obj) apply simp_all
  apply (erule exE)
  apply (rule_tac x="ArchObj (PageDirectory pd)" in exI)
  apply simp
  done


definition
  pde_wp_at :: "(ARM_Structs_A.pde \<Rightarrow> bool) \<Rightarrow> word32 \<Rightarrow> (12 word) \<Rightarrow> 'z state \<Rightarrow> bool"
  where
  "pde_wp_at P ptr slot s \<equiv>
     (case (kheap s ptr) of
         Some (ArchObj (PageDirectory pd)) \<Rightarrow> P (pd slot)
       | _ \<Rightarrow> False)"


lemma store_pde_pde_wp_at:
  "\<lbrace>\<top>\<rbrace>
   store_pde p x
   \<lbrace>\<lambda>_. pde_wp_at
         (\<lambda>pde. pde = x) (p && ~~ mask pd_bits) (ucast (p && mask pd_bits >> 2))\<rbrace>"
  apply (wp
    | simp add: store_pde_def set_pd_def set_pd_def set_object_def get_object_def
                obj_at_def pde_wp_at_def)+
  done


lemma store_pde_pde_wp_at2:
  "\<lbrace>pde_wp_at (\<lambda>pde. pde = ARM_Structs_A.pde.InvalidPDE) ptr slot\<rbrace>
   store_pde p' ARM_Structs_A.pde.InvalidPDE
   \<lbrace>\<lambda>_. pde_wp_at (\<lambda>pde. pde = ARM_Structs_A.pde.InvalidPDE) ptr slot\<rbrace>"
  apply (wp
    | simp add: store_pde_def set_pd_def set_pd_def set_object_def get_object_def
                obj_at_def pde_wp_at_def
    | clarsimp)+
  done


lemma obj_at_empty_tableI:
  "invs s \<and>
  (\<forall>x. x \<notin> kernel_mapping_slots \<longrightarrow>
      pde_wp_at (\<lambda>pde. pde = ARM_Structs_A.pde.InvalidPDE) p x s)
  \<Longrightarrow> obj_at (empty_table (set (arm_global_pts (arch_state s)))) p s"
  apply safe
  apply (simp add: obj_at_def empty_table_def pde_wp_at_def)
  (* Boring cases *)
  apply (case_tac "\<exists>ko. kheap s p = Some ko")
   apply (erule exE) apply (rule_tac x=ko in exI)
   apply (rule conjI)
    apply assumption
   apply (case_tac ko)
       apply ((erule_tac x="ucast (kernel_base >> 20) - 1" in allE,
         simp add: kernel_base_def kernel_mapping_slots_def)+)[4]
   apply (case_tac arch_kernel_obj) defer 3
      apply ((erule_tac x="ucast (kernel_base >> 20) - 1" in allE,
         simp add: kernel_base_def kernel_mapping_slots_def)+)[4]
   (* Interesting case *)
  apply clarsimp
  apply (erule_tac x=x in allE)
  apply (case_tac "x \<notin> kernel_mapping_slots")
   apply (simp add:valid_pde_mappings_def pde_ref_def)
  apply simp
  apply (rule conjI)
   apply (simp add: invs_def valid_state_def valid_kernel_mappings_def
                    valid_kernel_mappings_if_pd_def)
   apply (erule conjE)+
   apply (erule_tac x="ArchObj (PageDirectory fun)" in ballE)
    apply simp
   apply (simp add: ran_def)
  apply (clarsimp simp: invs_def valid_state_def valid_arch_state_def
                        valid_global_objs_def equal_kernel_mappings_def
                        obj_at_def a_type_simps)
   apply (erule_tac x=p in allE,
          erule_tac x="arm_global_pd (arch_state s)" in allE)
   apply (erule_tac x="fun" in allE, erule_tac x="pd" in allE)
   apply (simp add: empty_table_def)
  done


lemma pd_shifting_again3:
  "is_aligned pd pd_bits \<Longrightarrow> ((ucast (ae :: 12 word) << 2) + (pd :: word32) && ~~ mask pd_bits) = pd"
  apply (subst add_commute)
  apply (rule pd_shifting_again)
  apply assumption
  done

lemma pd_shifting_again4: "is_aligned (pd::word32) pd_bits \<Longrightarrow>
  (ucast (ae::12 word) << 2) + pd && mask pd_bits = (ucast ae << 2)"
  apply (subst add_commute)
  apply (simp add:shiftl_t2n mask_add_aligned)
  apply (rule less_mask_eq)
  apply (rule word_less_power_trans[where k = 2, simplified])
  apply (rule less_le_trans[OF ucast_less])
    apply (simp add:pd_bits_def pageBits_def)+
  done

lemma pd_shifting_again5:
  "\<lbrakk>is_aligned (pd :: word32) pd_bits;(sl::word32) = ucast (ae::12 word)\<rbrakk> \<Longrightarrow>
  ucast ((sl << 2) + pd && mask pd_bits >> 2) = ae"
  apply simp
  apply (frule_tac pd=pd and ae=ae in pd_shifting_again4)
  apply simp
  apply (cut_tac x="ucast ae :: word32" and n=2 in shiftl_shiftr_id)
    apply ((simp add: word_bits_def less_le_trans[OF ucast_less])+)[2]
  apply (simp add:ucast_bl word_bl.Rep_inverse)
  apply (subst word_rep_drop)
    apply simp
  done

lemma pd_shifting_kernel_mapping_slots:
  "\<lbrakk>is_aligned word pd_bits;
    (sl :: word32) \<le> (kernel_base >> (20\<Colon>nat)) - (1\<Colon>word32)\<rbrakk>
   \<Longrightarrow> ucast ((sl << (2\<Colon>nat)) + word && mask pd_bits >> (2\<Colon>nat))
      \<notin> kernel_mapping_slots"
  apply (subst pd_shifting_again5)
    apply assumption+
   prefer 2
   apply (simp add:not_le kernel_mapping_slots_def)
   apply (subst (asm) le_m1_iff_lt[THEN iffD1])
    apply (simp add: kernel_base_def)
   apply (rule shiftr_20_less[where x = "sl << 20",THEN iffD2])
   apply (subst shiftl_shiftr_id)
     apply (simp add:word_bits_def)
    defer
    apply assumption
   apply (subst shiftl_shiftr_id)
     apply (simp add:word_bits_def)
    defer
    apply (simp add: ucast_bl word_rep_drop of_drop_to_bl word_size)
    apply (subst eq_commute)
    apply (subst and_mask_eq_iff_le_mask)
    apply (rule order_trans)
     apply ((simp add: kernel_base_def mask_def)+)[2]
   apply (rule_tac x="sl" and y="kernel_base >> 20" in less_trans)
    apply ((simp add: kernel_base_def word_bits_def)+)[2]
  apply (subst (asm) le_m1_iff_lt[THEN iffD1])
   apply (simp add: kernel_base_def)
  apply (rule_tac x="sl" and y="kernel_base >> 20" in less_trans)
   apply ((simp add: kernel_base_def word_bits_def)+)[2]
  done

lemma pd_shifting_global_refs:
  "\<lbrakk>is_aligned pd pd_bits;
    ae \<le> (kernel_base >> 20) - 1; pd \<notin> global_refs s\<rbrakk>
   \<Longrightarrow> ((ae::word32) << 2) + pd && ~~ mask pd_bits \<notin> global_refs s"
  apply (cut_tac pd="pd" and ae="ucast ae" in pd_shifting_again3)
   apply simp
  apply (simp add: ucast_bl word_rep_drop of_drop_to_bl word_size)
  apply (insert and_mask_eq_iff_le_mask[where n=12 and w=ae, THEN iffD2])
  apply (frule_tac z="mask 12" in order_trans)
   apply (simp add: mask_def kernel_base_def)
  apply simp
  done

lemma mapM_x_store_pde_InvalidPDE_empty:
  "\<lbrace>(invs and  (\<lambda>s. word \<notin> global_refs s)) and K(is_aligned word pd_bits)\<rbrace>
    mapM_x (swp store_pde ARM_Structs_A.pde.InvalidPDE)
           (map (\<lambda>a. (a << 2) + word) [0.e.(kernel_base >> 20) - 1])
   \<lbrace>\<lambda>_ s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (rule hoare_post_imp)
   apply (erule obj_at_empty_tableI)
  apply (wp hoare_vcg_conj_lift)
    apply (rule mapM_x_swp_store_pde_invs_unmap)
   apply (simp add: mapM_x_map)
   apply (rule hoare_strengthen_post)
    apply (rule mapM_x_accumulate_checks[OF store_pde_pde_wp_at])
    defer
    apply (rule allI)
    apply (erule_tac x="ucast x" in ballE)
     apply (rule impI)
     apply (frule_tac pd="word" and ae="x" in pd_shifting_again3)
     apply (frule_tac pd="word" and ae="x" in pd_shifting_again5)
      apply ((simp add: kernel_mapping_slots_def kernel_base_def)+)[3]
    apply (subst word_not_le)
    apply (subst (asm) word_not_le)
    apply (cut_tac x="ucast x" and y="kernel_base >> 20" in le_m1_iff_lt)
    apply clarsimp
    apply (simp add: le_m1_iff_lt word_less_nat_alt unat_ucast)
    apply (simp add: pde_ref_def)
   apply (rule conjI, rule allI, rule impI)
    apply (rule pd_shifting_kernel_mapping_slots)
     apply simp+
   apply (rule allI, rule impI)
   apply (rule pd_shifting_global_refs)
     apply simp+
  apply (wp store_pde_pde_wp_at2)
  done

lemma word_aligned_pt_slots:
  "\<lbrakk>is_aligned word pt_bits;
    x \<in> set [word , word + 4 .e. word + 2 ^ pt_bits - 1]\<rbrakk>
  \<Longrightarrow> x && ~~ mask pt_bits = word"
  apply (simp add: pt_bits_def pageBits_def)
  apply (drule subsetD[OF upto_enum_step_subset])
  apply (frule_tac ptr'=x in mask_in_range)
  apply simp
  done

lemma pt_shifting:
  "\<lbrakk>is_aligned (pt::word32) pt_bits\<rbrakk>
   \<Longrightarrow> pt + (ucast (ae :: word8) << 2) && mask pt_bits
      = (ucast (ae :: word8) << 2)"
  apply (rule conjunct1, erule is_aligned_add_helper)
  apply (rule ucast_less_shiftl_helper)
   apply (simp add: word_bits_def)
  apply (simp add: pt_bits_def pageBits_def)
  done

lemma word32_ucast_enumerates_word8:
  "\<lbrakk>is_aligned (word :: word32) pt_bits\<rbrakk>
  \<Longrightarrow> (x :: word8) \<in> (\<lambda>sl. ucast (sl && mask pt_bits >> 2))
     ` set [word , word + 4 .e. word + 2 ^ pt_bits - 1]"
  apply (rule_tac x="word + (ucast x << 2)" in image_eqI)
   apply (frule_tac ae="x" in pt_shifting)
   apply simp
   apply (rule sym)
   apply (rule pd_casting_shifting)
   apply (simp add: word_size len32)
  apply (clarsimp simp: upto_enum_step_def)
  apply (rule conjI)
   apply (subgoal_tac
     " word + 2 ^ pt_bits - 1 \<ge> word", simp)
   apply (rule is_aligned_no_overflow)
    apply (simp, simp add: pt_bits_def pageBits_def word_bits_def)
  apply clarsimp
  apply (rule_tac x="ucast x" in image_eqI)
   apply (simp add: word32_shift_by_2)
  apply (clarsimp simp: pt_bits_def pageBits_def)
  apply (rule order_trans)
   apply (rule minus_one_helper3)
   apply (rule ucast_less)
   apply simp+
  done

lemma caps_of_state_aligned_page_table:
  "\<lbrakk>caps_of_state s slot =
  Some (cap.ArchObjectCap (arch_cap.PageTableCap word option));
  invs s\<rbrakk>
  \<Longrightarrow> is_aligned word pt_bits"
  apply (frule caps_of_state_valid)
  apply (frule invs_valid_objs, assumption)
  apply (frule valid_cap_aligned)
  apply (simp add: cap_aligned_def pt_bits_def pageBits_def)
  done

lemma caps_of_state_aligned_page_directory:
  "\<lbrakk>caps_of_state s slot =
  Some (cap.ArchObjectCap (arch_cap.PageDirectoryCap word option));
  invs s\<rbrakk>
  \<Longrightarrow> is_aligned word pd_bits"
  apply (frule caps_of_state_valid)
  apply (frule invs_valid_objs, assumption)
  apply (frule valid_cap_aligned)
  apply (simp add: cap_aligned_def pd_bits_def pageBits_def)
  done

lemma invs_valid_arch_capsI:
  "invs s \<Longrightarrow> valid_arch_caps s"
  by (simp add: invs_def valid_state_def)

lemma invs_valid_table_capsI:
  "invs s \<Longrightarrow> valid_table_caps s"
  by (simp add: invs_def valid_state_def valid_arch_caps_def)

lemma replaceable_reset_pt_strg:
  "cap = arch_cap.PageTableCap p m \<Longrightarrow> cap = cap' \<and>
   cte_wp_at (op = (cap.ArchObjectCap cap)) slot s \<and>
   (\<forall>vs. vs_cap_ref (cap.ArchObjectCap cap) = Some vs \<longrightarrow> \<not> (vs \<unrhd> p) s) \<and>
   is_final_cap' (cap.ArchObjectCap cap) s \<and>
   obj_at (empty_table (set (arm_global_pts (arch_state s)))) p s \<longrightarrow>
   replaceable_or_arch_update s slot (cap.ArchObjectCap (arch_reset_mem_mapping cap)) (cap.ArchObjectCap cap')"
  unfolding replaceable_or_arch_update_def
  by (fastforce simp add: is_cap_simps intro!: replaceable_reset_pt)

lemma replaceable_reset_pd_strg:
  "cap = arch_cap.PageDirectoryCap p m \<Longrightarrow> cap = cap' \<and>
   cte_wp_at (op = (cap.ArchObjectCap cap)) slot s \<and>
   (\<forall>vs. vs_cap_ref (cap.ArchObjectCap cap) = Some vs \<longrightarrow> \<not> (vs \<unrhd> p) s) \<and>
   is_final_cap' (cap.ArchObjectCap cap) s \<and>
   obj_at (empty_table (set (arm_global_pts (arch_state s)))) p s \<longrightarrow>
   replaceable_or_arch_update s slot (cap.ArchObjectCap (arch_reset_mem_mapping cap))
                                     (cap.ArchObjectCap cap')"
  unfolding replaceable_or_arch_update_def
  by (fastforce simp add: is_cap_simps intro!: replaceable_reset_pd)

lemma arch_finalise_case_no_lookup:
  "\<lbrace>pspace_aligned and valid_arch_objs and valid_objs and
    valid_cap (cap.ArchObjectCap acap) and (\<lambda>s. valid_asid_table (arm_asid_table (arch_state s)) s)
    and K (aobj_ref acap = Some w \<and> is_final)\<rbrace>
  arch_finalise_cap acap is_final
  \<lbrace>\<lambda>rv s. (\<forall>vs. vs_cap_ref (cap.ArchObjectCap acap) = Some vs \<longrightarrow> \<not> (vs \<unrhd> w) s)\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (rule hoare_pre)
   apply (simp add: arch_finalise_cap_def)
   apply (wpc | wp delete_asid_pool_unmapped hoare_vcg_imp_lift
                   unmap_page_table_unmapped3
              | simp add: vs_cap_ref_simps
                          vs_lookup_pages_eq_at[THEN fun_cong, symmetric]
                          vs_lookup_pages_eq_ap[THEN fun_cong, symmetric])+
     apply (wp hoare_vcg_all_lift unmap_page_unmapped static_imp_wp)
    apply (wpc|wp unmap_page_table_unmapped3 delete_asid_unmapped
      |simp add:vs_cap_ref_def
      vs_lookup_pages_eq_at[THEN fun_cong,symmetric]
      vs_lookup_pages_eq_ap[THEN fun_cong,symmetric])+
   apply (auto simp: valid_cap_simps valid_arch_state_def
              split: vmpage_size.split)
   done

lemma arch_finalise_pt_pd_empty:
  "\<lbrace>(\<lambda>s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) ptr s) and valid_cap (cap.ArchObjectCap acap) and
    K ((is_pt_cap (cap.ArchObjectCap acap) \<or> is_pd_cap (cap.ArchObjectCap acap)) \<and> aobj_ref acap = Some ptr)\<rbrace>
  arch_finalise_cap acap final
  \<lbrace>\<lambda>rv s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) ptr s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply clarsimp
  apply (erule disjE)
   apply (clarsimp simp: is_cap_simps arch_finalise_cap_def)
   apply (rule hoare_pre)
   apply (wp unmap_page_table_empty | wpc)+
   apply clarsimp
  apply (clarsimp simp: is_cap_simps arch_finalise_cap_def)
  apply (rule hoare_pre)
  apply (wp unmap_page_table_empty delete_asid_empty_table_pd | wpc)+
  apply (clarsimp simp: valid_cap_def)
  done

lemma dmo_tcb_cap_valid:
  "\<lbrace>\<lambda>s. P (tcb_cap_valid cap ptr s)\<rbrace> do_machine_op mop \<lbrace>\<lambda>_ s. P (tcb_cap_valid cap ptr s)\<rbrace>"
  apply (simp add: tcb_cap_valid_def no_cap_to_obj_with_diff_ref_def)
  apply (rule hoare_pre)
  apply wps
  apply wp
  apply simp
  done

lemma do_machine_op_reachable_pg_cap[wp]:
  "\<lbrace>\<lambda>s. P (reachable_pg_cap cap s)\<rbrace>
   do_machine_op mo
   \<lbrace>\<lambda>rv s. P (reachable_pg_cap cap s)\<rbrace>"
  apply (simp add:reachable_pg_cap_def,wp)
  done

lemma dmo_replaceable_or_arch_update [wp]:
  "\<lbrace>\<lambda>s. replaceable_or_arch_update s slot cap cap'\<rbrace>
  do_machine_op mo
  \<lbrace>\<lambda>r s. replaceable_or_arch_update s slot cap cap'\<rbrace>"
  unfolding replaceable_or_arch_update_def replaceable_def no_cap_to_obj_with_diff_ref_def
  apply (rule hoare_pre)
  apply (wps dmo_tcb_cap_valid do_machine_op_reachable_pg_cap)
  apply (rule hoare_vcg_prop)
  apply auto
  done

lemma replaceable_or_arch_update_pg:
  " (case (vs_cap_ref (cap.ArchObjectCap (arch_cap.PageCap word fun vm_pgsz y))) of None \<Rightarrow> True | Some ref \<Rightarrow> \<not> (ref \<unrhd> word) s)
  \<longrightarrow> replaceable_or_arch_update s slot (cap.ArchObjectCap (arch_cap.PageCap word fun vm_pgsz None))
                (cap.ArchObjectCap (arch_cap.PageCap word fun vm_pgsz y))"
  unfolding replaceable_or_arch_update_def
  apply (auto simp: is_cap_simps is_arch_update_def cap_master_cap_simps)
  done

lemma store_pde_arch_objs_invalid:
  "\<lbrace>valid_arch_objs\<rbrace> store_pde p ARM_Structs_A.pde.InvalidPDE \<lbrace>\<lambda>_. valid_arch_objs\<rbrace>"
  apply (wp store_pde_arch_objs_unmap)
  apply (simp add: pde_ref_def)
  done

lemma store_pde_executable_arch_objs_invalid [wp]:
  "\<lbrace>executable_arch_objs\<rbrace> store_pde p ARM_Structs_A.pde.InvalidPDE \<lbrace>\<lambda>_. executable_arch_objs\<rbrace>"
  apply (wp)
  apply (simp)
  done

lemma mapM_x_store_pde_InvalidPDE_empty2:
  "\<lbrace>invs and (\<lambda>s. word \<notin> global_refs s) and K (is_aligned word pd_bits) and K (slots = (map (\<lambda>a. (a << 2) + word) [0.e.(kernel_base >> 20) - 1])) \<rbrace>
  mapM_x (\<lambda>x. store_pde x ARM_Structs_A.pde.InvalidPDE) slots
  \<lbrace>\<lambda>_ s. obj_at (empty_table (set (arm_global_pts (arch_state s)))) word s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply simp
  apply (wp mapM_x_store_pde_InvalidPDE_empty [unfolded swp_def])
  apply simp
  done

crunch valid_cap: invalidate_tlb_by_asid "valid_cap cap"
crunch inv: page_table_mapped "P"
crunch valid_objs[wp]: invalidate_tlb_by_asid "valid_objs"
crunch valid_asid_table[wp]: do_machine_op
  "\<lambda>s. valid_asid_table (arm_asid_table (arch_state s)) s"

lemma mapM_x_swp_store_invalid_pte_invs:
  "\<lbrace>invs and (\<lambda>s. \<exists>slot. cte_wp_at
             (\<lambda>c. (\<lambda>x. x && ~~ mask pt_bits) ` set slots \<subseteq> obj_refs c \<and>
                  is_pt_cap c) slot s)\<rbrace>
  mapM_x (\<lambda>x. store_pte x ARM_Structs_A.pte.InvalidPTE) slots \<lbrace>\<lambda>_. invs\<rbrace>"
  by (simp add:
    mapM_x_swp_store_pte_invs[unfolded swp_def,
      where pte=ARM_Structs_A.pte.InvalidPTE, simplified])

lemma mapM_x_swp_store_invalid_pde_invs:
  "\<lbrace>invs and
   (\<lambda>s. \<forall>sl\<in>set slots.
         ucast (sl && mask pd_bits >> 2) \<notin> kernel_mapping_slots) and
   (\<lambda>s. \<forall>sl\<in>set slots. sl && ~~ mask pd_bits \<notin> global_refs s)\<rbrace>
     mapM_x (\<lambda>x. store_pde x ARM_Structs_A.pde.InvalidPDE) slots
   \<lbrace>\<lambda>rv. invs \<rbrace>"
  apply (simp add:mapM_x_mapM)
  apply (wp mapM_swp_store_pde_invs_unmap[unfolded swp_def,
              where pde=ARM_Structs_A.pde.InvalidPDE, simplified])
  done

lemma arch_cap_recycle_replaceable:
  notes split_if [split del]
  and   hoare_post_taut [simp del]
  and   arch_reset_mem_mapping.simps [simp del]
  shows "\<lbrace>cte_wp_at (op = (cap.ArchObjectCap cap)) slot
    and invs
    and (\<lambda>s. is_final = is_final_cap' (cap.ArchObjectCap cap) s)
    and (\<lambda>s. \<forall>ptr m. cap = arch_cap.PageDirectoryCap ptr m \<longrightarrow> ptr \<notin> global_refs s)\<rbrace>
     arch_recycle_cap is_final cap
   \<lbrace>\<lambda>rv s. replaceable_or_arch_update s slot
            (cap.ArchObjectCap rv) (cap.ArchObjectCap cap)\<rbrace>"
  apply (simp add: arch_recycle_cap_def)
  apply (rule hoare_pre)
   apply (wpc, simp_all only: prod_case_beta cong: option.case_cong imp_cong)
       apply ((wp | simp add: replaceable_or_arch_update_same
                              arch_reset_mem_mapping.simps)+)[3]
      -- "PageCase"
      apply ((simp only:
       | wp arch_finalise_case_no_lookup
            arch_finalise_pt_pd_empty page_table_mapped_inv
            invalidate_tlb_by_asid_pspace_aligned
            invalidate_tlb_by_asid_valid_cap do_machine_op_valid_cap
            final_cap_lift option_cases_weak_wp
            mapM_x_wp' [OF store_pte_caps_of_state]
            mapM_x_wp' [OF store_pte_cte_wp_at]
            mapM_x_wp' [OF store_pte_aligned]
            mapM_x_wp' [OF store_pte_typ_ats(14)]
            mapM_x_store_pte_valid_arch_objs
            mapM_x_swp_store_empty_table_set[unfolded swp_def]
            hoare_vcg_all_lift hoare_vcg_const_imp_lift
       | strengthen replaceable_reset_pt_strg [OF refl] impI[OF invs_valid_objs]
                    replaceable_or_arch_update_pg impI[OF invs_valid_asid_table]
       | simp add: replaceable_or_arch_update_same swp_def if_distrib
                   if_apply_def2
       | wp_once hoare_drop_imps )+)[1]
      apply (simp add:arch_finalise_cap_def)
      apply ((wpc | wp valid_option_case_post_wp unmap_page_unmapped
                      hoare_vcg_all_lift hoare_vcg_imp_lift K_valid)+)[2]
      -- "PagetableCap case"
    apply ((simp only: replaceable_or_arch_update_pg
       | wp arch_finalise_case_no_lookup arch_finalise_pt_pd_empty
            page_table_mapped_inv invalidate_tlb_by_asid_pspace_aligned
            invalidate_tlb_by_asid_valid_cap do_machine_op_valid_cap
            final_cap_lift option_cases_weak_wp
            mapM_x_swp_store_invalid_pte_invs
            mapM_x_wp' [OF store_pte_caps_of_state]
            mapM_x_wp' [OF store_pte_cte_wp_at]
            mapM_x_wp' [OF store_pte_aligned]
            mapM_x_wp' [OF store_pte_typ_ats(14)]
            mapM_x_store_pte_valid_arch_objs
            mapM_x_swp_store_empty_table_set[unfolded swp_def]
            hoare_vcg_all_lift hoare_vcg_const_imp_lift
       | strengthen replaceable_reset_pt_strg [OF refl] impI[OF invs_valid_objs]
                    impI[OF invs_valid_asid_table]
       | simp add: replaceable_or_arch_update_same swp_def if_distrib
                   if_apply_def2
       | wp_once hoare_drop_imps)+)[1]
   -- "PageDirectory"
   apply ((wp arch_finalise_case_no_lookup arch_finalise_pt_pd_empty
      invalidate_tlb_by_asid_pspace_aligned invalidate_tlb_by_asid_valid_cap
      do_machine_op_valid_cap find_pd_for_asid_inv mapM_x_swp_store_invalid_pde_invs
      final_cap_lift option_cases_weak_wp
      mapM_x_wp' [OF store_pde_caps_of_state]
      mapM_x_wp' [OF store_pde_cte_wp_at]
      mapM_x_wp' [OF store_pde_aligned]
      mapM_x_wp' [OF store_pde_arch_objs_invalid]
      mapM_x_wp' [OF store_pde_typ_ats(14)]
      mapM_x_store_pde_InvalidPDE_empty2
      hoare_vcg_all_lift hoare_vcg_const_imp_lift
      | strengthen replaceable_reset_pd_strg [OF refl] impI[OF invs_valid_asid_table]
        impI[OF invs_valid_objs]
      | simp add: replaceable_or_arch_update_same swp_def if_distrib
        if_apply_def2
      | wp_once hoare_drop_imps )+)[1]
  apply (clarsimp simp: cte_wp_at_caps_of_state invs_pspace_alignedI
                        invs_arch_objs)
  apply (frule (1) caps_of_state_valid [OF _ invs_valid_objs])
  apply (cases cap, simp_all add: is_cap_simps replaceable_or_arch_update_same)
  -- "pt"
    apply (clarsimp simp: vs_cap_ref_def valid_cap_simps invs_psp_aligned
                          invs_arch_objs invs_valid_objs invs_valid_asid_table
                   split: option.splits vmpage_size.splits)
   apply (case_tac slot)
   apply (clarsimp simp: valid_cap_simps)
   apply (case_tac "\<not> is_final_cap' (cap.ArchObjectCap (arch_cap.PageTableCap word option)) s")
    apply clarsimp
   apply (clarsimp simp:conj_ac)
   apply (intro conjI)
      apply (fastforce intro!: word_aligned_pt_slots
                       elim!: caps_of_state_aligned_page_table)
     apply (fastforce intro: word32_ucast_enumerates_word8
                     elim!: caps_of_state_aligned_page_table)
    apply (rule_tac x = "a" in exI, rule_tac x = "b" in exI)
    apply (clarsimp simp: cap_aligned_def)
    apply (erule word_aligned_pt_slots[rotated])
    apply (simp add: pt_bits_def pageBits_def)
   apply (rule_tac x = "a" in exI, rule_tac x = "b" in exI)
   apply (fastforce intro!: word_aligned_pt_slots
                    elim!: caps_of_state_aligned_page_table)
  apply (case_tac "\<not> is_final_cap' (cap.ArchObjectCap (arch_cap.PageDirectoryCap word option)) s")
   apply clarsimp
  apply (frule caps_of_state_valid)
   apply fastforce
  apply (clarsimp simp:cap_aligned_def valid_cap_simps conj_ac)
  -- "pd"
  apply (frule caps_of_state_aligned_page_directory)
   apply simp
  apply (clarsimp simp:valid_cap_simps cap_aligned_def pd_bits_def pageBits_def)
  apply (auto simp: pd_shifting_kernel_mapping_slots
                      [unfolded pd_bits_def pageBits_def,simplified]
                    pd_shifting_global_refs
                      [unfolded pd_bits_def pageBits_def,simplified])
  done

lemmas thread_set_final_cap =
    final_cap_lift [OF thread_set_caps_of_state_trivial]


schematic_lemma no_cap_to_obj_with_diff_ref_lift:
  "\<lbrace>\<lambda>s. ?P (caps_of_state s)\<rbrace> f \<lbrace>\<lambda>rv s. ?P (caps_of_state s)\<rbrace>
   \<Longrightarrow> \<lbrace>no_cap_to_obj_with_diff_ref cap S\<rbrace>
          f
      \<lbrace>\<lambda>rv. no_cap_to_obj_with_diff_ref cap S\<rbrace>"
  by (simp add: no_cap_to_obj_with_diff_ref_def
                cte_wp_at_caps_of_state)


lemmas thread_set_no_cap_obj_ref_trivial
    = no_cap_to_obj_with_diff_ref_lift [OF thread_set_caps_of_state_trivial]


lemma cap_not_in_valid_global_refs:
  "\<lbrakk>invs s; caps_of_state s p = Some cap\<rbrakk> \<Longrightarrow>
   obj_refs cap \<inter> global_refs s = {}"
  apply (drule invs_valid_global_refs)
  apply (simp add: valid_global_refs_def valid_refs_def)
  apply (case_tac p, simp)
  apply (erule_tac x=a in allE, erule_tac x=b in allE)
  apply (clarsimp simp: cte_wp_at_caps_of_state cap_range_def)
  apply blast
  done

lemma gts_wp:
  "\<lbrace>\<lambda>s. \<forall>st. st_tcb_at (op = st) t s \<longrightarrow> P st s\<rbrace> get_thread_state t \<lbrace>P\<rbrace>"
  unfolding get_thread_state_def
  apply (wp thread_get_wp')
  apply clarsimp
  apply (drule spec, erule mp)
  apply (clarsimp simp: st_tcb_at_def obj_at_def)
  done

lemma cap_recycle_replaceable:
  notes hoare_post_taut [simp del]
  shows "\<lbrace>invs and cte_wp_at (op = cap) slot and zombies_final
    and valid_objs and K (cap \<noteq> cap.NullCap)
    and (\<lambda>s. is_final = is_final_cap' cap s)\<rbrace>
     recycle_cap is_final cap
   \<lbrace>\<lambda>rv s. replaceable_or_arch_update s slot rv cap \<and> rv \<noteq> cap.NullCap\<rbrace>"
  apply (simp add: recycle_cap_def)
  apply (rule hoare_pre)
   apply (wpc, simp_all add: replaceable_or_arch_update_same)
            apply (wp | simp add: replaceable_or_arch_update_same)+
            -- "Zombie"
    apply (simp add: recycle_cap_def replaceable_def replaceable_or_arch_update_def)
    apply (wpc, simp_all)[1]
    apply (wp gts_wp static_imp_wp
               hoare_vcg_disj_lift thread_set_final_cap
               ball_tcb_cap_casesI hoare_vcg_const_Ball_lift
               thread_set_cte_wp_at_trivial
               thread_set_caps_of_state_trivial
               thread_set_no_cap_obj_ref_trivial
               arch_cap_recycle_replaceable
               hoare_vcg_all_lift
                 | simp add: tcb_registers_caps_merge_def tcb_not_empty_table reachable_pg_cap_def
                 | simp cong: rev_conj_cong
                 | strengthen tcb_cap_valid_imp'
                 | simp add: cte_wp_at_caps_of_state
                 | wp_once hoare_use_eq [OF thread_set_arch thread_set_obj_at_impossible])+
    -- "last imp goal"
  apply (simp add: replaceable_or_arch_update_same)
  apply (cases cap, simp_all add: is_cap_simps)
   apply (clarsimp simp: is_cap_simps obj_irq_refs_subset is_pt_cap_def is_pd_cap_def
                         vs_cap_ref_def cap_range_def
                   cong: rev_conj_cong)
   apply (frule(1) zombies_finalD [OF caps_of_state_cteD], clarsimp simp: is_cap_simps)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (frule caps_of_state_valid_cap, clarsimp+)
   apply (case_tac option, simp_all)[1]
   -- "None case"
    apply clarsimp
    apply (intro conjI)
       apply (clarsimp simp: valid_cap_def)
       apply (drule(1) order_less_le_trans)
       apply (drule tcb_cap_cases_lt)
       apply (simp add: nat_to_cref_unat_of_bl')

      apply (clarsimp simp: cte_wp_at_caps_of_state
                            tcb_cap_cases_def is_cap_simps
                     split: Structures_A.thread_state.split_asm)
     apply (simp add: valid_ipc_buffer_cap_def)
    apply (erule (1) no_cap_to_obj_with_diff_ref_finalI [OF caps_of_state_cteD])
    apply simp
    -- "Some case"
   apply (intro conjI)
     apply (clarsimp simp: cte_wp_at_caps_of_state
                           tcb_cap_cases_def is_cap_simps
                    split: Structures_A.thread_state.split_asm)
    apply (simp add: valid_ipc_buffer_cap_def)
   apply (erule (1) no_cap_to_obj_with_diff_ref_finalI [OF caps_of_state_cteD])
   apply simp
  -- "arch cap"
  apply clarsimp
  apply (drule cap_not_in_valid_global_refs)
   apply simp
  apply (simp add: global_refs_def)
  done

crunch caps_of_state[wp]: recycle_cap "\<lambda>s. P (caps_of_state s)"
  (ignore: filterM set_object thread_set clearMemory recycle_cap_ext
     simp: filterM_mapM crunch_simps tcb_registers_caps_merge_def
       wp: crunch_wps thread_set_caps_of_state_trivial2)

lemmas recycle_cap_cte_wp_at[wp] =
  hoare_cte_wp_caps_of_state_lift [OF recycle_cap_caps_of_state]

crunch irq_node[wp]: recycle_cap "\<lambda>s. P (interrupt_irq_node s)"
  (ignore: filterM clearMemory recycle_cap_ext
     simp: filterM_mapM crunch_simps
       wp: crunch_wps)

lemmas recycle_cap_cte_cap_to[wp] =
  ex_cte_cap_to_pres [OF recycle_cap_cte_wp_at recycle_cap_irq_node]

crunch typ_at[wp]: recycle_cap "\<lambda>s. P (typ_at T p s)"
  (ignore: filterM clearMemory recycle_cap_ext
     simp: filterM_mapM crunch_simps
       wp: crunch_wps)


lemmas recycle_cap_valid_cap = valid_cap_typ [OF recycle_cap_typ_at]


lemma set_asid_pool_obj_at_ptr:
  "\<lbrace>\<lambda>s. P (ArchObj (arch_kernel_obj.ASIDPool mp))\<rbrace>
     set_asid_pool ptr mp
   \<lbrace>\<lambda>rv s. obj_at P ptr s\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: obj_at_def)
  done


lemma zombies_final_arch [simp]:
  "zombies_final (arch_state_update f s) = zombies_final s"
  by (simp add: zombies_final_def is_final_cap'_def)


lemma state_refs_of_arch [simp]:
  "state_refs_of (arch_state_update f s) = state_refs_of s"
  by (simp add: state_refs_of_def)


lemma valid_global_refs_table [simp]:
  "valid_global_refs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table'\<rparr>\<rparr>) = valid_global_refs s"
  by (simp add: valid_global_refs_def global_refs_def)


lemma valid_arch_state_table_strg:
  "valid_arch_state s \<and> asid_pool_at p s \<and>
   Some p \<notin> arm_asid_table (arch_state s) ` (dom (arm_asid_table (arch_state s)) - {x}) \<longrightarrow>
   valid_arch_state (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table (arch_state s)(x \<mapsto> p)\<rparr>\<rparr>)"
  apply (clarsimp simp: valid_arch_state_def valid_asid_table_def ran_def)
  apply (rule conjI, fastforce)
  apply (erule inj_on_fun_upd_strongerI)
  apply simp
  done


lemma valid_irq_node_arch [simp]:
  "valid_irq_node (arch_state_update f s) = valid_irq_node s"
  by (simp add: valid_irq_node_def)


lemma valid_table_caps_table [simp]:
  "valid_table_caps (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table'\<rparr>\<rparr>) = valid_table_caps s"
  by (simp add: valid_table_caps_def)


lemma valid_global_objs_table [simp]:
  "valid_global_objs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table'\<rparr>\<rparr>) = valid_global_objs s"
  by (simp add: valid_global_objs_def)


lemma valid_kernel_mappings [simp]:
  "valid_kernel_mappings (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table'\<rparr>\<rparr>) = valid_kernel_mappings s"
  by (simp add: valid_kernel_mappings_def)


lemma vs_asid_refs_updateD:
  "(ref', p') \<in> vs_asid_refs (table (x \<mapsto> p))
  \<Longrightarrow> (ref',p') \<in> vs_asid_refs table \<or> (ref' = [VSRef (ucast x) None] \<and> p' = p)"
  apply (clarsimp simp: vs_asid_refs_def graph_of_def split: split_if_asm)
  apply (rule_tac x="(a,p')" in image_eqI)
   apply auto
  done


lemma vs_lookup1_arch [simp]:
  "vs_lookup1 (arch_state_update f s) = vs_lookup1 s"
  by (simp add: vs_lookup1_def)


lemma vs_lookup_empty_table:
  "(rs \<rhd> q)
  (s\<lparr>kheap := kheap s(p \<mapsto> ArchObj (arch_kernel_obj.ASIDPool empty)),
     arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table (arch_state s)(x \<mapsto> p)\<rparr>\<rparr>) \<Longrightarrow>
   (rs \<rhd> q) s \<or> (rs = [VSRef (ucast x) None] \<and> q = p)"
  apply (erule vs_lookupE)
  apply clarsimp
  apply (drule vs_asid_refs_updateD)
  apply (erule disjE)
   apply (drule rtranclD)
   apply (erule disjE)
    apply clarsimp
    apply (fastforce simp: vs_lookup_def)
   apply clarsimp
   apply (drule trancl_sub_lift [rotated])
    prefer 2
    apply (rule vs_lookup_trancl_step)
     prefer 2
     apply assumption
    apply (fastforce simp: vs_lookup_def)
   apply (clarsimp simp: obj_at_def vs_lookup1_def vs_refs_def
                  split: split_if_asm)
  apply clarsimp
  apply (drule rtranclD)
  apply (erule disjE)
   apply clarsimp
  apply clarsimp
  apply (drule tranclD)
  apply clarsimp
  apply (drule vs_lookup1D)
  apply (clarsimp simp: obj_at_def vs_refs_def)
  done


lemma vs_lookup_pages_empty_table:
  "(rs \<unrhd> q)
  (s\<lparr>kheap := kheap s(p \<mapsto> ArchObj (arch_kernel_obj.ASIDPool empty)),
     arch_state := arch_state s\<lparr>arm_asid_table := arm_asid_table (arch_state s)(x \<mapsto> p)\<rparr>\<rparr>) \<Longrightarrow>
   (rs \<unrhd> q) s \<or> (rs = [VSRef (ucast x) None] \<and> q = p)"
  apply (subst (asm) vs_lookup_pages_def)
  apply (clarsimp simp: Image_def)
  apply (drule vs_asid_refs_updateD)
  apply (erule disjE)
   apply (drule rtranclD)
   apply (erule disjE)
    apply clarsimp
    apply (fastforce simp: vs_lookup_pages_def)
   apply clarsimp
   apply (drule trancl_sub_lift [rotated])
    prefer 2
    apply (rule vs_lookup_pages_trancl_step)
     prefer 2
     apply assumption
    apply (fastforce simp: vs_lookup_pages_def)
   apply (clarsimp simp: obj_at_def vs_lookup_pages1_def vs_refs_pages_def
                  split: split_if_asm)
  apply clarsimp
  apply (drule rtranclD)
  apply (erule disjE)
   apply clarsimp
  apply clarsimp
  apply (drule tranclD)
  apply clarsimp
  apply (drule vs_lookup_pages1D)
  apply (clarsimp simp: obj_at_def vs_refs_pages_def)
  done


(* yes, it's ugly, but it works.. *)
lemma set_asid_pool_empty_table_objs:
  "\<lbrace>valid_arch_objs and asid_pool_at p\<rbrace>
  set_asid_pool p empty
   \<lbrace>\<lambda>rv s. valid_arch_objs
             (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table :=
                arm_asid_table (arch_state s)(asid_high_bits_of word2 \<mapsto> p)\<rparr>\<rparr>)\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: obj_at_def valid_arch_objs_def
                  simp del: fun_upd_apply
                  split: Structures_A.kernel_object.splits arch_kernel_obj.splits)
  apply (rule valid_arch_obj_same_type)
    prefer 2
    apply simp
   prefer 2
   apply (simp add: a_type_def)
  apply (clarsimp simp add: a_type_def split: split_if_asm)
  apply (erule_tac x=pa in allE)
  apply (erule impE)
   apply (drule vs_lookup_empty_table)
   apply fastforce
  apply simp
  done


lemma set_asid_pool_executable_arch_objs [wp]:
  "\<lbrace>executable_arch_objs and asid_pool_at p\<rbrace> 
  set_asid_pool p empty 
   \<lbrace>\<lambda>rv. executable_arch_objs\<rbrace>"
  apply (simp add: set_asid_pool_def)
  apply (wp get_object_wp set_object_executable_arch_objs)
  apply (clarsimp simp: obj_at_def)
  apply (clarsimp simp: a_type_def split: Structures_A.kernel_object.splits arch_kernel_obj.splits)
  done

lemma set_asid_pool_empty_table_lookup:
  "\<lbrace>valid_vs_lookup and asid_pool_at p and
    (\<lambda>s. \<exists>p'. caps_of_state s p' = Some (cap.ArchObjectCap (arch_cap.ASIDPoolCap p base)))\<rbrace>
  set_asid_pool p empty
   \<lbrace>\<lambda>rv s. valid_vs_lookup
             (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table :=
                arm_asid_table (arch_state s)(asid_high_bits_of base \<mapsto> p)\<rparr>\<rparr>)\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: obj_at_def valid_vs_lookup_def
                  simp del: fun_upd_apply)
  apply (drule vs_lookup_pages_empty_table)
  apply (erule disjE)
   apply (fastforce simp: caps_of_state_after_update[folded fun_upd_apply]
                         obj_at_def)
  apply clarsimp
  apply (rule_tac x=a in exI)
  apply (rule_tac x=b in exI)
  apply (simp add: caps_of_state_after_update [folded fun_upd_apply] obj_at_def)
  apply (simp add: vs_cap_ref_def)
  done


lemma set_asid_pool_empty_valid_asid_map:
  "\<lbrace>\<lambda>s. valid_asid_map s \<and> asid_pool_at p s
       \<and> (\<forall>asid'. \<not> ([VSRef asid' None] \<rhd> p) s)
       \<and> (\<forall>p'. \<not> ([VSRef (ucast (asid_high_bits_of base)) None] \<rhd> p') s)\<rbrace>
       set_asid_pool p empty
   \<lbrace>\<lambda>rv s. valid_asid_map (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table :=
                 arm_asid_table (arch_state s)(asid_high_bits_of base \<mapsto> p)\<rparr>\<rparr>)\<rbrace>"
  apply (simp add: set_asid_pool_def set_object_def)
  apply (wp get_object_wp)
  apply (clarsimp simp: valid_asid_map_def pd_at_asid_def
                 dest!: graph_ofD
                 split: Structures_A.kernel_object.split_asm
                        arch_kernel_obj.split_asm)
  apply (drule bspec, erule graph_ofI)
  apply (clarsimp dest!: vs_lookup_2ConsD vs_lookup1D)
  apply (case_tac "p = pa")
   apply simp
  apply (clarsimp elim!: vs_lookup_atE)
  apply (rule vs_lookupI[rotated])
   apply (rule r_into_rtrancl)
   apply (rule_tac p=pa in vs_lookup1I)
     apply (simp add: obj_at_def)
    apply assumption
   apply simp
  apply (rule vs_asid_refsI)
  apply clarsimp
  apply (drule vs_asid_refsI)
  apply (drule vs_lookupI, rule rtrancl_refl)
  apply simp
  done


(* FIXME: move *)
lemma vms_arch_state_update[simp]:
  "valid_machine_state (arch_state_update f s) = valid_machine_state s"
  by (simp add: valid_machine_state_def)


lemma set_asid_pool_invs_table:
  "\<lbrace>\<lambda>s. invs s \<and> asid_pool_at p s
       \<and> (\<exists>p'. caps_of_state s p' = Some (cap.ArchObjectCap (arch_cap.ASIDPoolCap p base)))
       \<and> (\<not> ([VSRef (ucast (asid_high_bits_of base)) None] \<rhd> p) s)
       \<and> (\<forall>p'. \<not> ([VSRef (ucast (asid_high_bits_of base)) None] \<rhd> p') s)\<rbrace>
       set_asid_pool p empty
  \<lbrace>\<lambda>x s. invs (s\<lparr>arch_state := arch_state s\<lparr>arm_asid_table :=
                 arm_asid_table (arch_state s)(asid_high_bits_of base \<mapsto> p)\<rparr>\<rparr>)\<rbrace>"
  apply (simp add: invs_def valid_state_def valid_pspace_def valid_arch_caps_def)
  apply (rule hoare_pre)
   apply (wp valid_irq_node_typ set_asid_pool_typ_at
             set_asid_pool_empty_table_objs
             valid_irq_handlers_lift set_asid_pool_empty_table_lookup
             set_asid_pool_empty_valid_asid_map
          | strengthen valid_arch_state_table_strg)+
  apply (clarsimp simp: conj_ac)
  apply (rule context_conjI)
   apply clarsimp
   apply (frule valid_vs_lookupD[OF vs_lookup_pages_vs_lookupI], clarsimp)
   apply clarsimp
   apply (drule obj_ref_elemD)
   apply (frule(2) unique_table_refsD,
          unfold obj_refs.simps aobj_ref.simps Option.set.simps,
          assumption)
   apply (clarsimp simp:vs_cap_ref_def table_cap_ref_def
     split:cap.split_asm arch_cap.split_asm)
  apply clarsimp
  apply (drule vs_asid_refsI)
  apply (drule vs_lookupI, rule rtrancl_refl)
  apply simp
  done


lemma delete_asid_pool_unmapped2:
  "\<lbrace>\<lambda>s. (base' = base \<and> ptr' = ptr)
         \<or> \<not> ([VSRef (ucast (asid_high_bits_of base')) None] \<rhd> ptr') s\<rbrace>
     delete_asid_pool base ptr
   \<lbrace>\<lambda>rv s. \<not> ([VSRef (ucast (asid_high_bits_of base')) None] \<rhd> ptr') s\<rbrace>"
  (is "valid ?P ?f (\<lambda>rv. ?Q)")
  apply (cases "base = base' \<and> ptr = ptr'")
   apply simp
   apply (wp delete_asid_pool_unmapped)
  apply (simp add: delete_asid_pool_def)
  apply wp
     apply (rule_tac Q="\<lambda>rv s. ?Q s \<and> asid_table = arm_asid_table (arch_state s)"
                in hoare_post_imp)
      apply (clarsimp simp: fun_upd_def[symmetric])
      apply (drule vs_lookup_clear_asid_table[rule_format])
      apply simp
     apply (wp mapM_wp')
     apply clarsimp
    apply wp
  apply clarsimp
  done


lemma page_table_mapped_wp_weak:
  "\<lbrace>\<lambda>s. Q None s \<and> (\<forall>x. Q (Some x) s)\<rbrace>
     page_table_mapped asid vptr pt
   \<lbrace>Q\<rbrace>"
  (is "\<lbrace>?P\<rbrace> page_table_mapped asid vptr pt \<lbrace>Q\<rbrace>")
  apply (simp add: page_table_mapped_def)
  apply (rule hoare_pre)
   apply (wp get_pde_wp | wpc)+
   apply (rule_tac Q'="\<lambda>_. ?P" in hoare_post_imp_R)
    apply wp
   apply clarsimp
  apply simp
  done


crunch arm_global_pd[wp]: invalidate_tlb_by_asid
           "\<lambda>s. P (arm_global_pd (arch_state s))"


crunch global_refs_invs[wp]: invalidate_tlb_by_asid
           "\<lambda>s. P (global_refs s)"


lemma pd_bits_14: "pd_bits = 14" by (simp add: pd_bits_def pageBits_def)


lemma arch_recycle_slots_kernel_mapping_slots:
  "is_aligned pd pd_bits \<and> sl \<le> (kernel_base >> 20) - 1 \<longrightarrow>
     ucast ((sl << 2) && mask pd_bits >> 2)
               \<notin> kernel_mapping_slots"
  apply (clarsimp simp: kernel_mapping_slots_def
                        kernel_base_shift_cast_le[symmetric]
                        ucast_ucast_mask_shift_helper)
  apply (simp add: pd_bits_14)
  apply (subst(asm) iffD2[OF mask_eq_iff_w2p])
    apply (simp add: word_size)
   apply (rule shiftl_less_t2n)
    apply (erule order_le_less_trans, simp add: kernel_base_def)
   apply simp
  apply (subst(asm) shiftl_shiftr_id)
    apply (simp add: word_bits_def)
   apply (erule order_le_less_trans, simp add: kernel_base_def word_bits_def)
  apply (drule minus_one_helper5[rotated])
   apply (simp add: kernel_base_def)
  apply simp
  done

lemma clearMemory_valid_irq_states:
  "\<lbrace>\<lambda>m. valid_irq_states (s\<lparr>machine_state := m\<rparr>)\<rbrace> clearMemory w x
   \<lbrace>\<lambda>a b. valid_irq_states (s\<lparr>machine_state := b\<rparr>)\<rbrace>"
  apply(simp add: valid_irq_states_def | wp | simp add: no_irq_clearMemory)+
  done


(* FIXME: move *)
lemma clearMemory_invs[wp]:
  "\<lbrace>invs\<rbrace> do_machine_op (clearMemory w sz) \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (simp add: do_machine_op_def split_def)
  apply wp
  apply (clarsimp simp: invs_def valid_state_def clearMemory_vms cur_tcb_def)
  apply(erule use_valid[OF _ clearMemory_valid_irq_states], simp)
  done


(* FIXME: move *)
lemma dmo_bind_return:
  "\<lbrace>P\<rbrace> do_machine_op f \<lbrace>\<lambda>_. Q\<rbrace> \<Longrightarrow>
   \<lbrace>P\<rbrace> do_machine_op (do _ \<leftarrow> f; return x od) \<lbrace>\<lambda>_. Q\<rbrace>"
  by (simp add: do_machine_op_def bind_def return_def valid_def select_f_def
                     split_def)


lemma arch_recycle_cap_invs:
  notes split_if [split del]
  shows "\<lbrace>invs and cte_wp_at (op = (cap.ArchObjectCap cap)) slot\<rbrace>
         arch_recycle_cap is_final cap
         \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: arch_recycle_cap_def)
  apply (rule hoare_pre)
   apply ((wp set_asid_pool_invs_table dmo_ccr_invs
             mapM_x_swp_store_pde_invs_unmap
             hoare_vcg_all_lift delete_asid_pool_unmapped2
             page_table_mapped_wp_weak
             mapM_x_wp'[where P="\<lambda>s. Q (global_refs s)", standard]
             mapM_x_wp'[where P="\<lambda>s. Q (typ_at T p s)", standard]
             store_pte_typ_at static_imp_wp
           | simp add: fun_upd_def[symmetric] cte_wp_at_caps_of_state
                       valid_cap_simps
                  split del: split_if
           | wpc)+)
  apply (case_tac slot)
  apply clarsimp
  apply (frule caps_of_state_valid_cap, clarsimp)
  apply (frule valid_global_refsD2, clarsimp)
  apply (frule valid_cap_aligned, clarsimp simp: cap_aligned_def)
  apply (intro conjI)
     (* ASID pool case *)
     apply ((fastforce simp: valid_cap_def mask_def split: split_if
                     elim!: vs_lookup_atE)+)[2]
   (* PageTable case*)
   apply clarsimp
   apply (subgoal_tac "(\<exists>a b cap.
               caps_of_state s (a, b) = Some cap \<and>
               (\<lambda>x. x && ~~ mask pt_bits) `
               set [x , x + 4 .e. x + 2 ^ pt_bits - 1]
               \<subseteq> obj_refs cap \<and>
               is_pt_cap cap)")
    apply (case_tac xa)
     apply simp+
    apply (clarsimp simp: valid_cap_simps)
   apply (clarsimp simp: is_cap_simps valid_cap_simps mask_def asid_bits_def
     vmsz_aligned_def upto_enum_step_def pt_bits_def pageBits_def is_cap_simps
     image_image word32_shift_by_2 split: split_if_asm)
    apply (erule order_le_less_trans, simp)+
   apply (rule_tac x=a in exI, rule_tac x=b in exI)
   apply (clarsimp simp: upto_enum_step_def pt_bits_def pageBits_def is_cap_simps
                         image_image word32_shift_by_2 split: split_if_asm)
  apply (frule_tac d="xb << 2" in is_aligned_add_helper)
    apply (rule shiftl_less_t2n)
     apply (erule order_le_less_trans, simp)
    apply (simp_all add: mask_def)[3]
  (* PageDirectory case *)
  apply (intro allI impI)
  apply (subgoal_tac "
           (\<forall>sl\<le>(kernel_base >> 20) - 1.
               ucast (x + (sl << 2) && 2 ^ pd_bits - 1 >> 2)
               \<notin> kernel_mapping_slots) \<and>
           (\<forall>sl\<le>(kernel_base >> 20) - 1.
               x + (sl << 2) && ~~ (2 ^ pd_bits - 1) \<notin> global_refs s)")
  apply (clarsimp simp: valid_cap_def cap_aligned_def pd_bits_14[symmetric]
                        cap_range_def pde_ref_def
                        mask_add_aligned field_simps
                        split: option.splits)
  apply (intro allI conjI impI)
   apply (simp add: kernel_base_def mask_def pd_bits_def pageBits_def)
   apply (frule_tac d="sl << 2" in is_aligned_add_helper)
    apply (rule shiftl_less_t2n)
     apply (erule order_le_less_trans, simp)
    apply (simp add: mask_def kernel_mapping_slots_def
        kernel_base_def word_le_make_less not_le)
   apply (simp add: mask_def kernel_mapping_slots_def kernel_base_def
      word_le_make_less not_le)
   apply (rule le_less_trans[rotated])
    apply (frule_tac 'a = "12" in ucast_mono[where y = "0xF00::word32"])
     apply (simp+)[2]
   apply (intro eq_refl  arg_cong[where f = ucast] shiftl_shiftr_id)
    apply ((simp add:word_bits_def)+)[2]
   apply unat_arith
  apply (simp add: kernel_base_def mask_def pd_bits_def pageBits_def)
  apply (frule_tac d="sl << 2" in is_aligned_add_helper)
   apply (rule shiftl_less_t2n)
    apply (erule order_le_less_trans)
    apply (simp add: word_bits_def mask_def)+
   apply (drule cap_not_in_valid_global_refs)
  apply (simp add: obj_refs_def)+
  done

lemma st_tcb_at_idle_thread:
  "\<lbrakk> st_tcb_at P (idle_thread s) s; valid_idle s \<rbrakk>
        \<Longrightarrow> P Structures_A.IdleThreadState"
  by (clarsimp simp: valid_idle_def st_tcb_def2)


lemma tcb_state_merge_tcb_state_default:
  "tcb_state (tcb_registers_caps_merge tcb tcb') = tcb_state tcb"
  "tcb_state default_tcb = Structures_A.Inactive"
  by (auto simp add: tcb_registers_caps_merge_def default_tcb_def)


(*Lift hoare triples from an instantiation to the nondeterministic hoare triple version.
  Since bcorres states that f refines g with respect to the non_extended state,
  we can prove the hoare triple over the more abstract g and put undefined
  values into the extended_state*)

lemma use_bcorres: "bcorres f g \<Longrightarrow> (\<And>f f'.
        \<lbrace>P o (trans_state f)\<rbrace> g \<lbrace>\<lambda>r s. Q r (trans_state f' s)\<rbrace>)\<Longrightarrow> \<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace>"
  apply (clarsimp simp add: bcorres_underlying_def s_bcorres_underlying_def valid_def)
  apply (drule_tac x="\<lambda>_.exst s" in meta_spec)
  apply (drule_tac x="\<lambda>_.exst b" in meta_spec)
  apply (drule_tac x="truncate_state s" in spec)
  apply (simp add: trans_state_update')
  apply (drule_tac x="(a,truncate_state b)" in bspec)
  apply force
  apply (simp add:  trans_state_update')
  done


lemma dxo_noop: "do_extended_op f = (return () :: (unit,unit) s_monad)"
  apply (clarsimp simp add: do_extended_op_def bind_def gets_def get_def return_def
         select_f_def modify_def put_def mk_ef_def wrap_ext_op_unit_def)
  apply force
  done




lemma recycle_cap_invs:
  "\<lbrace>cte_wp_at (op = cap) slot and invs\<rbrace>
     recycle_cap is_final cap
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (cases cap, simp_all add: recycle_cap_def)
           apply ((wp | simp)+)[9]
   -- "Zombie"
   apply (case_tac option, simp_all)
    apply (rule hoare_seq_ext[rotated], rule assert_sp gts_sp)+
    apply (rule hoare_seq_ext)
     apply (wp, simp)[1]
    apply (rule use_bcorres[OF thread_set_bcorres])
    apply (simp add: o_def) (* Nothing cares about the extended state*)
    apply (simp add: thread_set_split_out_set_thread_state[where 'a="unit",simplified  gets_bind_ign dxo_noop bind_return_unit[symmetric]] tcb_registers_caps_merge_def) (*Use the nondeterministic version of set_thread_state and
                  go through refinement/bcorres *)
    apply (fold tcb_registers_caps_merge_def)
    apply (rule hoare_pre, wp sts_invs_minor)
     apply (simp add: cte_wp_at_caps_of_state
                      tcb_state_merge_tcb_state_default)
     apply (wp thread_set_no_change_tcb_state
               thread_set_caps_of_state_trivial2
               hoare_vcg_disj_lift hoare_vcg_all_lift
               thread_set_invs_trivial [OF ball_tcb_cap_casesI]
               has_reply_cap_cte_lift
                 | simp add: tcb_registers_caps_merge_def)+
       apply (simp add: default_tcb_def)
      apply (simp add: default_tcb_def tcb_registers_caps_merge_def
                       word_bits_def)
     apply (simp add: default_tcb_def tcb_registers_caps_merge_def)
    apply (clarsimp simp: cte_wp_at_caps_of_state default_tcb_def)
    apply (rule conjI, erule st_tcb_weakenE, (auto)[1])
    apply (frule_tac r="idle_thread s"
              in  valid_global_refsD [OF _ caps_of_state_cteD, rotated])
      apply (simp add: global_refs_def)
     apply clarsimp
    apply (strengthen reply_cap_doesnt_exist_strg)
    apply (fastforce simp: cap_range_def elim!: st_tcb_weakenE)
   apply (wp arch_recycle_cap_invs[where slot=slot] | simp)+
  done

lemma cap_recycle_cte_replaceable:
  "\<lbrace>cte_wp_at (op = cap) slot and zombies_final
    and valid_objs and K (cap \<noteq> cap.NullCap)
    and invs
    and (\<lambda>s. is_final = is_final_cap' cap s)\<rbrace>
     recycle_cap is_final cap
   \<lbrace>\<lambda>rv s. cte_wp_at (\<lambda>cap. replaceable_or_arch_update s slot rv cap) slot s\<rbrace>"
  apply (rule hoare_chain)
    apply (rule hoare_vcg_conj_lift)
     apply (rule cap_recycle_replaceable)
    apply (rule recycle_cap_cte_wp_at)
   apply fastforce
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  done

lemma page_table_pte_atE:
  "\<lbrakk> page_table_at p s; x < 2 ^ pt_bits;
             (x >> 2) << 2 = x; pspace_aligned s \<rbrakk>
       \<Longrightarrow> pte_at (p + x) s"
  apply (drule page_table_pte_atI[where x="x >> 2"], simp_all)
  apply (subst mask_eq_iff_w2p[symmetric])
   apply (simp add: pt_bits_def pageBits_def word_size)
  apply (rule word_eqI)
  apply (simp add: nth_shiftr word_size)
  apply (drule_tac x="Suc (Suc n)" in word_eqD [OF less_mask_eq])
  apply (simp add: word_size)
  apply arith
  done


crunch aligned[wp]: invalidate_tlb_by_asid "pspace_aligned"

crunch valid_arch_state[wp]: invalidate_tlb_by_asid "valid_arch_state"

(*FIXME: move *)
lemma corres_option_split:
  "\<lbrakk>v = v'; corres_underlying sr nf r P P' a c; (\<And>x. v = Some x \<Longrightarrow> corres_underlying sr nf r (Q x) (Q' x) (b x) (d x))\<rbrakk>
  \<Longrightarrow> corres_underlying sr nf r (option_case P Q v) (option_case P' Q' v') (option_case a b v) (option_case c d v')"
  by (cases v', simp_all)


lemma hoare_post_option_case_ext:
  "\<lbrace>R\<rbrace> f \<lbrace>\<lambda>rv s. option_case (P s) (\<lambda>rv'. Q rv' s) rv\<rbrace> \<Longrightarrow> \<lbrace>R\<rbrace> f \<lbrace>option_case P Q\<rbrace>"
  by (erule hoare_post_imp [rotated], simp split: option.splits)


lemma hoare_when_weak_wp:
  "\<lbrace>P\<rbrace> f \<lbrace>\<lambda>_. P\<rbrace> \<Longrightarrow> \<lbrace>P\<rbrace> when G f \<lbrace>\<lambda>_. P\<rbrace>"
  by wp simp+


lemma zombie_not_ex_cap_to:
  "\<lbrakk> cte_wp_at (op = (cap.Zombie ptr zbits n)) slot s;
         zombies_final s \<rbrakk>
      \<Longrightarrow> \<not> ex_nonz_cap_to ptr s"
  apply (clarsimp simp: ex_nonz_cap_to_def )
  apply (frule(1) zombies_finalD3[where P="op = c" and P'="\<lambda>c. x \<in> S c", standard])
     apply (clarsimp simp: cte_wp_at_caps_of_state)
    apply assumption
   apply (rule notI, drule_tac a=ptr in equals0D)
   apply (clarsimp simp add: zobj_refs_to_obj_refs)
  apply (clarsimp simp: cte_wp_at_caps_of_state is_cap_simps)
  apply fastforce
  done

lemma valid_idle_has_null_cap:
  "\<lbrakk> if_unsafe_then_cap s; valid_global_refs s;valid_idle s;valid_irq_node s\<rbrakk>
   \<Longrightarrow> caps_of_state s (idle_thread s, v) = Some cap
   \<Longrightarrow> cap = cap.NullCap"
  apply (rule ccontr)
  apply (drule(1) if_unsafe_then_capD[OF caps_of_state_cteD])
   apply clarsimp
  apply (clarsimp simp: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply (frule(1) valid_global_refsD2)
  apply (case_tac capa, simp_all add: cap_range_def global_refs_def)[1]
  apply (clarsimp simp: valid_irq_node_def valid_idle_def st_tcb_at_def
                        obj_at_def is_cap_table_def)
  apply (drule_tac x=word in spec, simp)
  done

lemma zombie_cap_two_nonidles:
  "\<lbrakk> caps_of_state s ptr = Some (cap.Zombie ptr' zbits n); invs s \<rbrakk>
       \<Longrightarrow> fst ptr \<noteq> idle_thread s \<and> ptr' \<noteq> idle_thread s"
  apply (frule valid_global_refsD2, clarsimp+)
  apply (simp add: cap_range_def global_refs_def)
  apply (cases ptr, auto dest: valid_idle_has_null_cap[rotated -1])[1]
  done

lemma is_cap_tableE:
  "\<lbrakk> is_cap_table sz ko; \<And>cs. \<lbrakk> ko = kernel_object.CNode sz cs; well_formed_cnode_n sz cs\<rbrakk> \<Longrightarrow> P \<rbrakk> \<Longrightarrow> P"
  unfolding is_cap_table_def
  by (auto split: Structures_A.kernel_object.split_asm)

lemma recycle_cap_Null[wp]: "\<lbrace>\<top>\<rbrace> recycle_cap is_final cap \<lbrace>\<lambda>rv s. rv \<noteq> cap.NullCap\<rbrace>"
  apply (simp add: recycle_cap_def)
  apply (rule hoare_pre)
   apply (wp hoare_post_taut hoare_drop_imps | simp add: o_def | wpc)+
  apply fastforce
  done


crunch valid_cap [wp]: unmap_page_table, invalidate_tlb_by_asid,
  page_table_mapped, store_pte, delete_asid_pool, copy_global_mappings,
  arch_finalise_cap
  "valid_cap c"
  (wp: mapM_wp_inv mapM_x_wp')


lemma arch_recycle_cap_valid[wp]:
  "\<lbrace>valid_cap (cap.ArchObjectCap arch_cap)\<rbrace>
    arch_recycle_cap is_final arch_cap
   \<lbrace>valid_cap \<circ> cap.ArchObjectCap\<rbrace>"
  apply (rule hoare_pre)
   apply (rule_tac
     Q="\<lambda>rv s. valid_cap (cap.ArchObjectCap arch_cap) s
     \<and> (rv = arch_cap
        \<or> rv = arch_reset_mem_mapping arch_cap)"
     in hoare_post_imp)
    apply (erule conjE)
    apply (erule disjE)
     apply ((clarsimp simp: arch_reset_mem_mapping.simps
                            valid_cap_def cap_aligned_def
       | case_tac arch_cap)+)[2]
   apply (simp add: arch_recycle_cap_def)
   apply (intro conjI impI)
    apply (wp unmap_page_table_valid_cap invalidate_tlb_by_asid_valid_cap
              mapM_x_wp' store_pte_valid_cap
              delete_asid_pool_valid_cap copy_global_mappings_valid_cap
              do_machine_op_valid_cap set_asid_pool_typ_ats
           | wpc
           | wp_once hoare_vcg_conj_lift
           | wp_once hoare_vcg_all_lift
           | wp_once hoare_drop_imps
           | simp add: swp_def)+
  apply force
  done


lemma cap_table_at_length:
  "\<lbrakk> cap_table_at bits oref s; valid_objs s \<rbrakk>
     \<Longrightarrow> bits < (word_bits - cte_level_bits)"
  apply (erule(1) obj_at_valid_objsE)
  apply (case_tac ko, simp_all add: is_cap_table_def)
  apply (clarsimp simp: valid_obj_def valid_cs_def
                        valid_cs_size_def well_formed_cnode_n_def
                        length_set_helper)
  done


lemma recycle_cap_valid[wp]:
  "\<lbrace>valid_cap cap and valid_objs\<rbrace> recycle_cap is_final cap \<lbrace>valid_cap\<rbrace>"
  apply (simp add: recycle_cap_def)
  apply (cases cap, simp_all)
           apply (wp valid_cap_typ [OF ep_cancel_badged_sends_typ_at]
                     | simp)+
   apply (rule hoare_pre, wpc)
     apply (wp | simp add: valid_cap_def | wp_once hoare_drop_imps)+
   apply (clarsimp simp: cap_aligned_def split: option.split_asm)
  apply (wp | simp)+
  done


lemma recycle_cap_cases:
  notes hoare_post_taut [simp del]
  and   split_if [split del]
  shows "\<lbrace>\<top>\<rbrace>
    recycle_cap is_final cap
   \<lbrace>\<lambda>rv s. rv = cap
    \<or> (\<exists>arch_cap. cap = cap.ArchObjectCap arch_cap
      \<and> rv = cap.ArchObjectCap (arch_reset_mem_mapping arch_cap))
    \<or> is_zombie cap
      \<and> (is_thread_cap rv \<or> is_cnode_cap rv)
      \<and> obj_ref_of rv = obj_ref_of cap
      \<and> obj_size rv = obj_size cap\<rbrace>"
  apply (cases cap, simp_all add: recycle_cap_def)
           apply (wp | simp)+
   apply (rule hoare_pre, wpc)
     apply simp
     apply (wp assert_inv | simp)+
   apply (clarsimp simp: is_cap_simps)
  (* arch object cap cases *)
  apply (clarsimp simp: is_cap_simps arch_recycle_cap_def)
  apply (rule hoare_pre)
   apply (wp | wpc | simp)+
  apply (fastforce split: split_if_asm)
  done


lemma emptyable_cte_wp_atD:   "\<lbrakk> cte_wp_at P sl s; valid_objs s;
     \<forall>cap. P cap \<longrightarrow> \<not> is_master_reply_cap cap \<rbrakk>
   \<Longrightarrow> emptyable sl s"
  apply (clarsimp simp: emptyable_def st_tcb_at_def obj_at_def
                        is_tcb cte_wp_at_cases)
  apply (erule(1) pspace_valid_objsE)
  apply (clarsimp simp: valid_obj_def valid_tcb_def ran_tcb_cap_cases)
  done


lemma thread_set_emptyable:
  assumes z: "\<And>tcb. tcb_state  (f tcb) = tcb_state  tcb"
  shows      "\<lbrace>emptyable sl\<rbrace> thread_set f t \<lbrace>\<lambda>rv. emptyable sl\<rbrace>"
  by (wp emptyable_lift thread_set_no_change_tcb_state z)


end
