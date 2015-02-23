theory Semantics_Ternary
imports Matching_Ternary Misc
begin

(*
TODO TODO TODO

rename the functions.

*)

section{*Embedded Ternary-Matching Big Step Semantics*}

(* TODO larsrh *)
lemma rules_singleton_rev_E: "[Rule m a] = rs\<^sub>1 @ rs\<^sub>2 \<Longrightarrow> (rs\<^sub>1 = [Rule m a] \<Longrightarrow> rs\<^sub>2 = [] \<Longrightarrow> P m a) \<Longrightarrow> (rs\<^sub>1 = [] \<Longrightarrow> rs\<^sub>2 = [Rule m a] \<Longrightarrow> P m a) \<Longrightarrow> P m a"
by (cases rs\<^sub>1) auto


inductive approximating_bigstep :: "('a, 'p) match_tac \<Rightarrow> 'p \<Rightarrow> 'a rule list \<Rightarrow> state \<Rightarrow> state \<Rightarrow> bool"
  ("_,_\<turnstile> \<langle>_, _\<rangle> \<Rightarrow>\<^sub>\<alpha> _"  [60,60,20,98,98] 89)
  for \<gamma> and p where
skip:  "\<gamma>,p\<turnstile> \<langle>[], t\<rangle> \<Rightarrow>\<^sub>\<alpha> t" |
accept:  "\<lbrakk>matches \<gamma> m Accept p\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>[Rule m Accept], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision FinalAllow" |
drop:  "\<lbrakk>matches \<gamma> m Drop p\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>[Rule m Drop], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision FinalDeny" |
reject:  "\<lbrakk>matches \<gamma> m Reject p\<rbrakk> \<Longrightarrow>  \<gamma>,p\<turnstile> \<langle>[Rule m Reject], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision FinalDeny" |
log:   "\<lbrakk>matches \<gamma> m Log p\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>[Rule m Log], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Undecided" |
empty:   "\<lbrakk>matches \<gamma> m Empty p\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>[Rule m Empty], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Undecided" |
nomatch:  "\<lbrakk>\<not> matches \<gamma> m a p\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>[Rule m a], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Undecided" | 
decision:  "\<gamma>,p\<turnstile> \<langle>rs, Decision X\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision X" |
seq:  "\<lbrakk>\<gamma>,p\<turnstile> \<langle>rs\<^sub>1, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t; \<gamma>,p\<turnstile> \<langle>rs\<^sub>2, t\<rangle> \<Rightarrow>\<^sub>\<alpha> t'\<rbrakk> \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>rs\<^sub>1@rs\<^sub>2, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t'" 



thm approximating_bigstep.induct[of \<gamma> p rs s t P]
(*tuned induction rule*)
lemma approximating_bigstep_induct[case_names Skip Allow Deny Log Nomatch Decision Seq, induct pred: approximating_bigstep] : "\<gamma>,p\<turnstile> \<langle>rs,s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow>
(\<And>t. P [] t t) \<Longrightarrow>
(\<And>m a. matches \<gamma> m a p \<Longrightarrow> a = Accept \<Longrightarrow> P [Rule m a] Undecided (Decision FinalAllow)) \<Longrightarrow>
(\<And>m a. matches \<gamma> m a p \<Longrightarrow> a = Drop \<or> a = Reject \<Longrightarrow> P [Rule m a] Undecided (Decision FinalDeny)) \<Longrightarrow>
(\<And>m a. matches \<gamma> m a p \<Longrightarrow> a = Log \<or> a = Empty \<Longrightarrow> P [Rule m a] Undecided Undecided) \<Longrightarrow>
(\<And>m a. \<not> matches \<gamma> m a p \<Longrightarrow> P [Rule m a] Undecided Undecided) \<Longrightarrow>
(\<And>rs X. P rs (Decision X) (Decision X)) \<Longrightarrow>
(\<And>rs rs\<^sub>1 rs\<^sub>2 t t'. rs = rs\<^sub>1 @ rs\<^sub>2 \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>rs\<^sub>1,Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> P rs\<^sub>1 Undecided t \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>rs\<^sub>2,t\<rangle> \<Rightarrow>\<^sub>\<alpha> t' \<Longrightarrow> P rs\<^sub>2 t t' \<Longrightarrow> P rs Undecided t')
   \<Longrightarrow> P rs s t"
by (induction rule: approximating_bigstep.induct) (simp_all)


lemma skipD: "\<gamma>,p\<turnstile> \<langle>[], s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> s = t"
by (induction "[]::'a rule list" s t rule: approximating_bigstep_induct) (simp_all)

lemma decisionD: "\<gamma>,p\<turnstile> \<langle>rs, Decision X\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> t = Decision X"
by (induction rs "Decision X" t rule: approximating_bigstep_induct) (simp_all)

lemma acceptD: "\<gamma>,p\<turnstile> \<langle>[Rule m Accept], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> matches \<gamma> m Accept p \<Longrightarrow> t = Decision FinalAllow"
apply (induction "[Rule m Accept]" Undecided t rule: approximating_bigstep_induct)
    apply (simp_all)
