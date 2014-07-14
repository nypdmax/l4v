(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(NICTA_BSD)
 *)

(* A theory of rewriting under refinement. *)

theory MonadicRewrite
imports
  "wp/NonDetMonadVCG"
  Corres_UL
  EmptyFailLib
  LemmaBucket
begin

definition
  monadic_rewrite :: "bool \<Rightarrow> bool \<Rightarrow> ('a \<Rightarrow> bool)
                       \<Rightarrow> ('a, 'b) nondet_monad \<Rightarrow> ('a, 'b) nondet_monad \<Rightarrow> bool"
where
 "monadic_rewrite F E P f g \<equiv> \<forall>s. P s \<and> (F \<longrightarrow> \<not> snd (f s))
           \<longrightarrow> (E \<longrightarrow> f s = g s)
            \<and> (\<not> E \<longrightarrow> fst (g s) \<subseteq> fst (f s) \<and> (snd (g s) \<longrightarrow> snd (f s)))"


(* FIXME: also in Retype_C *)
lemma snd_bind:
  "snd ((a >>= b) s) = (snd (a s) \<or> (\<exists>(r, s') \<in> fst (a s). snd (b r s')))"
  by (auto simp add: bind_def split_def)

lemma monadic_rewrite_bind:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x);
           \<lbrace>R\<rbrace> g \<lbrace>Q\<rbrace> \<rbrakk>
        \<Longrightarrow> monadic_rewrite F E (P and R) (f >>= (\<lambda>x. h x)) (g >>= (\<lambda>x. j x))"
  apply (cases E)
   apply (clarsimp simp: monadic_rewrite_def snd_bind imp_conjL)
   apply (drule spec, drule(1) mp, clarsimp)
   apply (rule bind_apply_cong)
    apply simp
   apply (frule(2) use_valid)
   apply fastforce
  apply (clarsimp simp: monadic_rewrite_def snd_bind imp_conjL)
  apply (simp add: bind_def split_def)
  apply (rule conjI)
   apply (rule UN_mono)
    apply simp
   apply clarsimp
   apply (frule(2) use_valid)
   apply fastforce
  apply (rule conjI)
   apply fastforce
  apply clarsimp
  apply (frule(2) use_valid)
  apply fastforce
  done

lemma monadic_rewrite_refl:
  "monadic_rewrite F E \<top> f f"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_bindE:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x);
           \<lbrace>R\<rbrace> g \<lbrace>Q\<rbrace>,- \<rbrakk>
        \<Longrightarrow> monadic_rewrite F E (P and R) (f >>=E (\<lambda>x. h x)) (g >>=E (\<lambda>x. j x))"
  apply (simp add: bindE_def)
  apply (erule monadic_rewrite_bind)
   defer
   apply (simp add: validE_R_def validE_def)
  apply (case_tac x, simp_all add: lift_def monadic_rewrite_refl)
  done

lemma monadic_rewrite_catch:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x);
           \<lbrace>R\<rbrace> g -,\<lbrace>Q\<rbrace> \<rbrakk>
        \<Longrightarrow> monadic_rewrite F E (P and R) (f <catch> (\<lambda>x. h x)) (g <catch> (\<lambda>x. j x))"
  apply (simp add: catch_def)
  apply (erule monadic_rewrite_bind)
   defer
   apply (simp add: validE_E_def validE_def)
  apply (case_tac x, simp_all add: lift_def monadic_rewrite_refl)
  done

lemma monadic_rewrite_symb_exec_pre:
  assumes inv: "\<And>s. \<lbrace>op = s\<rbrace> g \<lbrace>\<lambda>r. op = s\<rbrace>"
       and ef: "empty_fail g"
       and rv: "\<And>s. \<lbrace>P\<rbrace> g \<lbrace>\<lambda>y s. y \<in> S\<rbrace>"
       and h': "\<And>y. y \<in> S \<longrightarrow> h y = h'"
  shows "monadic_rewrite True True P (g >>= h) h'"
