(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(NICTA_BSD)
 *)

theory signed_div
imports "../CTranslation"
begin

install_C_file "signed_div.c"

context signed_div
begin

lemma f_result:
  "\<Gamma> \<turnstile> \<lbrace> True \<rbrace> \<acute>ret__int :== CALL f(5, -1) \<lbrace> \<acute>ret__int = -5 \<rbrace>"
  apply vcg
  apply (clarsimp simp: sdiv_word_def sdiv_int_def)
  done

lemma word_not_minus_one [simp]:
  "0 \<noteq> (-1 :: word32)"
  by (metis word_msb_0 word_msb_n1)

lemma f_overflow:
  shows "\<lbrakk> a_' s = of_int (-2^31); b_' s = -1 \<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> \<langle> Call f_'proc ,Normal s\<rangle> \<Rightarrow> Fault SignedArithmetic"
  apply (rule exec.Call [where \<Gamma>=\<Gamma>, OF f_impl, simplified f_body_def creturn_def])
  apply (rule exec.CatchMiss)
  apply (subst exec.simps, clarsimp simp del: word_neq_0_conv simp: sdiv_word_def sdiv_int_def)+
  apply simp
  done

lemma g_result:
  "\<Gamma> \<turnstile> \<lbrace> True \<rbrace> \<acute>ret__int :== CALL g(-5, 10) \<lbrace> \<acute>ret__int = -5 \<rbrace>"
  apply vcg
  apply (clarsimp simp: smod_word_def smod_int_def sdiv_int_def)
  done

lemma h_result:
  "\<Gamma> \<turnstile> \<lbrace> True \<rbrace> \<acute>ret__int :== CALL h(5, -1) \<lbrace> \<acute>ret__int = 0 \<rbrace>"
  apply vcg
  apply (clarsimp simp: word_arith_nat_div ucast_def bintr_Min)
  done

lemma i_result:
  "\<Gamma> \<turnstile> \<lbrace> True \<rbrace> \<acute>ret__int :== CALL f(5, -1) \<lbrace> \<acute>ret__int = -5 \<rbrace>"
  apply vcg
  apply (clarsimp simp: sdiv_word_def sdiv_int_def)
  done

end

end