by (metis list_app_singletonE skipD)

lemma dropD: "\<gamma>,p\<turnstile> \<langle>[Rule m Drop], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> matches \<gamma> m Drop p \<Longrightarrow> t = Decision FinalDeny"
apply (induction "[Rule m Drop]" Undecided t rule: approximating_bigstep_induct)
by(auto dest: skipD elim!: rules_singleton_rev_E)

lemma rejectD: "\<gamma>,p\<turnstile> \<langle>[Rule m Reject], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> matches \<gamma> m Reject p \<Longrightarrow> t = Decision FinalDeny"
apply (induction "[Rule m Reject]" Undecided t rule: approximating_bigstep_induct)
by(auto dest: skipD elim!: rules_singleton_rev_E)

lemma logD: "\<gamma>,p\<turnstile> \<langle>[Rule m Log], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> t = Undecided"
apply (induction "[Rule m Log]" Undecided t rule: approximating_bigstep_induct)
by(auto dest: skipD elim!: rules_singleton_rev_E)

lemma emptyD: "\<gamma>,p\<turnstile> \<langle>[Rule m Empty], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> t = Undecided"
apply (induction "[Rule m Empty]" Undecided t rule: approximating_bigstep_induct)
by(auto dest: skipD elim!: rules_singleton_rev_E)

lemma nomatchD: "\<gamma>,p\<turnstile> \<langle>[Rule m a], Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> \<not> matches \<gamma> m a p \<Longrightarrow> t = Undecided"
apply (induction "[Rule m a]" Undecided t rule: approximating_bigstep_induct)
by(auto dest: skipD elim!: rules_singleton_rev_E)

lemmas approximating_bigstepD = skipD acceptD dropD rejectD logD emptyD nomatchD decisionD

lemma approximating_bigstep_to_undecided: "\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> Undecided \<Longrightarrow> s = Undecided"
  by (metis decisionD state.exhaust)

lemma approximating_bigstep_to_decision1: "\<gamma>,p\<turnstile> \<langle>rs, Decision Y\<rangle> \<Rightarrow>\<^sub>\<alpha> Decision X \<Longrightarrow> Y = X"
  by (metis decisionD state.inject)
thm decisionD

lemma nomatch_fst: "\<not> matches \<gamma> m a p \<Longrightarrow>  \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>Rule m a # rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
  apply(cases s)
   apply(clarify)
   apply(drule nomatch)
   apply(drule(1) seq)
   apply (simp)
  apply(clarify)
  apply(drule decisionD)
  apply(clarify)
 apply(simp_all add: decision)
done

lemma seq':
  assumes "rs = rs\<^sub>1 @ rs\<^sub>2" "\<gamma>,p\<turnstile> \<langle>rs\<^sub>1,s\<rangle> \<Rightarrow>\<^sub>\<alpha> t" "\<gamma>,p\<turnstile> \<langle>rs\<^sub>2,t\<rangle> \<Rightarrow>\<^sub>\<alpha> t'"
  shows "\<gamma>,p\<turnstile> \<langle>rs,s\<rangle> \<Rightarrow>\<^sub>\<alpha> t'"
using assms by (cases s) (auto intro: seq decision dest: decisionD)