proof -
  have P: "\<And>s v. \<lbrakk> P s; v \<in> fst (g s) \<rbrakk> \<Longrightarrow> split h v = h' s"
    apply clarsimp
    apply (frule use_valid[OF _ inv], rule refl)
    apply (frule(1) use_valid[OF _ rv])
    apply (simp add: h')
    done

  show ?thesis
    apply (clarsimp simp: monadic_rewrite_def bind_def P image_constant_conv
                    cong: image_cong)
    apply (drule empty_failD2[OF ef])
    apply (clarsimp simp: Pair_fst_snd_eq split: split_if_asm)
    done
qed

lemma monadic_rewrite_trans:
  "\<lbrakk> monadic_rewrite F E P f g; monadic_rewrite F E Q g h \<rbrakk>
      \<Longrightarrow> monadic_rewrite F E (P and Q) f h"
  by (auto simp add: monadic_rewrite_def)

lemma singleton_eq_imp_helper:
  "v \<in> {x} \<longrightarrow> h v = h x" by simp

lemmas monadic_rewrite_symb_exec
    = monadic_rewrite_symb_exec_pre [OF _ _ _ singleton_eq_imp_helper,
                                     THEN monadic_rewrite_trans,
                                     simplified, standard]

lemma eq_UNIV_imp_helper:
  "v \<in> UNIV \<longrightarrow> x = x" by simp

lemmas monadic_rewrite_symb_exec2
    = monadic_rewrite_symb_exec_pre[OF _ _ _ eq_UNIV_imp_helper, where P=\<top>,
                                    simplified, THEN monadic_rewrite_trans]

lemma monadic_rewrite_imp:
  "\<lbrakk> monadic_rewrite F E Q f g; \<And>s. P s \<Longrightarrow> Q s \<rbrakk> \<Longrightarrow> monadic_rewrite F E P f g"
  by (auto simp add: monadic_rewrite_def)

lemmas monadic_rewrite_bind_tail
    = monadic_rewrite_bind [OF monadic_rewrite_refl, simplified pred_and_true_var]
lemmas monadic_rewrite_bind_head
    = monadic_rewrite_bind [OF _ monadic_rewrite_refl hoare_vcg_prop,
                            simplified pred_and_true]

lemma monadic_rewrite_bind2:
  "\<lbrakk> monadic_rewrite F E P f g; \<And>x. monadic_rewrite F E (Q x) (h x) (j x);
           \<lbrace>R\<rbrace> f \<lbrace>Q\<rbrace> \<rbrakk>
        \<Longrightarrow> monadic_rewrite F E (P and R) (f >>= (\<lambda>x. h x)) (g >>= (\<lambda>x. j x))"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans)
    apply (erule(1) monadic_rewrite_bind_tail)
   apply (erule monadic_rewrite_bind_head)
  apply simp
  done

lemma monadic_rewrite_if:
  "\<lbrakk> monadic_rewrite F E Q a c; monadic_rewrite F E R b d \<rbrakk> \<Longrightarrow>
   monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s))
        (If P a b) (If P c d)"
  by (cases P, simp_all)

lemma monadic_rewrite_liftM:
  "monadic_rewrite F E P f g \<Longrightarrow> monadic_rewrite F E P (liftM fn f) (liftM fn g)"
  apply (simp add: liftM_def)
  apply (erule monadic_rewrite_bind_head)
  done

lemmas monadic_rewrite_liftE
    = monadic_rewrite_liftM[where fn=Inr, folded liftE_liftM]

lemma monadic_rewrite_from_simple:
  "P \<longrightarrow> f = g \<Longrightarrow> monadic_rewrite F E (\<lambda>_. P) f g"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_gen_asm:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q f g \<rbrakk> \<Longrightarrow> monadic_rewrite F E ((\<lambda>_. P) and Q) f g"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_assert:
  "\<lbrakk> Q \<Longrightarrow> monadic_rewrite True E P (f ()) g \<rbrakk>
      \<Longrightarrow> monadic_rewrite True E (\<lambda>s. Q \<longrightarrow> P s) (assert Q >>= f) g"
  apply (simp add: assert_def split: split_if)
  apply (simp add: monadic_rewrite_def fail_def)
  done

lemma monadic_rewrite_drop_modify:
  "monadic_rewrite F E (\<lambda>s. f s = s) (modify f >>= v) (v ())"
  by (simp add: monadic_rewrite_def bind_def simpler_modify_def)

lemma empty_failD3:
  "\<lbrakk> empty_fail f; \<not> snd (f s) \<rbrakk> \<Longrightarrow> fst (f s) \<noteq> {}"
  by (drule(1) empty_failD2, clarsimp)

