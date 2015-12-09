theory Interfaces_Normalize
imports Common_Primitive_Lemmas
        Ipassmt
begin



subsection{*Optimizing interfaces in match expressions*}

  (*returns: (list of positive interfaces \<times> a list of negated interfaces)
    it matches the conjunction of both
    None if the expression cannot match*)
  definition compress_interfaces :: "iface negation_type list \<Rightarrow> (iface list \<times> iface list) option" where
    "compress_interfaces ifces \<equiv> case (compress_pos_interfaces (getPos ifces))
        of None \<Rightarrow> None
        |  Some i \<Rightarrow> if \<exists>negated_ifce \<in> set (getNeg ifces). iface_subset i negated_ifce then None else Some ((if i = ifaceAny then [] else [i]), getNeg ifces)"

term map_option
term option_map (*l4v*)

  lemma compress_interfaces_None: "compress_interfaces ifces = None \<Longrightarrow> \<not> matches (common_matcher, \<alpha>) (alist_and (NegPos_map IIface ifces)) a p"
    apply(simp add: compress_interfaces_def)
    apply(simp add: nt_match_list_matches[symmetric] nt_match_list_simp)
    apply(simp add: NegPos_map_simps match_simplematcher_Iface match_simplematcher_Iface_not)
    apply(case_tac "compress_pos_interfaces (getPos ifces)")
     apply(simp_all)
     apply(drule_tac p_i="p_iiface p" in compress_pos_interfaces_None)
     apply(simp; fail)
    apply(drule_tac p_i="p_iiface p" in compress_pos_interfaces_Some)
    apply(simp split:split_if_asm)
    using iface_subset by blast

  lemma compress_interfaces_Some: "compress_interfaces ifces = Some (i_pos, i_neg) \<Longrightarrow>
    matches (common_matcher, \<alpha>) (alist_and (NegPos_map IIface ((map Pos i_pos)@(map Neg i_neg)))) a p \<longleftrightarrow>
    matches (common_matcher, \<alpha>) (alist_and (NegPos_map IIface ifces)) a p"
    apply(simp add: compress_interfaces_def)
    apply(simp add: bunch_of_lemmata_about_matches(1) alist_and_append NegPos_map_append)
    apply(simp add: nt_match_list_matches[symmetric] nt_match_list_simp)
    apply(simp add: NegPos_map_simps match_simplematcher_Iface match_simplematcher_Iface_not)
    apply(case_tac "compress_pos_interfaces (getPos ifces)")
     apply(simp_all)
    apply(drule_tac p_i="p_iiface p" in compress_pos_interfaces_Some)
    apply(simp split:split_if_asm)
     using match_ifaceAny apply blast
    by force

  
  definition compress_normalize_interfaces :: "common_primitive match_expr \<Rightarrow> common_primitive match_expr option" where 
    "compress_normalize_interfaces m \<equiv> compress_normalize_primitive (is_Iiface, iiface_sel) IIface compress_interfaces m"

  lemma compress_normalize_interfaces_Some:
  assumes "normalized_nnf_match m" and "compress_normalize_interfaces m = Some m'"
    shows "matches (common_matcher, \<alpha>) m' a p \<longleftrightarrow> matches (common_matcher, \<alpha>) m a p"
    apply(rule compress_normalize_primitive_Some[OF assms(1) wf_disc_sel_common_primitive(5)])
     using assms(2) apply(simp add: compress_normalize_interfaces_def; fail)
    using compress_interfaces_Some by simp

  lemma compress_normalize_interfaces_None:
  assumes "normalized_nnf_match m" and "compress_normalize_interfaces m = None"
    shows "\<not> matches (common_matcher, \<alpha>) m a p"
    apply(rule compress_normalize_primitive_None[OF assms(1) wf_disc_sel_common_primitive(5)])
     using assms(2) apply(simp add: compress_normalize_interfaces_def; fail)
    using compress_interfaces_None by simp

  lemma compress_normalize_interfaces_nnf: "normalized_nnf_match m \<Longrightarrow> compress_normalize_interfaces m = Some m' \<Longrightarrow>
      normalized_nnf_match m'"
    unfolding compress_normalize_interfaces_def
    using compress_normalize_primitive_nnf[OF wf_disc_sel_common_primitive(5)] by blast
 
  lemma compress_normalize_interfaces_not_introduces_Iiface:
    "\<not> has_disc is_Iiface m \<Longrightarrow> normalized_nnf_match m \<Longrightarrow> compress_normalize_interfaces m = Some m' \<Longrightarrow>
     \<not> has_disc is_Iiface m'"
      apply(simp add: compress_normalize_interfaces_def)
      apply(drule compress_normalize_primitive_not_introduces_C[where m=m])
          apply(simp_all add: wf_disc_sel_common_primitive(5))
      by(simp add: compress_interfaces_def)

  lemma compress_normalize_interfaces_not_introduces_Iiface_negated:
    assumes notdisc: "\<not> has_disc_negated is_Iiface False m"
        and nm: "normalized_nnf_match m"
        and some: "compress_normalize_interfaces m = Some m'"
     shows "\<not> has_disc_negated is_Iiface False m'"
     apply(rule compress_normalize_primitive_not_introduces_C_negated[OF notdisc wf_disc_sel_common_primitive(5) nm])
     using some apply(simp add: compress_normalize_interfaces_def)
     by(simp add: compress_interfaces_def split: option.split_asm)


  (* only for arbitrary discs that do not match Iiface*)
  lemma compress_normalize_interfaces_hasdisc:
    "\<not> has_disc disc m \<Longrightarrow> (\<forall>a. \<not> disc (IIface a)) \<Longrightarrow> normalized_nnf_match m \<Longrightarrow> compress_normalize_interfaces m = Some m' \<Longrightarrow>
     normalized_nnf_match m' \<and> \<not> has_disc disc m'"
     unfolding compress_normalize_interfaces_def
     using compress_normalize_primitive_hasdisc[OF _ wf_disc_sel_common_primitive(5)] by blast

   (* only for arbitrary discs that do not match Iiface*)
  lemma compress_normalize_interfaces_hasdisc_negated:
    "\<not> has_disc_negated disc neg m \<Longrightarrow> (\<forall>a. \<not> disc (IIface a)) \<Longrightarrow> normalized_nnf_match m \<Longrightarrow> compress_normalize_interfaces m = Some m' \<Longrightarrow>
     normalized_nnf_match m' \<and> \<not> has_disc_negated disc neg m'"
     unfolding compress_normalize_interfaces_def
     using compress_normalize_primitive_hasdisc_negated[OF _ wf_disc_sel_common_primitive(5)] by blast


  lemma compress_normalize_interfaces_preserves_normalized_n_primitive:
    "normalized_n_primitive (disc, sel) P m \<Longrightarrow> (\<forall>a. \<not> disc (IIface a)) \<Longrightarrow> normalized_nnf_match m \<Longrightarrow> compress_normalize_interfaces m = Some m' \<Longrightarrow>
     normalized_nnf_match m' \<and> normalized_n_primitive (disc, sel) P m'"
     unfolding compress_normalize_interfaces_def
   using compress_normalize_primitve_preserves_normalized_n_primitive[OF _ wf_disc_sel_common_primitive(5)] by blast
  

  value[code] "compress_normalize_interfaces 
    (MatchAnd (MatchAnd (MatchAnd (Match (IIface (Iface ''eth+''))) (MatchNot (Match (IIface (Iface ''eth4''))))) (Match (IIface (Iface ''eth1''))))
              (Match (Prot (Proto TCP))))"
    
  value[code] "compress_normalize_interfaces MatchAny"

end