lemma seq_split:
  assumes "\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t" "rs = rs\<^sub>1@rs\<^sub>2"
  obtains t' where "\<gamma>,p\<turnstile> \<langle>rs\<^sub>1,s\<rangle> \<Rightarrow>\<^sub>\<alpha> t'" "\<gamma>,p\<turnstile> \<langle>rs\<^sub>2,t'\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
  using assms
  proof (induction rs s t arbitrary: rs\<^sub>1 rs\<^sub>2 thesis rule: approximating_bigstep_induct)
    case Allow thus ?case by (auto dest: skipD elim!: rules_singleton_rev_E intro: approximating_bigstep.intros)
  next
    case Deny thus ?case by (auto dest: skipD elim!: rules_singleton_rev_E intro: approximating_bigstep.intros)
  next
    case Log thus ?case by (auto dest: skipD elim!: rules_singleton_rev_E intro: approximating_bigstep.intros)
  next
    case Nomatch thus ?case by (auto dest: skipD elim!: rules_singleton_rev_E intro: approximating_bigstep.intros)
  next
    case (Seq rs rsa rsb t t')
    hence rs: "rsa @ rsb = rs\<^sub>1 @ rs\<^sub>2" by simp
    note List.append_eq_append_conv_if[simp]
    from rs show ?case
      proof (cases rule: list_app_eq_cases)
        case longer
        with Seq have t1: "\<gamma>,p\<turnstile> \<langle>take (length rsa) rs\<^sub>1, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
          by simp
        from Seq longer obtain t2
          where t2a: "\<gamma>,p\<turnstile> \<langle>drop (length rsa) rs\<^sub>1,t\<rangle> \<Rightarrow>\<^sub>\<alpha> t2"
            and rs2_t2: "\<gamma>,p\<turnstile> \<langle>rs\<^sub>2,t2\<rangle> \<Rightarrow>\<^sub>\<alpha> t'"
          by blast
        with t1 rs2_t2 have "\<gamma>,p\<turnstile> \<langle>take (length rsa) rs\<^sub>1 @ drop (length rsa) rs\<^sub>1,Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t2"
          by (blast intro: approximating_bigstep.seq)
        with Seq rs2_t2 show ?thesis
          by simp
      next
        case shorter
        with rs have rsa': "rsa = rs\<^sub>1 @ take (length rsa - length rs\<^sub>1) rs\<^sub>2"
          by (metis append_eq_conv_conj length_drop)
        from shorter rs have rsb': "rsb = drop (length rsa - length rs\<^sub>1) rs\<^sub>2"
          by (metis append_eq_conv_conj length_drop)
        from Seq rsa' obtain t1
          where t1a: "\<gamma>,p\<turnstile> \<langle>rs\<^sub>1,Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t1"
            and t1b: "\<gamma>,p\<turnstile> \<langle>take (length rsa - length rs\<^sub>1) rs\<^sub>2,t1\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
          by blast
        from rsb' Seq.hyps have t2: "\<gamma>,p\<turnstile> \<langle>drop (length rsa - length rs\<^sub>1) rs\<^sub>2,t\<rangle> \<Rightarrow>\<^sub>\<alpha> t'"
          by blast
        with seq' t1b have "\<gamma>,p\<turnstile> \<langle>rs\<^sub>2,t1\<rangle> \<Rightarrow>\<^sub>\<alpha> t'" by (metis append_take_drop_id)
        with Seq t1a show ?thesis
          by fast
      qed
  qed (auto intro: approximating_bigstep.intros)


lemma seqE_fst:
  assumes "\<gamma>,p\<turnstile> \<langle>r#rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
  obtains t' where "\<gamma>,p\<turnstile> \<langle>[r],s\<rangle> \<Rightarrow>\<^sub>\<alpha> t'" "\<gamma>,p\<turnstile> \<langle>rs,t'\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
  using assms seq_split by (metis append_Cons append_Nil)

lemma seq_fst: "\<gamma>,p\<turnstile> \<langle>[r], s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>rs, t\<rangle> \<Rightarrow>\<^sub>\<alpha> t' \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>r # rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t'"
apply(cases s)
apply(simp)
using seq apply fastforce
apply(simp)
apply(drule decisionD)
apply(simp)
apply(drule decisionD)
apply(simp)
using decision by fast


fun approximating_bigstep_fun :: "('a, 'p) match_tac \<Rightarrow> 'p \<Rightarrow> 'a rule list \<Rightarrow> state \<Rightarrow> state" where
  "approximating_bigstep_fun \<gamma> p [] s = s" |
  "approximating_bigstep_fun \<gamma> p rs (Decision X) = (Decision X)" |
  "approximating_bigstep_fun \<gamma> p ((Rule m a)#rs) Undecided = (if 
      \<not> matches \<gamma> m a p
    then
      approximating_bigstep_fun \<gamma> p rs Undecided
    else
      case a of Accept \<Rightarrow> Decision FinalAllow
              | Drop \<Rightarrow> Decision FinalDeny
              | Reject \<Rightarrow> Decision FinalDeny
              | Log \<Rightarrow> approximating_bigstep_fun \<gamma> p rs Undecided
              | Empty \<Rightarrow> approximating_bigstep_fun \<gamma> p rs Undecided
              (*unhalndled cases*)
              )"