lemma monadic_rewrite_symb_exec_r:
  "\<lbrakk> \<And>s. \<lbrace>op = s\<rbrace> m \<lbrace>\<lambda>r. op = s\<rbrace>; no_fail P' m;
     \<And>rv. monadic_rewrite F False (Q rv) x (y rv);
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
      \<Longrightarrow> monadic_rewrite F False (P and P') x (m >>= y)"
  apply (clarsimp simp: monadic_rewrite_def bind_def)
  apply (drule(1) no_failD)
  apply (subgoal_tac "\<forall>v \<in> fst (m s). Q (fst v) (snd v) \<and> snd v = s")
   apply fastforce
  apply clarsimp
  apply (frule(2) use_valid)
  apply (frule use_valid, assumption, rule refl)
  apply simp
  done

lemma monadic_rewrite_symb_exec_l':
  "\<lbrakk> \<And>s. \<lbrace>op = s\<rbrace> m \<lbrace>\<lambda>r. op = s\<rbrace>; empty_fail m;
     \<not> F \<longrightarrow> no_fail P' m; 
     \<And>rv. monadic_rewrite F False (Q rv) (x rv) y;
     \<lbrace>P\<rbrace> m \<lbrace>Q\<rbrace> \<rbrakk>
      \<Longrightarrow> monadic_rewrite F False (P and P') (m >>= x) y"
  apply (clarsimp simp: monadic_rewrite_def bind_def)
  apply (subgoal_tac "\<not> snd (m s)")
   apply (subgoal_tac "\<forall>v \<in> fst (m s). Q (fst v) (snd v) \<and> snd v = s")
    apply (frule(1) empty_failD2)
    apply (clarsimp simp: split_def)
    apply fastforce
   apply clarsimp
   apply (frule(2) use_valid)
   apply (frule use_valid, assumption, rule refl)
   apply simp
  apply (cases F, simp_all add: no_failD)
  done

lemmas monadic_rewrite_symb_exec_l
    = monadic_rewrite_symb_exec_l'[where F=True and P'=\<top>, simplified]
      monadic_rewrite_symb_exec_l'[where F=False, simplified simp_thms]

lemma monadic_rewrite_alternative_rhs:
  "\<lbrakk> monadic_rewrite F E P a b; monadic_rewrite F E Q a c \<rbrakk>
     \<Longrightarrow> monadic_rewrite F E (P and Q) a (b \<sqinter> c)"
  apply (clarsimp simp: monadic_rewrite_def alternative_def)
  apply auto
  done

lemma monadic_rewrite_rdonly_bind:
  "\<lbrakk> \<And>s. \<lbrace>op = s\<rbrace> f \<lbrace>\<lambda>rv. op = s\<rbrace> \<rbrakk> \<Longrightarrow>
    monadic_rewrite F False \<top>
         (alternative (f >>= (\<lambda>x. g x)) h)
                (f >>= (\<lambda>x. alternative (g x) h))"
  apply (clarsimp simp: monadic_rewrite_def bind_def
                        alternative_def imp_conjL)
  apply (subgoal_tac "\<forall>x \<in> fst (f s). snd x = s")
   apply (simp add: image_image split_def cong: image_cong)
   apply fastforce
  apply clarsimp
  apply (frule use_valid, (assumption | rule refl | simp)+)
  done

lemmas monadic_rewrite_rdonly_bind_l
    = monadic_rewrite_trans [OF monadic_rewrite_rdonly_bind]

lemma monadic_rewrite_if_rhs:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q a b; \<not> P \<Longrightarrow> monadic_rewrite F E R a c \<rbrakk>
      \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s))
             a (If P b c)"
  by (cases P, simp_all)

lemma monadic_rewrite_transverse:
  "\<lbrakk> monadic_rewrite False True Q c b; monadic_rewrite F E P a b \<rbrakk>
       \<Longrightarrow> monadic_rewrite F E (P and Q) a c"
  by (auto simp add: monadic_rewrite_def)

