(*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(NICTA_BSD)
 *)

theory dc_20081211
imports "../CTranslation"
begin

install_C_file "dc_20081211.c"

context dc_20081211 begin

thm setHardwareASID_modifies
thm test_body_def
thm test_modifies

lemma test_modifies:
  "\<forall>s. \<Gamma> \<turnstile>\<^bsub>/UNIV\<^esub> {s} Call
  test_'proc {t. t may_only_modify_globals s in [x]}"
  (* fails: apply(vcg spec=modifies)
     perhaps because there already is a test_modifies already in
     scope *)
  oops

end

end