thm approximating_bigstep_fun.induct[of P \<gamma> p rs s]
(*tuned induction rule*)
lemma approximating_bigstep_fun_induct[case_names Empty Decision Nomatch Match] : "
(\<And>\<gamma> p s. P \<gamma> p [] s) \<Longrightarrow>
(\<And>\<gamma> p r rs X. P \<gamma> p (r # rs) (Decision X)) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    \<not> matches \<gamma> m a p \<Longrightarrow> P \<gamma> p rs Undecided \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> (a = Log \<Longrightarrow> P \<gamma> p rs Undecided) \<Longrightarrow> (a = Empty \<Longrightarrow> P \<gamma> p rs Undecided) \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
P \<gamma> p rs s"
apply (rule approximating_bigstep_fun.induct[of P \<gamma> p rs s])
apply (simp_all)
by metis

lemma Decision_approximating_bigstep_fun: "approximating_bigstep_fun \<gamma> p rs (Decision X) = Decision X"
  by(induction rs) (simp_all)


subsection{*wf ruleset*}
  text{*
  A @{typ "'a rule list"} here is well-formed (for a packet) if
  \begin{enumerate}
    \item either the rules do not match
    \item or the action is not @{const Call}, not @{const Return}, not @{const Unknown}
  \end{enumerate}
  *}
  definition wf_ruleset :: "('a, 'p) match_tac \<Rightarrow> 'p \<Rightarrow> 'a rule list \<Rightarrow> bool" where
    "wf_ruleset \<gamma> p rs \<equiv> \<forall>r \<in> set rs. 
      (\<not> matches \<gamma> (get_match r) (get_action r) p) \<or> 
      (\<not>(\<exists>chain. get_action r = Call chain) \<and> get_action r \<noteq> Return \<and> get_action r \<noteq> Unknown)"

  lemma wf_ruleset_append: "wf_ruleset \<gamma> p (rs1@rs2) \<longleftrightarrow> wf_ruleset \<gamma> p rs1 \<and> wf_ruleset \<gamma> p rs2"
    by(auto simp add: wf_ruleset_def)
  lemma wf_rulesetD: assumes "wf_ruleset \<gamma> p (r # rs)" shows "wf_ruleset \<gamma> p [r]" and "wf_ruleset \<gamma> p rs"
    using assms by(auto simp add: wf_ruleset_def)
  lemma wf_ruleset_fst: "wf_ruleset \<gamma> p (Rule m a # rs) \<longleftrightarrow> wf_ruleset \<gamma> p [Rule m a] \<and> wf_ruleset \<gamma> p rs"
    using assms by(auto simp add: wf_ruleset_def)
  lemma wf_ruleset_stripfst: "wf_ruleset \<gamma> p (r # rs) \<Longrightarrow> wf_ruleset \<gamma> p (rs)"
    by(simp add: wf_ruleset_def)
  lemma wf_ruleset_rest: "wf_ruleset \<gamma> p (Rule m a # rs) \<Longrightarrow> wf_ruleset \<gamma> p [Rule m a]"
    by(simp add: wf_ruleset_def)
  

lemma approximating_bigstep_fun_induct_wf[case_names Empty Decision Nomatch MatchAccept MatchDrop MatchReject MatchLog MatchEmpty, consumes 1]:
  "wf_ruleset \<gamma> p rs \<Longrightarrow>
(\<And>\<gamma> p s. P \<gamma> p [] s) \<Longrightarrow>
(\<And>\<gamma> p r rs X. P \<gamma> p (r # rs) (Decision X)) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    \<not> matches \<gamma> m a p \<Longrightarrow> P \<gamma> p rs Undecided \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> a = Accept  \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> a = Drop \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> a = Reject \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> a = Log \<Longrightarrow> P \<gamma> p rs Undecided  \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
(\<And>\<gamma> p m a rs.
    matches \<gamma> m a p \<Longrightarrow> a = Empty \<Longrightarrow> P \<gamma> p rs Undecided \<Longrightarrow> P \<gamma> p (Rule m a # rs) Undecided) \<Longrightarrow>
P \<gamma> p rs s"
apply(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct)
apply blast
apply blast
apply(auto dest:wf_rulesetD)[1]
apply(frule wf_rulesetD(1), drule wf_rulesetD(2))
apply(simp)
apply(case_tac a)
apply(simp_all)
apply(auto simp add: wf_ruleset_def)
done

subsubsection{*Append, Prepend, Postpend, Composition*}
  lemma approximating_bigstep_fun_seq_wf: "\<lbrakk> wf_ruleset \<gamma> p rs\<^sub>1\<rbrakk> \<Longrightarrow>
      approximating_bigstep_fun \<gamma> p (rs\<^sub>1 @ rs\<^sub>2) Undecided = approximating_bigstep_fun \<gamma> p rs\<^sub>2 (approximating_bigstep_fun \<gamma> p rs\<^sub>1 Undecided)"
    apply(induction rs\<^sub>1 arbitrary: )
    apply simp_all
    apply(rename_tac r rs1)
    apply(case_tac r, rename_tac x1 x2)
    apply(clarify)
    apply(case_tac "\<not> matches \<gamma> x1 x2 p")
    apply(simp add: wf_ruleset_def)
    apply(simp add: wf_ruleset_def)
    apply(case_tac x2)
    apply simp_all
    apply(simp_all add: Decision_approximating_bigstep_fun)
    apply auto
    done


  lemma approximating_bigstep_fun_seq_Undecided_wf: "\<lbrakk> wf_ruleset \<gamma> p (rs1@rs2)\<rbrakk> \<Longrightarrow> 
      approximating_bigstep_fun \<gamma> p (rs1@rs2) Undecided = Undecided \<longleftrightarrow> 
  approximating_bigstep_fun \<gamma> p rs1 Undecided = Undecided \<and> approximating_bigstep_fun \<gamma> p rs2 Undecided = Undecided"
    apply(induction "rs1" arbitrary:)
    apply(simp add: wf_ruleset_def)
    apply(rename_tac r rs1)
    apply(case_tac r, rename_tac x1 x2)
    apply(clarify)
    apply(case_tac "\<not> matches \<gamma> x1 x2 p")
    apply(simp add: wf_ruleset_def)
    apply(simp add: wf_ruleset_def)
    apply(case_tac x2)
    apply simp_all
    apply auto
    done

  lemma approximating_bigstep_fun_seq_Undecided_t_wf: "\<lbrakk> wf_ruleset \<gamma> p (rs1@rs2)\<rbrakk> \<Longrightarrow> 
      approximating_bigstep_fun \<gamma> p (rs1@rs2) Undecided = t \<longleftrightarrow> 
  approximating_bigstep_fun \<gamma> p rs1 Undecided = Undecided \<and> approximating_bigstep_fun \<gamma> p rs2 Undecided = t \<or>
  approximating_bigstep_fun \<gamma> p rs1 Undecided = t \<and> t \<noteq> Undecided"
    apply(induction "rs1" arbitrary:)
    apply simp_all
    apply(case_tac t)
    apply(simp_all add: Decision_approximating_bigstep_fun)

    apply(rename_tac r rs1)
    apply(case_tac r, rename_tac x1 x2)
    apply(clarify)
    apply(case_tac "\<not> matches \<gamma> x1 x2 p")
    apply(simp add: wf_ruleset_def)
    apply(simp add: wf_ruleset_def)
    apply(case_tac x2)
    apply simp_all
    apply auto
    done

  lemma approximating_bigstep_fun_wf_postpend: "wf_ruleset \<gamma> p rsA \<Longrightarrow> wf_ruleset \<gamma> p rsB \<Longrightarrow> 
      approximating_bigstep_fun \<gamma> p rsA s = approximating_bigstep_fun \<gamma> p rsB s \<Longrightarrow> 
      approximating_bigstep_fun \<gamma> p (rsA@rsC) s = approximating_bigstep_fun \<gamma> p (rsB@rsC) s"
  apply(case_tac s)
   prefer 2
   apply(simp add: Decision_approximating_bigstep_fun)
  apply(simp)
  apply(thin_tac "s = ?un")
  apply(induction \<gamma> p rsA "Undecided" rule: approximating_bigstep_fun_induct_wf)
  apply(simp_all)
  apply (metis approximating_bigstep_fun_seq_wf)
  apply (metis Decision_approximating_bigstep_fun approximating_bigstep_fun_seq_wf)+
  done

lemma approximating_bigstep_fun_singleton_prepend: "approximating_bigstep_fun \<gamma> p rsB s = approximating_bigstep_fun \<gamma> p rsC s \<Longrightarrow> 
      approximating_bigstep_fun \<gamma> p (r#rsB) s = approximating_bigstep_fun \<gamma> p (r#rsC) s"
  apply(case_tac s)
   prefer 2
   apply(simp add: Decision_approximating_bigstep_fun)
  apply(simp)
  apply(cases r)
  apply(simp split: action.split)
  done

subsection{*Equality with @{term "\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"} semantics*}
  lemma approximating_bigstep_wf: "\<gamma>,p\<turnstile> \<langle>rs, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> Undecided \<Longrightarrow> wf_ruleset \<gamma> p rs"
  unfolding wf_ruleset_def
  proof(induction rs Undecided Undecided rule: approximating_bigstep_induct)
    case Skip thus ?case by simp
    next
    case Log thus ?case by auto
    next
    case Nomatch thus ?case by simp
    next
    case (Seq rs rs1 rs2 t)
      from Seq approximating_bigstep_to_undecided have "t = Undecided" by fast
      from this Seq show ?case by auto
  qed
  

  text{*only valid actions appear in this ruleset*}
  definition good_ruleset :: "'a rule list \<Rightarrow> bool" where
    "good_ruleset rs \<equiv> \<forall>r \<in> set rs. (\<not>(\<exists>chain. get_action r = Call chain) \<and> get_action r \<noteq> Return \<and> get_action r \<noteq> Unknown)"

  lemma[code_unfold]: "good_ruleset rs \<equiv> (\<forall>r\<in>set rs. (case get_action r of Call chain \<Rightarrow> False | Return \<Rightarrow> False | Unknown \<Rightarrow> False | _ \<Rightarrow> True))"
    apply(induction rs)
     apply(simp add: good_ruleset_def)
    apply(simp add: good_ruleset_def)
    apply(thin_tac "?x = ?y") (*IH*)
    apply(rename_tac r rs)
    apply(case_tac "get_action r")
           apply(simp_all)
    done

  lemma good_ruleset_alt: "good_ruleset rs = (\<forall>r\<in>set rs. get_action r = Accept \<or> get_action r = Drop \<or>
                                                get_action r = Reject \<or> get_action r = Log  \<or> get_action r = Empty)"
    apply(simp add: good_ruleset_def)
    apply(rule iffI)
     apply(clarify)
     apply(case_tac "get_action r")
            apply(simp_all)
    apply(clarify)
    apply(case_tac "get_action r")
          apply(simp_all)
      apply(fastforce)+
    done


  lemma good_ruleset_append: "good_ruleset (rs\<^sub>1 @ rs\<^sub>2) \<longleftrightarrow> good_ruleset rs\<^sub>1 \<and> good_ruleset rs\<^sub>2"
    by(simp add: good_ruleset_alt, blast)

  lemma good_ruleset_fst: "good_ruleset (r#rs) \<Longrightarrow> good_ruleset [r]"
    by(simp add: good_ruleset_def)
  lemma good_ruleset_tail: "good_ruleset (r#rs) \<Longrightarrow> good_ruleset rs"
    by(simp add: good_ruleset_def)

  text{*
    @{term good_ruleset} is stricter than @{term wf_ruleset}. It can be easily checked with running code!
  *}
  lemma good_imp_wf_ruleset: "good_ruleset rs \<Longrightarrow> wf_ruleset \<gamma> p rs" by (metis good_ruleset_def wf_ruleset_def)

  definition simple_ruleset :: "'a rule list \<Rightarrow> bool" where
    "simple_ruleset rs \<equiv> \<forall>r \<in> set rs. get_action r = Accept (*\<or> get_action r = Reject*) \<or> get_action r = Drop"
  lemma simple_imp_good_ruleset: "simple_ruleset rs \<Longrightarrow> good_ruleset rs"
    by(simp add: simple_ruleset_def good_ruleset_def, fastforce)

  lemma simple_ruleset_tail: "simple_ruleset (r#rs) \<Longrightarrow> simple_ruleset rs" by (simp add: simple_ruleset_def)

  lemma simple_ruleset_append: "simple_ruleset (rs\<^sub>1 @ rs\<^sub>2) \<longleftrightarrow> simple_ruleset rs\<^sub>1 \<and> simple_ruleset rs\<^sub>2"
    by(simp add: simple_ruleset_def, blast)

lemma approximating_bigstep_fun_seq_semantics: "\<lbrakk> \<gamma>,p\<turnstile> \<langle>rs\<^sub>1, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<rbrakk> \<Longrightarrow> 
    approximating_bigstep_fun \<gamma> p (rs\<^sub>1 @ rs\<^sub>2) s = approximating_bigstep_fun \<gamma> p rs\<^sub>2 t"
  apply(induction rs\<^sub>1 s t arbitrary: rs\<^sub>2 rule: approximating_bigstep.induct)
  apply(simp_all add: Decision_approximating_bigstep_fun)
  done

lemma approximating_semantics_imp_fun: "\<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<Longrightarrow> approximating_bigstep_fun \<gamma> p rs s = t"
  apply(induction rs s t rule: approximating_bigstep_induct)
  apply(auto)[7]
  apply(case_tac rs)
  apply(simp_all)
  apply(simp add: approximating_bigstep_fun_seq_semantics)
  done

lemma approximating_fun_imp_semantics: assumes "wf_ruleset \<gamma> p rs"
      shows "approximating_bigstep_fun \<gamma> p rs s = t \<Longrightarrow> \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
  using assms proof(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct_wf)
    case (Empty \<gamma> p s)
      thus "\<gamma>,p\<turnstile> \<langle>[], s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"  using skip by(simp)
    next
    case (Decision \<gamma> p r rs X)
      hence "t = Decision X" by simp
      thus "\<gamma>,p\<turnstile> \<langle>r # rs, Decision X\<rangle> \<Rightarrow>\<^sub>\<alpha> t" using decision by fast
    next
    case (Nomatch \<gamma> p m a rs)
      thus "\<gamma>,p\<turnstile> \<langle>Rule m a # rs, Undecided\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
        apply(rule_tac t=Undecided in seq_fst)
         apply(simp add: nomatch)
        apply(simp add: Nomatch.IH)
        done
    next
    case (MatchAccept \<gamma> p m a rs)
      hence "t = Decision FinalAllow" by simp
      thus ?case by (metis MatchAccept.hyps accept decision seq_fst)
    next
    case (MatchDrop \<gamma> p m a rs)
      hence "t = Decision FinalDeny" by simp
      thus ?case by (metis MatchDrop.hyps drop decision seq_fst)
    next
    case (MatchReject \<gamma> p m a rs)
      hence "t = Decision FinalDeny" by simp
      thus ?case by (metis MatchReject.hyps reject decision seq_fst)
    next
    case (MatchLog \<gamma> p m a rs)
      thus ?case
        apply(simp)
        apply(rule_tac t=Undecided in seq_fst)
         apply(simp add: log)
        apply(simp add: MatchLog.IH)
        done
    next
    case (MatchEmpty \<gamma> p m a rs)
      thus ?case
        apply(simp)
        apply(rule_tac t=Undecided in seq_fst)
         apply(simp add: empty)
        apply(simp add: MatchEmpty.IH)
        done
    qed


text{*Henceforth, we will use the @{term approximating_bigstep_fun} semantics, because they are easier.
We show that they are equal.
*}
theorem approximating_semantics_iff_fun: "wf_ruleset \<gamma> p rs \<Longrightarrow>
    \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> approximating_bigstep_fun \<gamma> p rs s = t"
by (metis approximating_fun_imp_semantics approximating_semantics_imp_fun)

corollary approximating_semantics_iff_fun_good_ruleset: "good_ruleset rs \<Longrightarrow>
    \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> approximating_bigstep_fun \<gamma> p rs s = t"
  by (metis approximating_semantics_iff_fun good_imp_wf_ruleset)


lemma approximating_bigstep_deterministic: "\<lbrakk> \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t; \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t' \<rbrakk> \<Longrightarrow> t = t'"
  apply(induction arbitrary: t' rule: approximating_bigstep_induct)
  apply(auto dest: approximating_bigstepD)[6]
by (metis (hide_lams, mono_tags) append_Nil2 approximating_bigstep_fun.simps(1) approximating_bigstep_fun_seq_semantics)


text{*The actions Log and Empty do not modify the packet processing in any way. They can be removed.*}
fun rm_LogEmpty :: "'a rule list \<Rightarrow> 'a rule list" where
  "rm_LogEmpty [] = []" |
  "rm_LogEmpty ((Rule _ Empty)#rs) = rm_LogEmpty rs" |
  "rm_LogEmpty ((Rule _ Log)#rs) = rm_LogEmpty rs" |
  "rm_LogEmpty (r#rs) = r # rm_LogEmpty rs"

lemma rm_LogEmpty_fun_semantics: 
  "approximating_bigstep_fun \<gamma> p (rm_LogEmpty rs) s = approximating_bigstep_fun \<gamma> p rs s"
apply(induction rs)
apply(simp_all)
apply(rename_tac r rs)
apply(case_tac r)
apply(rename_tac m a)
apply(simp)
apply(case_tac a)
apply(simp_all)
apply(case_tac [!] s)
apply(simp_all)
apply (metis Decision_approximating_bigstep_fun)
by (metis Decision_approximating_bigstep_fun)

lemma rm_LogEmpty_seq: "rm_LogEmpty (rs1@rs2) = rm_LogEmpty rs1 @ rm_LogEmpty rs2"
  apply(induction rs1)
  apply(simp_all)
  apply(case_tac a)
  apply(simp_all)
  apply(case_tac x2)
  apply(simp_all)
  done


lemma rm_LogEmpty_semantics: "\<gamma>,p\<turnstile> \<langle>rm_LogEmpty rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t \<longleftrightarrow> \<gamma>,p\<turnstile> \<langle>rs, s\<rangle> \<Rightarrow>\<^sub>\<alpha> t"
apply(rule iffI)

apply(induction rs arbitrary: s t)
apply(simp_all)
apply(case_tac a)
apply(simp)
apply(case_tac x2)
apply(simp_all)
apply(auto intro: approximating_bigstep.intros)
apply(erule seqE_fst, simp add: seq_fst)
apply(erule seqE_fst, simp add: seq_fst)
apply (metis decision log nomatch_fst seq_fst state.exhaust)
apply(erule seqE_fst, simp add: seq_fst)
apply(erule seqE_fst, simp add: seq_fst)
apply(erule seqE_fst, simp add: seq_fst)
apply (metis decision empty nomatch_fst seq_fst state.exhaust)
apply(erule seqE_fst, simp add: seq_fst)

apply(induction rs s t rule: approximating_bigstep_induct)
apply(auto intro: approximating_bigstep.intros)
apply(case_tac a)
apply(auto intro: approximating_bigstep.intros)
apply(drule_tac rs\<^sub>1="rm_LogEmpty rs\<^sub>1" and rs\<^sub>2="rm_LogEmpty rs\<^sub>2" in seq)
apply(simp_all)
using rm_LogEmpty_seq apply metis
done


lemma rm_LogEmpty_simple_but_Reject: 
  "good_ruleset rs \<Longrightarrow> \<forall>r \<in> set (rm_LogEmpty rs). get_action r = Accept \<or> get_action r = Reject \<or> get_action r = Drop"
  apply(induction rs)
  apply(simp_all add: good_ruleset_def simple_ruleset_def)
  apply(clarify)
  apply(case_tac a)
  apply(simp)
  apply(case_tac x2)
  apply(simp_all)
  apply fastforce+
  done

text{*Rewrite @{const Reject} actions to @{const Drop} actions*}
fun rw_Reject :: "'a rule list \<Rightarrow> 'a rule list" where
  "rw_Reject [] = []" |
  "rw_Reject ((Rule m Reject)#rs) = (Rule m Drop)#rw_Reject rs" |
  "rw_Reject (r#rs) = r # rw_Reject rs"


lemma rw_Reject_fun_semantics: 
  "wf_unknown_match_tac \<alpha> \<Longrightarrow> 
  (approximating_bigstep_fun (\<beta>, \<alpha>) p (rw_Reject rs) s = approximating_bigstep_fun (\<beta>, \<alpha>) p rs s)"
apply(induction rs)
 apply(simp_all)
apply(rename_tac r rs)
apply(case_tac r)
apply(rename_tac m a)
apply(simp)
apply(case_tac a)
       apply(simp_all)
       (*the proof from here is very very ugly!!! redo this!!*)
       apply(case_tac [!] s)
               apply(simp_all)
 apply(auto dest: wf_unknown_match_tacD_False1 wf_unknown_match_tacD_False2)
done


lemma rmLogEmpty_rwReject_good_to_simple: "good_ruleset rs \<Longrightarrow> simple_ruleset (rw_Reject (rm_LogEmpty rs))"
  apply(drule rm_LogEmpty_simple_but_Reject)
  apply(simp add: simple_ruleset_def)
  apply(induction rs)
   apply(simp_all)
  apply(rename_tac r rs)
  apply(case_tac r)
  apply(rename_tac m a)
  apply(case_tac a)
         apply(simp_all)
  done


definition optimize_matches :: "('a match_expr \<Rightarrow> 'a match_expr) \<Rightarrow> 'a rule list \<Rightarrow> 'a rule list" where
  "optimize_matches f rs = map (\<lambda>r. Rule (f (get_match r)) (get_action r)) rs"

lemma optimize_matches: "\<forall>m. matches \<gamma> m = matches \<gamma> (f m) \<Longrightarrow> approximating_bigstep_fun \<gamma> p (optimize_matches f rs) s = approximating_bigstep_fun \<gamma> p rs s"
  apply(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct)
     apply(simp add: optimize_matches_def)
    apply(simp add: optimize_matches_def)
   apply(simp add: optimize_matches_def)
  apply(simp add: optimize_matches_def)
  apply(case_tac a)
         apply(simp_all)
  done


lemma optimize_matches_simple_ruleset: "simple_ruleset rs \<Longrightarrow> simple_ruleset (optimize_matches f rs)"
  by(simp add: optimize_matches_def simple_ruleset_def)

lemma optimize_matches_opt_MatchAny_match_expr: "approximating_bigstep_fun \<gamma> p (optimize_matches opt_MatchAny_match_expr rs) s = approximating_bigstep_fun \<gamma> p rs s"
using optimize_matches opt_MatchAny_match_expr_correct by metis

definition optimize_matches_a :: "(action \<Rightarrow> 'a match_expr \<Rightarrow> 'a match_expr) \<Rightarrow> 'a rule list \<Rightarrow> 'a rule list" where
  "optimize_matches_a f rs = map (\<lambda>r. Rule (f (get_action r) (get_match r)) (get_action r)) rs"

lemma optimize_matches_a_simple_ruleset: "simple_ruleset rs \<Longrightarrow> simple_ruleset (optimize_matches_a f rs)"
  by(simp add: optimize_matches_a_def simple_ruleset_def)

lemma optimize_matches_a: "\<forall>a m. matches \<gamma> m a = matches \<gamma> (f a m) a \<Longrightarrow> approximating_bigstep_fun \<gamma> p (optimize_matches_a f rs) s = approximating_bigstep_fun \<gamma> p rs s"
  apply(induction \<gamma> p rs s rule: approximating_bigstep_fun_induct)
     apply(simp add: optimize_matches_a_def)
    apply(simp add: optimize_matches_a_def)
   apply(simp add: optimize_matches_a_def)
  apply(simp add: optimize_matches_a_def)
  apply(case_tac a)
         apply(simp_all)
  done

lemma optimize_matches_a_simplers_very_ugly_helper: "wf_ruleset \<gamma> p rs \<Longrightarrow> simple_ruleset rs \<Longrightarrow>
   \<forall>a m. a = Accept \<or> a = Drop \<longrightarrow> matches \<gamma> (f a m) a = matches \<gamma> m a\<Longrightarrow> 
   approximating_bigstep_fun \<gamma> p (optimize_matches_a f rs) s = approximating_bigstep_fun \<gamma> p rs s"
  apply(cases s)
   prefer 2
   apply(simp add: Decision_approximating_bigstep_fun)
  apply(simp)
  apply(thin_tac "s = ?un")
  apply(induction \<gamma> p rs "Undecided" rule: approximating_bigstep_fun_induct_wf)
        apply(simp_all add: optimize_matches_a_def simple_ruleset_tail)
   apply(simp_all add: simple_ruleset_def)
  apply(safe)
   apply(simp_all)
  done


lemma optimize_matches_a_simplers: "simple_ruleset rs \<Longrightarrow>
   \<forall>a m. a = Accept \<or> a = Drop \<longrightarrow> matches \<gamma> (f a m) a = matches \<gamma> m a\<Longrightarrow> 
   approximating_bigstep_fun \<gamma> p (optimize_matches_a f rs) s = approximating_bigstep_fun \<gamma> p rs s"
apply(frule simple_imp_good_ruleset)
apply(drule good_imp_wf_ruleset)
apply(drule(3) optimize_matches_a_simplers_very_ugly_helper)
done

end