lemma monadic_rewrite_alternative_l:
  "monadic_rewrite F False \<top> (alternative f g) g"
  by (clarsimp simp: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_introduce_alternative:
  "\<lbrakk> f = f'; monadic_rewrite F E P (alternative f' f) g \<rbrakk>
      \<Longrightarrow> monadic_rewrite F E P f g"
  by (simp add: alternative_def)

lemma monadic_rewrite_modify_noop:
  "monadic_rewrite F E (\<lambda>s. f s = s) (modify f) (return ())"
  by (clarsimp simp: monadic_rewrite_def simpler_modify_def return_def)

lemma monadic_rewrite_split_fn:
  "\<lbrakk> monadic_rewrite F E P (liftM fn a) c;
        \<And>rv. monadic_rewrite F E (Q rv) (b rv) (d (fn rv));
        \<lbrace>R\<rbrace> a \<lbrace>Q\<rbrace> \<rbrakk> \<Longrightarrow>
    monadic_rewrite F E (P and R) (a >>= b) (c >>= d)"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans[rotated])
    apply (erule monadic_rewrite_bind_head)
   apply (simp add: liftM_def)
   apply (erule(1) monadic_rewrite_bind_tail)
  apply simp
  done

lemma monadic_rewrite_pick_alternative_1:
  "monadic_rewrite F False \<top> (alternative f g) f"
  by (auto simp add: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_pick_alternative_2:
  "monadic_rewrite F False \<top> (alternative f g) g"
  by (auto simp add: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_weaken:
  "monadic_rewrite (F \<and> F') (E \<or> E') P f g
    \<Longrightarrow> monadic_rewrite F' E' P f g"
  apply (clarsimp simp add: monadic_rewrite_def)
  apply auto
  done

lemma monadic_rewrite_is_refl:
  "x = y \<Longrightarrow> monadic_rewrite F E \<top> x y"
  by (simp add: monadic_rewrite_refl)

lemma monadic_rewrite_refl3:
  "[| !!s. P s ==> f s = g s |] ==> monadic_rewrite F E P f g"
  by (simp add: monadic_rewrite_def)

lemmas monadic_rewrite_refl2 = monadic_rewrite_refl3[where P=\<top>]

lemma monadic_rewrite_cases:
  "\<lbrakk> P \<Longrightarrow> monadic_rewrite F E Q a b; \<not> P \<Longrightarrow> monadic_rewrite F E R a b \<rbrakk>
     \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (P \<longrightarrow> Q s) \<and> (\<not> P \<longrightarrow> R s)) a b"
  by (cases P, simp_all)

lemma monadic_rewrite_symb_exec_l_known:
  "\<lbrakk> \<And>s. \<lbrace>op = s\<rbrace> m \<lbrace>\<lambda>r. op = s\<rbrace>; empty_fail m;
        monadic_rewrite True False Q (x rv) y; \<lbrace>P\<rbrace> m \<lbrace>\<lambda>rv' s. rv' = rv \<and> Q s\<rbrace> \<rbrakk>
      \<Longrightarrow> monadic_rewrite True False P (m >>= x) y"
  apply (erule(1) monadic_rewrite_symb_exec_l)
   apply (rule_tac P="rva = rv" in monadic_rewrite_gen_asm)
   apply simp
  apply (erule hoare_strengthen_post)
  apply simp
  done

lemma monadic_rewrite_gets_the_known_v:
  "monadic_rewrite F E (\<lambda>s. f s = Some v)
     (gets_the f) (return v)"
  by (simp add: monadic_rewrite_def gets_the_def
                exec_gets assert_opt_def)

lemma monadic_rewrite_gets_the_walk:
  "\<lbrakk> \<And>x. monadic_rewrite True False (P x) (g x) (gets_the pf >>= g' x);
      \<And>Q. \<lbrace>\<lambda>s. Q (pf s)\<rbrace> f \<lbrace>\<lambda>rv s. Q (pf s)\<rbrace>; \<lbrace>R\<rbrace> f \<lbrace>P\<rbrace>; empty_fail f \<rbrakk>
      \<Longrightarrow> monadic_rewrite True False R
            (f >>= g)
            (do v \<leftarrow> gets_the pf; x \<leftarrow> f; g' x v od)"
  apply (rule monadic_rewrite_imp)
   apply (rule monadic_rewrite_trans)
    apply (erule(1) monadic_rewrite_bind_tail)
   apply (simp add: gets_the_def bind_assoc)
   apply (rule monadic_rewrite_symb_exec_r, wp)
    apply (rule monadic_rewrite_trans)
     apply (rule monadic_rewrite_bind_tail)
      apply (rule_tac rv=rv in monadic_rewrite_symb_exec_l_known,
             wp empty_fail_gets)
       apply (rule monadic_rewrite_refl)
      apply wp
     apply assumption
    apply (rule_tac P="rv = None" in monadic_rewrite_cases[where Q=\<top>])
     apply (simp add: assert_opt_def)
     apply (clarsimp simp: monadic_rewrite_def fail_def snd_bind)
     apply (rule ccontr, drule(1) empty_failD2)
     apply clarsimp
    apply (simp add: assert_opt_def option_case_If2)
    apply (rule monadic_rewrite_refl)
   apply wp
  apply simp
  done

lemma monadic_rewrite_alternatives:
  "\<lbrakk> monadic_rewrite E F P a c; monadic_rewrite E F Q b d \<rbrakk>
      \<Longrightarrow> monadic_rewrite E F (P and Q) (a \<sqinter> b) (c \<sqinter> d)"
  by (auto simp: monadic_rewrite_def alternative_def)

lemma monadic_rewrite_weaken2:
  "monadic_rewrite F E P f g
     \<Longrightarrow> monadic_rewrite F' E' ((\<lambda>_. (F \<longrightarrow> F') \<and> (E' \<longrightarrow> E)) and P) f g"
  apply (rule monadic_rewrite_gen_asm)
  apply (rule monadic_rewrite_weaken[where F=F and E=E])
  apply auto
  done

lemma monadic_rewrite_sum_case:
  "\<lbrakk> \<And>v. x = Inl v \<Longrightarrow> monadic_rewrite F E (P v) (a v) (c v);
     \<And>v. x = Inr v \<Longrightarrow> monadic_rewrite F E (Q v) (b v) (d v) \<rbrakk>
    \<Longrightarrow> monadic_rewrite F E (\<lambda>s. (\<not> isRight x \<longrightarrow> P (theLeft x) s) \<and> (isRight x \<longrightarrow> Q (theRight x) s))
          (sum_case a b x) (sum_case c d x)"
  by (cases x, simp_all add: isRight_def)

lemma monadic_rewrite_add_gets:
  "monadic_rewrite F E \<top> m (gets f >>= (\<lambda>_. m))"
  by (simp add: monadic_rewrite_def exec_gets)

lemma monadic_rewrite_add_assert:
  "monadic_rewrite F E (\<lambda>s. P) m (assert P >>= (\<lambda>_. m))"
  by (simp add: monadic_rewrite_def)

lemma monadic_rewrite_gets_known:
  "monadic_rewrite F E (\<lambda>s. f s = rv) (gets f >>= m) (m rv)"
  by (simp add: monadic_rewrite_def exec_gets)

lemma monadic_rewrite_to_eq:
  "monadic_rewrite False True \<top> f g ==> f = g"
  by (simp add: monadic_rewrite_def fun_eq_iff)

lemma corres_underlyingI:
  assumes rv: "\<And>s t rv' t'. \<lbrakk>(s, t) \<in> R; P s; P' t; (rv', t') \<in> fst (c t)\<rbrakk> \<Longrightarrow> \<exists>(rv, s') \<in> fst (a s). (s', t') \<in> R \<and> r rv rv'"
  and     nf: "\<And>s t. \<lbrakk>(s, t) \<in> R; P s; P' t; F\<rbrakk> \<Longrightarrow> \<not> snd (c t)"
  shows  "corres_underlying R F r P P' a c"
  unfolding corres_underlying_def using rv nf by (auto simp: split_def)

lemma corres_underlyingE:
  assumes cul: "corres_underlying R F r P P' a c"
  and     xin: "(s, t) \<in> R" "P s" "P' t" "(rv', t') \<in> fst (c t)"
  and      rl: "\<And>s' rv. \<lbrakk>F \<longrightarrow> \<not> snd (c t); (rv, s') \<in> fst (a s); (s', t') \<in> R; r rv rv'\<rbrakk> \<Longrightarrow> Q"
  shows   "Q"
  using cul xin
  unfolding corres_underlying_def by (fastforce simp: split_def intro: rl)

(* Above here is generic *)
lemma monadic_rewrite_corres:
  assumes cu: "corres_underlying R F r P P' a' c"
  and     me: "monadic_rewrite False True Q a a'"
  shows   "corres_underlying R F r (P and Q) P' a c"
proof (rule corres_underlyingI)
  fix s t rv' t' 
  assume st: "(s, t) \<in> R" and pq: "(P and Q) s" and pt: "P' t" and ct: "(rv', t') \<in> fst (c t)"
  from pq have Ps: "P s" and Qs: "Q s" by simp_all

  from cu st Ps pt ct obtain s' rv where 
     as': "(rv, s') \<in> fst (a' s)" and rest: "F \<longrightarrow> \<not> snd (c t)" "(s', t') \<in> R" "r rv rv'"
    by (fastforce elim: corres_underlyingE)
  
  from me st Qs as' have as: "(rv, s') \<in> fst (a s)"
    by (clarsimp simp: monadic_rewrite_def)

  with rest show "\<exists>(rv, s')\<in>fst (a s). (s', t') \<in> R \<and> r rv rv'" by auto
next
  fix s t
  assume "(s, t) \<in> R" "(P and Q) s" "P' t" "F" 
  thus "\<not> snd (c t)" using cu
    by (fastforce simp: corres_underlying_def split_def)
qed

end