(*Original Author: Max Haslbeck, 2015*)
theory IPPartitioning
imports "../Common/SetPartitioning"
        "../Common/GroupF"
        "../Primitive_Matchers/Common_Primitive_toString"
        "SimpleFw_Semantics"
        "../afp/Mergesort" (*TODO*)
begin



fun extract_IPSets_generic0 :: "(simple_match \<Rightarrow> 32 word \<times> nat) \<Rightarrow> simple_rule list \<Rightarrow> (32 wordinterval) list" where
  "extract_IPSets_generic0 _ [] = []" |
  "extract_IPSets_generic0 sel ((SimpleRule m _)#ss) = (ipv4_cidr_tuple_to_interval (sel m)) #
                                                       (extract_IPSets_generic0 sel ss)"

lemma extract_IPSets_generic0_length: "length (extract_IPSets_generic0 sel rs) = length rs"
  by(induction rs rule: extract_IPSets_generic0.induct) (simp_all)



(*
The order in which extract_IPSets returns the collected IP ranges heavily influences the running time
of the subsequent algorithms.
For example:
1) iterating through the ruleset and collecting all source and destination ips:
   10:10:49 elapsed time, 38:41:17 cpu time, factor 3.80
2) iterating through the ruleset and first returning all source ips and iterating again and then return all destination ips:
   3:39:56 elapsed time, 21:08:34 cpu time, factor 5.76

To get a more deterministic runtime, we are sorting the output. As a performance optimization, we also remove duplicate entries.
We use mergesort_remdups, which does a mergesort (i.e sorts!) and removes duplicates and mergesort_by_rel which does a mergesort
(without removing duplicates) and allows to specify the relation we use to sort.
In theory, the largest ip ranges (smallest prefix length) should be put first, the following evaluation shows that this may not
be the fastest solution. The reason might be that access_matrix_pretty picks (almost randomly) one IP from the result and
there are fast and slower choices. The faster choices are the ones where the firewall ruleset has a decision very early. 
Therefore, the running time is still a bit unpredictable.

Here is the data:
map ipv4_cidr_tuple_to_interval (mergesort_by_rel (\<lambda> (a1,a2) (b1, b2). (a2, a1) \<le> (b2, b1)) (mergesort_remdups
                        ((map (src \<circ> match_sel) rs) @ (map (dst \<circ> match_sel) rs))))
 (2:47:04 elapsed time, 17:08:01 cpu time, factor 6.15)


map ipv4_cidr_tuple_to_interval (mergesort_remdups ((map (src \<circ> match_sel) rs) @ (map (dst \<circ> match_sel) rs)))
 (2:41:03 elapsed time, 16:56:46 cpu time, factor 6.31)


map ipv4_cidr_tuple_to_interval (mergesort_by_rel (\<lambda> (a1,a2) (b1, b2). (a2, a1) \<le> (b2, b1)) (
                         ((map (src \<circ> match_sel) rs) @ (map (dst \<circ> match_sel) rs)))
 (5:52:28 elapsed time, 41:50:10 cpu time, factor 7.12)


map ipv4_cidr_tuple_to_interval (mergesort_by_rel (op \<le>)
                         ((map (src \<circ> match_sel) rs) @ (map (dst \<circ> match_sel) rs))))
  (3:10:57 elapsed time, 19:12:25 cpu time, factor 6.03)


map ipv4_cidr_tuple_to_interval (mergesort_by_rel (\<lambda> (a1,a2) (b1, b2). (a2, a1) \<le> (b2, b1)) (mergesort_remdups
                        (extract_src_dst_ips rs [])))
 (2:49:57 elapsed time, 17:10:49 cpu time, factor 6.06)

map ipv4_cidr_tuple_to_interval ((mergesort_remdups (extract_src_dst_ips rs [])))
 (2:43:44 elapsed time, 16:57:49 cpu time, factor 6.21)

map ipv4_cidr_tuple_to_interval (mergesort_by_rel (\<lambda> (a1,a2) (b1, b2). (a2, a1) \<ge> (b2, b1)) (mergesort_remdups (extract_src_dst_ips rs [])))
 (2:47:37 elapsed time, 16:54:47 cpu time, factor 6.05)

There is a clear looser: not using mergesort_remdups
There is no clear winner. We will just stick to mergesort_remdups.

*)

(*check the the order of mergesort_remdups did not change*)
lemma "mergesort_remdups [(1::ipv4addr, 2::nat), (8,0), (8,1), (2,2), (2,4), (1,2), (2,2)] = [(1, 2), (2, 2), (2, 4), (8, 0), (8, 1)]" by eval


(*a tail-recursive implementation*)
fun extract_src_dst_ips :: "simple_rule list \<Rightarrow> (ipv4addr \<times> nat) list \<Rightarrow> (ipv4addr \<times> nat) list" where
  "extract_src_dst_ips [] ts = ts" |
  "extract_src_dst_ips ((SimpleRule m _)#ss) ts = extract_src_dst_ips ss  (src m # dst m # ts)"

lemma extract_src_dst_ips_length: "length (extract_src_dst_ips rs acc) = 2*length rs + length acc"
proof(induction rs arbitrary: acc)
case (Cons r rs) thus ?case by(cases r, simp)
qed(simp)

definition extract_IPSets :: "simple_rule list \<Rightarrow> (32 wordinterval) list" where
  "extract_IPSets rs = map ipv4_cidr_tuple_to_interval (mergesort_remdups (extract_src_dst_ips rs []))"
lemma extract_IPSets: "set (extract_IPSets rs) = set (extract_IPSets_generic0 src rs) \<union> set (extract_IPSets_generic0 dst rs)"
proof -
  { fix acc
    have "ipv4_cidr_tuple_to_interval ` set (extract_src_dst_ips rs acc) =
          ipv4_cidr_tuple_to_interval ` set acc \<union> set (extract_IPSets_generic0 src rs) \<union> set (extract_IPSets_generic0 dst rs)"
    proof(induction rs arbitrary: acc)
    case (Cons r rs ) thus ?case
      apply(cases r)
      apply(simp)
      by fast
    qed(simp)
  } thus ?thesis unfolding extract_IPSets_def by(simp_all add: extract_IPSets_def mergesort_remdups_correct)
qed

lemma "(a::nat) div 2 + a mod 2 \<le> a" by fastforce

lemma merge_length: "length (merge l1 l2) \<le> length l1 + length l2"
by(induction l1 l2 rule: merge.induct) auto

lemma merge_list_length: "length (merge_list as ls) \<le> length (concat (as @ ls))"
proof(induction as ls rule: merge_list.induct)
case (5 l1 l2 acc2 ls)
  have "length (merge l2 acc2) \<le> length l2 + length acc2" using merge_length by blast
  with 5 show ?case by simp
qed(simp_all)

lemma mergesort_remdups_length: "length (mergesort_remdups as) \<le> length as"
unfolding mergesort_remdups_def
proof -
  have "concat ([] @ (map (\<lambda>x. [x]) as)) = as" by simp
  with merge_list_length show "length (merge_list [] (map (\<lambda>x. [x]) as)) \<le> length as" by metis
qed

lemma extract_IPSets_length: "length (extract_IPSets rs) \<le> 2 * length rs"
apply(simp add: extract_IPSets_def)
using extract_src_dst_ips_length mergesort_remdups_length by (metis add.right_neutral list.size(3)) 


(*
export_code extract_IPSets in SML
why you no work?
*)


lemma extract_equi0: "set (map wordinterval_to_set (extract_IPSets_generic0 sel rs))
                     = (\<lambda>(base,len). ipv4range_set_from_prefix base len) ` sel ` match_sel ` set rs"
  proof(induction rs)
  case (Cons r rs) thus ?case
    apply(cases r, simp)
    using ipv4range_to_set_ipv4_cidr_tuple_to_interval[simplified ipv4range_to_set_def] by fastforce
  qed(simp)

lemma src_ipPart:
  assumes "ipPartition (set (map wordinterval_to_set (extract_IPSets_generic0 src rs))) A"
          "B \<in> A" "s1 \<in> B" "s2 \<in> B"
  shows "simple_fw rs (p\<lparr>p_src:=s1\<rparr>) = simple_fw rs (p\<lparr>p_src:=s2\<rparr>)"
proof -
  have "\<forall>A \<in> (\<lambda>(base,len). ipv4range_set_from_prefix base len) ` src ` match_sel ` set rs. B \<subseteq> A \<or> B \<inter> A = {} \<Longrightarrow>
      simple_fw rs (p\<lparr>p_src:=s1\<rparr>) = simple_fw rs (p\<lparr>p_src:=s2\<rparr>)"
  proof(induction rs)
    case Nil thus ?case by simp
  next
    case (Cons r rs)
    { fix m
      from `s1 \<in> B` `s2 \<in> B` have 
        "B \<subseteq> (case src m of (x, xa) \<Rightarrow> ipv4range_set_from_prefix x xa) \<or> B \<inter> (case src m of (x, xa) 
                      \<Rightarrow> ipv4range_set_from_prefix x xa) = {} \<Longrightarrow>
             simple_matches m (p\<lparr>p_src := s1\<rparr>) \<longleftrightarrow> simple_matches m (p\<lparr>p_src := s2\<rparr>)"
      apply(cases m)
      apply(rename_tac iiface oiface srca dst proto sports dports)
      apply(case_tac srca)
      apply(simp add: simple_matches.simps)
      by blast
    } note helper=this
    from Cons show ?case
     apply(cases r, rename_tac m a)
     apply(simp)
     apply(case_tac a)
      using helper apply force+
     done
  qed
  thus ?thesis using assms(1) assms(2)
    unfolding ipPartition_def
    by (metis (full_types) Int_commute extract_equi0)
qed

(*basically a copy of src_ipPart*)
lemma dst_ipPart:
  assumes "ipPartition (set (map wordinterval_to_set (extract_IPSets_generic0 dst rs))) A"
          "B \<in> A" "s1 \<in> B" "s2 \<in> B"
  shows "simple_fw rs (p\<lparr>p_dst:=s1\<rparr>) = simple_fw rs (p\<lparr>p_dst:=s2\<rparr>)"
proof -
  have "\<forall>A \<in> (\<lambda>(base,len). ipv4range_set_from_prefix base len) ` dst ` match_sel ` set rs. B \<subseteq> A \<or> B \<inter> A = {} \<Longrightarrow>
      simple_fw rs (p\<lparr>p_dst:=s1\<rparr>) = simple_fw rs (p\<lparr>p_dst:=s2\<rparr>)"
  proof(induction rs)
    case Nil thus ?case by simp
  next
    case (Cons r rs)
    { fix m
      from `s1 \<in> B` `s2 \<in> B` have
        "B \<subseteq> (case dst m of (x, xa) \<Rightarrow> ipv4range_set_from_prefix x xa) \<or> B \<inter> (case dst m of (x, xa) 
                  \<Rightarrow> ipv4range_set_from_prefix x xa) = {} \<Longrightarrow>
         simple_matches m (p\<lparr>p_dst := s1\<rparr>) \<longleftrightarrow> simple_matches m (p\<lparr>p_dst := s2\<rparr>)"
          apply(cases m)
          apply(rename_tac iiface oiface src dsta proto sports dports)
          apply(case_tac dsta)
          apply(simp add: simple_matches.simps)
          by blast
    } note helper=this
    from Cons show ?case
     apply(simp)
     apply(case_tac r, rename_tac m a)
     apply(simp)
     apply(case_tac a)
      using helper apply force+
     done
  qed
  thus ?thesis using assms(1) assms(2)
    unfolding ipPartition_def
    by (metis (full_types) Int_commute extract_equi0)
qed



(* OPTIMIZED PARTITIONING *)

definition wordinterval_list_to_set :: "'a::len wordinterval list \<Rightarrow> 'a::len word set" where
  "wordinterval_list_to_set ws = \<Union> set (map wordinterval_to_set ws)"

lemma wordinterval_list_to_set_compressed: "wordinterval_to_set (wordinterval_compress (foldr wordinterval_union xs Empty_WordInterval)) =
          wordinterval_list_to_set xs"
  proof(induction xs)
  qed(simp_all add: wordinterval_compress wordinterval_list_to_set_def)

fun partIps :: "'a::len wordinterval \<Rightarrow> 'a::len wordinterval list 
                \<Rightarrow> 'a::len wordinterval list" where
  "partIps _ [] = []" |
  "partIps s (t#ts) = (if wordinterval_empty s then (t#ts) else
                        (if wordinterval_empty (wordinterval_intersection s t)
                          then (t#(partIps (wordinterval_setminus s t) ts))
                          else
                            (if wordinterval_empty (wordinterval_setminus t s)
                              then (t#(partIps (wordinterval_setminus s t) ts))
                              else (wordinterval_intersection t s)#((wordinterval_setminus t s)#
                                   (partIps (wordinterval_setminus s t) ts)))))"


lemma "partIps (WordInterval (1::ipv4addr) 1) [WordInterval 0 1] = [WordInterval 1 1, WordInterval 0 0]" by eval

lemma partIps_length: "length (partIps s ts) \<le> (length ts) * 2"
proof(induction ts arbitrary: s)
case Cons thus ?case 
  apply(simp)
  using le_Suc_eq by blast
qed(simp)

fun partitioningIps :: "'a::len wordinterval list \<Rightarrow> 'a::len wordinterval list \<Rightarrow>
                        'a::len wordinterval list" where
  "partitioningIps [] ts = ts" |
  "partitioningIps (s#ss) ts = partIps s (partitioningIps ss ts)"


lemma partitioningIps_length: "length (partitioningIps ss ts) \<le> (2^length ss) * length ts"
proof(induction ss)
case Nil thus ?case by simp
next
case (Cons s ss)
  have "length (partIps s (partitioningIps ss ts)) \<le> length (partitioningIps ss ts) * 2"
    using partIps_length by fast
  with Cons show  ?case by force
qed

lemma partIps_equi: "map wordinterval_to_set (partIps s ts)
       = (partList3 (wordinterval_to_set s) (map wordinterval_to_set ts))"
  proof(induction ts arbitrary: s)
  qed(simp_all)

lemma partitioningIps_equi: "map wordinterval_to_set (partitioningIps ss ts)
       = (partitioning1 (map wordinterval_to_set ss) (map wordinterval_to_set ts))"
  proof(induction ss arbitrary: ts)
  qed(simp_all add: partIps_equi)


           
definition getParts :: "simple_rule list \<Rightarrow> 32 wordinterval list" where
   "getParts rs = partitioningIps (extract_IPSets rs) [wordinterval_UNIV]"

lemma partitioningIps_foldr: "partitioningIps ss ts = foldr partIps ss ts"
  by(induction ss) (simp_all)

lemma getParts_foldr: "getParts rs = foldr partIps (extract_IPSets rs) [wordinterval_UNIV]"
  by(simp add: getParts_def partitioningIps_foldr)

lemma getParts_length: "length (getParts rs) \<le> 2^(2 * length rs)"
proof -
  from partitioningIps_length[where ss="extract_IPSets rs" and ts="[wordinterval_UNIV]"] have
    1: "length (partitioningIps (extract_IPSets rs) [wordinterval_UNIV]) \<le> 2 ^ length (extract_IPSets rs)" by simp
  from extract_IPSets_length have "(2::nat) ^ length (extract_IPSets rs) \<le> 2 ^ (2 * length rs)" by simp
  with 1 have "length (partitioningIps (extract_IPSets rs) [wordinterval_UNIV]) \<le> 2 ^ (2 * length rs)" by linarith
  thus ?thesis by(simp add: getParts_def) 
qed

lemma getParts_ipPartition: "ipPartition (set (map wordinterval_to_set (extract_IPSets rs)))
                                         (set (map wordinterval_to_set (getParts rs)))"
proof -
  have "{} \<notin> set (map wordinterval_to_set ts) \<Longrightarrow> disjoint_list_rec (map wordinterval_to_set ts) \<Longrightarrow> 
     (wordinterval_list_to_set ss) \<subseteq> (wordinterval_list_to_set ts) \<Longrightarrow> 
     ipPartition (set (map wordinterval_to_set ss)) 
                 (set (map wordinterval_to_set (partitioningIps ss ts)))" for ts ss::"32 wordinterval list"
  by (metis ipPartitioning_helper_opt partitioningIps_equi wordinterval_list_to_set_def)
  hence "ipPartition (set (map wordinterval_to_set ss)) 
                   (set (map wordinterval_to_set (partitioningIps ss [wordinterval_UNIV])))"
     for ss::"32 wordinterval list"
  by(simp add: wordinterval_list_to_set_def)
  thus ?thesis
  unfolding getParts_def by blast
qed


lemma getParts_complete: "wordinterval_list_to_set (getParts rs) = UNIV"
  proof -
  have "{} \<notin> set (map wordinterval_to_set ts) \<Longrightarrow> disjoint_list_rec (map wordinterval_to_set ts) \<Longrightarrow> 
     (wordinterval_list_to_set ss) \<subseteq> (wordinterval_list_to_set ts) \<Longrightarrow> 
     wordinterval_list_to_set (partitioningIps ss ts) = (wordinterval_list_to_set ts)"
     for ss ts::"32 wordinterval list"
    using complete_helper by (metis partitioningIps_equi wordinterval_list_to_set_def)
  hence "wordinterval_list_to_set (getParts rs) = wordinterval_list_to_set [wordinterval_UNIV]"
    unfolding getParts_def by(simp add: wordinterval_list_to_set_def)
  also have "\<dots> = UNIV" by (simp add: wordinterval_list_to_set_def)
  finally show ?thesis .
qed

lemma getParts_disjoint: "disjoint_list_rec (map wordinterval_to_set (getParts rs))"
 proof -
  have disjoint_partitioningIps: 
    "{} \<notin> set (map wordinterval_to_set ts) \<Longrightarrow> disjoint_list_rec (map wordinterval_to_set ts) \<Longrightarrow> 
     (wordinterval_list_to_set ss) \<subseteq> (wordinterval_list_to_set ts) \<Longrightarrow>
     disjoint_list_rec (map wordinterval_to_set (partitioningIps ss ts))"
  for ss ts::"32 wordinterval list"
    by (simp add: partitioning1_disjoint partitioningIps_equi wordinterval_list_to_set_def)
  thus ?thesis by(simp add: getParts_def wordinterval_list_to_set_def)
qed


theorem getParts_samefw: 
  assumes "A \<in> set (map wordinterval_to_set (getParts rs))" "s1 \<in> A" "s2 \<in> A" 
  shows "simple_fw rs (p\<lparr>p_src:=s1\<rparr>) = simple_fw rs (p\<lparr>p_src:=s2\<rparr>) \<and>
         simple_fw rs (p\<lparr>p_dst:=s1\<rparr>) = simple_fw rs (p\<lparr>p_dst:=s2\<rparr>)"
proof -
  let ?X="(set (map wordinterval_to_set (getParts rs)))"
  from getParts_ipPartition have "ipPartition (set (map wordinterval_to_set (extract_IPSets rs))) ?X" .
  hence "ipPartition (set (map wordinterval_to_set (extract_IPSets_generic0 src rs))) ?X \<and>
         ipPartition (set (map wordinterval_to_set (extract_IPSets_generic0 dst rs))) ?X"
    by(simp add: extract_IPSets ipPartitionUnion image_Un)
  thus ?thesis using assms dst_ipPart src_ipPart by blast
qed


lemma partIps_nonempty: "ts \<noteq> [] \<Longrightarrow> partIps s ts \<noteq> []"
  by(induction ts arbitrary: s) simp_all
lemma partitioningIps_nonempty: "ts \<noteq> [] \<Longrightarrow> partitioningIps ss ts \<noteq> []"
proof(induction ss arbitrary: ts)
  case Nil thus ?case by simp
  next
  case (Cons s ss) thus ?case
    apply(cases ts)
     apply(simp; fail)
    apply(simp)
    using partIps_nonempty by blast
qed

(*
lemma partIps_nonempty: "\<forall>t \<in> set ts. \<not> wordinterval_empty t 
       \<Longrightarrow> {} \<notin> set (map wordinterval_to_set (partIps s ts))"
  apply(induction ts arbitrary: s)
   apply(simp; fail)
  apply(simp)
  by blast
*)

lemma getParts_nonempty: "getParts rs \<noteq> []" by(simp add: getParts_def partitioningIps_nonempty)
lemma getParts_nonempty_elems: "\<forall>w\<in>set (getParts rs). \<not> wordinterval_empty w"
  unfolding getParts_def
  proof -
    have partitioning_nonempty: "\<forall>t \<in> set ts. \<not> wordinterval_empty t \<Longrightarrow>
      {} \<notin> set (map wordinterval_to_set (partitioningIps ss ts))"
      for ts ss::"32 wordinterval list"
      proof(induction ss arbitrary: ts)
        case Nil thus ?case by auto
        case Cons thus ?case by (simp add: partIps_equi partList3_empty)
      qed
    have "\<forall>t \<in> set [wordinterval_UNIV].\<not> wordinterval_empty t" by(simp)
    with partitioning_nonempty have
      "{} \<notin> set (map wordinterval_to_set (partitioningIps (extract_IPSets rs) [wordinterval_UNIV]))" 
      by blast
    thus "\<forall>w\<in>set (partitioningIps (extract_IPSets rs) [wordinterval_UNIV]). \<not> wordinterval_empty w" by auto
  qed

(* HELPER FUNCTIONS UNIFICATION *)

fun getOneIp :: "'a::len wordinterval \<Rightarrow> 'a::len word" where
  "getOneIp (WordInterval b _) = b" |
  "getOneIp (RangeUnion r1 r2) = (if wordinterval_empty r1 then getOneIp r2
                                                           else getOneIp r1)"

lemma getOneIp_elem: "\<not> wordinterval_empty W \<Longrightarrow> wordinterval_element (getOneIp W) W"
  by (induction W) simp_all

record parts_connection = pc_iiface :: string
                          pc_oiface :: string
                          pc_proto :: primitive_protocol
                          pc_sport :: "16 word"
                          pc_dport :: "16 word"
                          pc_tag_ctstate :: ctstate



(* SAME FW DEFINITIONS AND PROOFS *)



definition same_fw_behaviour :: "32 word \<Rightarrow> 32 word \<Rightarrow> simple_rule list \<Rightarrow> bool" where
  "same_fw_behaviour a b rs \<equiv> \<forall>p. simple_fw rs (p\<lparr>p_src:=a\<rparr>) = simple_fw rs (p\<lparr>p_src:=b\<rparr>) \<and>
                                  simple_fw rs (p\<lparr>p_dst:=a\<rparr>) = simple_fw rs (p\<lparr>p_dst:=b\<rparr>)"

lemma getParts_same_fw_behaviour:
  "A \<in> set (map wordinterval_to_set (getParts rs)) \<Longrightarrow>  s1 \<in> A \<Longrightarrow> s2 \<in> A \<Longrightarrow> 
   same_fw_behaviour s1 s2 rs"
  unfolding same_fw_behaviour_def
  using getParts_samefw by blast

definition "runFw s d c rs = simple_fw rs \<lparr>p_iiface=pc_iiface c,p_oiface=pc_oiface c,
                          p_src=s,p_dst=d,
                          p_proto=pc_proto c,
                          p_sport=pc_sport c,p_dport=pc_dport c,
                          p_tcp_flags={TCP_SYN},
                          p_tag_ctstate=pc_tag_ctstate c\<rparr>"

lemma has_default_policy_runFw: "has_default_policy rs \<Longrightarrow> runFw s d c rs = Decision FinalAllow \<or> runFw s d c rs = Decision FinalDeny"
  by(simp add: runFw_def has_default_policy)

definition "same_fw_behaviour_one ip1 ip2 c rs \<equiv>
            \<forall>d s. runFw ip1 d c rs = runFw ip2 d c rs \<and> runFw s ip1 c rs = runFw s ip2 c rs"

lemma same_fw_spec: "same_fw_behaviour ip1 ip2 rs \<Longrightarrow> same_fw_behaviour_one ip1 ip2 c rs"
  apply(simp add: same_fw_behaviour_def same_fw_behaviour_one_def runFw_def)
  apply(rule conjI)
   apply(clarify)
   apply(erule_tac x="\<lparr>p_iiface = pc_iiface c, p_oiface = pc_oiface c, p_src = ip1, p_dst= d,
                       p_proto = pc_proto c, p_sport = pc_sport c, p_dport = pc_dport c,
                       p_tcp_flags = {TCP_SYN},
                       p_tag_ctstate = pc_tag_ctstate c\<rparr>" in allE)
   apply(simp;fail)
  apply(clarify)
  apply(erule_tac x="\<lparr>p_iiface = pc_iiface c, p_oiface = pc_oiface c, p_src = s, p_dst= ip1,
                       p_proto = pc_proto c, p_sport = pc_sport c, p_dport = pc_dport c,
                       p_tcp_flags = {TCP_SYN},
                       p_tag_ctstate = pc_tag_ctstate c\<rparr>" in allE)
  apply(simp)
  done

text{*Is an equivalence relation*}
lemma same_fw_behaviour_one_equi:
  "same_fw_behaviour_one x x c rs"
  "same_fw_behaviour_one x y c rs = same_fw_behaviour_one y x c rs"
  "same_fw_behaviour_one x y c rs \<and> same_fw_behaviour_one y z c rs \<Longrightarrow> same_fw_behaviour_one x z c rs"
  unfolding same_fw_behaviour_one_def by metis+

lemma same_fw_behaviour_equi:
  "same_fw_behaviour x x rs"
  "same_fw_behaviour x y rs = same_fw_behaviour y x rs"
  "same_fw_behaviour x y rs \<and> same_fw_behaviour y z rs \<Longrightarrow> same_fw_behaviour x z rs"
  unfolding same_fw_behaviour_def by auto

lemma runFw_sameFw_behave: 
       "\<forall>A \<in> W. \<forall>a1 \<in> A. \<forall>a2 \<in> A. same_fw_behaviour_one a1 a2 c rs \<Longrightarrow> \<Union> W = UNIV \<Longrightarrow>
       \<forall>B \<in> W. \<exists>b \<in> B. runFw ip1 b c rs = runFw ip2 b c rs \<Longrightarrow>
       \<forall>B \<in> W. \<exists>b \<in> B. runFw b ip1 c rs = runFw b ip2 c rs \<Longrightarrow>
       same_fw_behaviour_one ip1 ip2 c rs"
proof -
  assume a1: "\<forall>A \<in> W. \<forall>a1 \<in> A. \<forall>a2 \<in> A. same_fw_behaviour_one a1 a2 c rs"
   and a2: "\<Union> W = UNIV "
   and a3: "\<forall>B \<in> W. \<exists>b \<in> B. runFw ip1 b c rs = runFw ip2 b c rs"
   and a4: "\<forall>B \<in> W. \<exists>b \<in> B. runFw b ip1 c rs = runFw b ip2 c rs"

   
  have relation_lem: "\<forall>D \<in> W. \<forall>d1 \<in> D. \<forall>d2 \<in> D. \<forall>s. f s d1 = f s d2 \<Longrightarrow> \<Union> W = UNIV \<Longrightarrow>
                     \<forall>B \<in> W. \<exists>b \<in> B. f s1 b = f s2 b \<Longrightarrow>
                     f s1 d = f s2 d" for W and f::"'c \<Rightarrow> 'b \<Rightarrow> 'd" and s1 d s2
    by (metis UNIV_I Union_iff)

  from a1 have a1':"\<forall>A\<in>W. \<forall>a1\<in>A. \<forall>a2\<in>A. \<forall>s. runFw s a1 c rs = runFw s a2 c rs"
    unfolding same_fw_behaviour_one_def by fast
  from relation_lem[OF a1' a2 a3] have s1: "\<And> d. runFw ip1 d c rs = runFw ip2 d c rs" by simp

  from a1 have a1'':"\<forall>A\<in>W. \<forall>a1\<in>A. \<forall>a2\<in>A. \<forall>d. runFw a1 d c rs = runFw a2 d c rs"
    unfolding same_fw_behaviour_one_def by fast
  from relation_lem[OF a1'' a2 a4] have s2: "\<And> s. runFw s ip1 c rs = runFw s ip2 c rs" by simp
  from s1 s2 show "same_fw_behaviour_one ip1 ip2 c rs"
    unfolding same_fw_behaviour_one_def by fast
qed

lemma sameFw_behave_sets:
  "\<forall>w\<in>set A. \<forall>a1 \<in> w. \<forall>a2 \<in> w. same_fw_behaviour_one a1 a2 c rs \<Longrightarrow>
   \<forall>w1\<in>set A. \<forall>w2\<in>set A. \<exists>a1\<in>w1. \<exists>a2\<in>w2. same_fw_behaviour_one a1 a2 c rs \<Longrightarrow>
   \<forall>w1\<in>set A. \<forall>w2\<in>set A.
     \<forall>a1\<in>w1. \<forall>a2\<in>w2. same_fw_behaviour_one a1 a2 c rs"
proof -
  assume a1: "\<forall>w\<in>set A. \<forall>a1 \<in> w. \<forall>a2 \<in> w. same_fw_behaviour_one a1 a2 c rs" and
         "\<forall>w1\<in>set A. \<forall>w2\<in>set A. \<exists>a1\<in>w1. \<exists>a2\<in>w2.  same_fw_behaviour_one a1 a2 c rs"
  from this have "\<forall>w1\<in>set A. \<forall>w2\<in>set A. \<exists>a1\<in>w1. \<forall>a2\<in>w2.  same_fw_behaviour_one a1 a2 c rs"
    using same_fw_behaviour_one_equi(3) by metis
  from a1 this show "\<forall>w1\<in>set A. \<forall>w2\<in>set A. \<forall>a1\<in>w1. \<forall>a2\<in>w2. same_fw_behaviour_one a1 a2 c rs"
    using same_fw_behaviour_one_equi(3) by metis
qed
  
lemma same_behave_runFw:
  assumes a1: "\<forall>A \<in> set (map wordinterval_to_set W). \<forall>a1 \<in> A. \<forall>a2 \<in> A. same_fw_behaviour_one a1 a2 c rs"
  and a2: "wordinterval_list_to_set W = UNIV"
  and a3: "\<forall>w \<in> set W. \<not> wordinterval_empty w"
  and a4: "(map (\<lambda>d. runFw x1 d c rs) (map getOneIp W), map (\<lambda>s. runFw s x1 c rs) (map getOneIp W)) =
           (map (\<lambda>d. runFw x2 d c rs) (map getOneIp W), map (\<lambda>s. runFw s x2 c rs) (map getOneIp W))"
  shows "same_fw_behaviour_one x1 x2 c rs"
proof -
  from a3 a4 getOneIp_elem
    have b1: "\<forall>B \<in> set (map wordinterval_to_set W). \<exists>b \<in> B. runFw x1 b c rs = runFw x2 b c rs"
    by fastforce
  from a3 a4 getOneIp_elem
    have b2: "\<forall>B \<in> set (map wordinterval_to_set W). \<exists>b \<in> B. runFw b x1 c rs = runFw b x2 c rs"
    by fastforce
  from runFw_sameFw_behave[OF a1 _ b1 b2] a2[unfolded wordinterval_list_to_set_def] show "same_fw_behaviour_one x1 x2 c rs" by simp
qed

lemma same_behave_runFw_not:
      "(map (\<lambda>d. runFw x1 d c rs) W, map (\<lambda>s. runFw s x1 c rs) W) \<noteq>
       (map (\<lambda>d. runFw x2 d c rs) W, map (\<lambda>s. runFw s x2 c rs) W) \<Longrightarrow>
       \<not> same_fw_behaviour_one x1 x2 c rs"
by (simp add: same_fw_behaviour_one_def) (blast)




definition groupWIs :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list list" where
  "groupWIs c rs = (let W = getParts rs in 
                       (let f = (\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c rs) (map getOneIp W),
                                      map (\<lambda>s. runFw s (getOneIp wi) c rs) (map getOneIp W))) in
                       groupF f W))"



lemma groupWIs_not_empty: "groupWIs c rs \<noteq> []"
  proof -
    have "getParts rs \<noteq> []" by(simp add: getParts_def partitioningIps_nonempty)
    with groupF_empty have "\<And>f. groupF f (getParts rs) \<noteq> []" by blast
    thus ?thesis by(simp add: groupWIs_def Let_def) blast
  qed
lemma groupWIs_not_empty_elem: "V \<in> set (groupWIs c rs) \<Longrightarrow> V \<noteq> []"
  by(simp add: groupWIs_def Let_def groupF_empty_elem)
lemma groupWIs_not_empty_elems: 
  assumes V: "V \<in> set (groupWIs c rs)" and w: "w \<in> set V"
  shows "\<not> wordinterval_empty w"
  proof -
    have "\<forall>w\<in>set (concat (groupWIs c rs)). \<not> wordinterval_empty w"
      apply(subst groupWIs_def)
      apply(subst Let_def)+
      apply(subst groupF_set_lem)
      using getParts_nonempty_elems by blast
    from this V w show ?thesis by auto
  qed

lemma groupParts_same_fw_wi0:
    assumes "V \<in> set (groupWIs c rs)"
    shows "\<forall>w \<in> set (map wordinterval_to_set V). \<forall>a1 \<in> w. \<forall>a2 \<in> w. same_fw_behaviour_one a1 a2 c rs"
proof -
  have "\<forall>A\<in>set (map wordinterval_to_set (concat (groupWIs c rs))). 
        \<forall>a1\<in>A. \<forall>a2\<in>A. same_fw_behaviour_one a1 a2 c rs"
    apply(subst groupWIs_def)
    apply(subst Let_def)+
    apply(subst set_map)
    apply(subst groupF_set_lem)
    using getParts_same_fw_behaviour same_fw_spec by fastforce
  from this assms show ?thesis by force
qed

lemma groupWIs_same_fw_not: "A \<in> set (groupWIs c rs) \<Longrightarrow> B \<in> set (groupWIs c rs) \<Longrightarrow> 
                            A \<noteq> B \<Longrightarrow>
                             \<forall>aw \<in> set (map wordinterval_to_set A).
                             \<forall>bw \<in> set (map wordinterval_to_set B).
                             \<forall>a \<in> aw. \<forall>b \<in> bw. \<not> same_fw_behaviour_one a b c rs"
proof -
  assume asm: "A \<in> set (groupWIs c rs)" "B \<in> set (groupWIs c rs)" "A \<noteq> B"
  from this have b1: "\<forall>aw \<in> set A. \<forall>bw \<in> set B.
                  (map (\<lambda>d. runFw (getOneIp aw) d c rs) (map getOneIp (getParts rs)),
                   map (\<lambda>s. runFw s (getOneIp aw) c rs) (map getOneIp (getParts rs))) \<noteq>
                  (map (\<lambda>d. runFw (getOneIp bw) d c rs) (map getOneIp (getParts rs)),
                   map (\<lambda>s. runFw s (getOneIp bw) c rs) (map getOneIp (getParts rs)))"
    apply(simp add: groupWIs_def Let_def)
    using groupF_lem_not by fastforce
  have "\<forall>C \<in> set (groupWIs c rs). \<forall>c \<in> set C. getOneIp c \<in> wordinterval_to_set c"
    apply(simp add: groupWIs_def Let_def)
    using getParts_nonempty_elems groupF_set_lem1 getOneIp_elem by fastforce
  from this b1 asm have
  "\<forall>aw \<in> set (map wordinterval_to_set A). \<forall>bw \<in> set (map wordinterval_to_set B).
   \<exists>a \<in> aw. \<exists>b \<in> bw. (map (\<lambda>d. runFw a d c rs) (map getOneIp (getParts rs)), map (\<lambda>s. runFw s a c rs) (map getOneIp (getParts rs))) \<noteq>
    (map (\<lambda>d. runFw b d c rs) (map getOneIp (getParts rs)), map (\<lambda>s. runFw s b c rs) (map getOneIp (getParts rs)))"
   by (simp) (blast)
  from this same_behave_runFw_not asm
  have " \<forall>aw \<in> set (map wordinterval_to_set A). \<forall>bw \<in> set (map wordinterval_to_set B).
         \<exists>a \<in> aw. \<exists>b \<in> bw. \<not> same_fw_behaviour_one a b c rs" by fast
  from this groupParts_same_fw_wi0[of A c rs]  groupParts_same_fw_wi0[of B c rs] asm
  have "\<forall>aw \<in> set (map wordinterval_to_set A).
        \<forall>bw \<in> set (map wordinterval_to_set B).
        \<forall>a \<in> aw. \<exists>b \<in> bw. \<not> same_fw_behaviour_one a b c rs"
    apply(simp) using same_fw_behaviour_one_equi(3) by blast
  from this groupParts_same_fw_wi0[of A c rs]  groupParts_same_fw_wi0[of B c rs] asm
  show "\<forall>aw \<in> set (map wordinterval_to_set A).
        \<forall>bw \<in> set (map wordinterval_to_set B).
        \<forall>a \<in> aw. \<forall>b \<in> bw. \<not> same_fw_behaviour_one a b c rs"
    apply(simp) using same_fw_behaviour_one_equi(3) by fast
qed





(*beginning is copy&paste of previous proof*)
lemma groupParts_same_fw_wi1:
  "V \<in> set (groupWIs c rs) \<Longrightarrow> \<forall>w1 \<in> set V. \<forall>w2 \<in> set V.
     \<forall>a1 \<in> wordinterval_to_set w1. \<forall>a2 \<in> wordinterval_to_set w2. same_fw_behaviour_one a1 a2 c rs"
proof -
  assume asm: "V \<in> set (groupWIs c rs)"
  from getParts_same_fw_behaviour same_fw_spec
    have b1: "\<forall>A \<in> set (map wordinterval_to_set (getParts rs)) . \<forall>a1 \<in> A. \<forall>a2 \<in> A.
              same_fw_behaviour_one a1 a2 c rs" by fast
  from getParts_nonempty_elems have "\<forall>w\<in>set (getParts rs). \<not> wordinterval_empty w" by simp
  from same_behave_runFw[OF b1 getParts_complete this]
       groupF_lem[of "(\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c rs) (map getOneIp (getParts rs)),
                             map (\<lambda>s. runFw s (getOneIp wi) c rs) (map getOneIp (getParts rs))))"
                     "(getParts rs)"] asm
  have b2: "\<forall>a1\<in>set V. \<forall>a2\<in>set V. same_fw_behaviour_one (getOneIp a1) (getOneIp a2) c rs"
    apply(subst (asm) groupWIs_def)
    apply(subst (asm) Let_def)+
    by fast
  from groupWIs_not_empty_elems asm have "\<forall>w \<in> set V. \<not> wordinterval_empty w" by simp
  from this b2 getOneIp_elem
    have b3: "\<forall>w1\<in>set (map wordinterval_to_set V). \<forall>w2\<in>set (map wordinterval_to_set V). 
           \<exists>ip1\<in> w1. \<exists>ip2\<in>w2.
           same_fw_behaviour_one ip1 ip2 c rs" by (simp) (blast)
  from groupParts_same_fw_wi0 asm 
    have "\<forall>A\<in>set (map wordinterval_to_set V). \<forall>a1\<in> A. \<forall>a2\<in> A. same_fw_behaviour_one a1 a2 c rs" 
    by metis
  from sameFw_behave_sets[OF this b3]
  show "\<forall>w1 \<in> set V. \<forall>w2 \<in> set V.
   \<forall>a1 \<in> wordinterval_to_set w1. \<forall>a2 \<in> wordinterval_to_set w2. same_fw_behaviour_one a1 a2 c rs"
  by force
qed

lemma groupParts_same_fw_wi2: "V \<in> set (groupWIs c rs) \<Longrightarrow>
                               \<forall>ip1 \<in> wordinterval_list_to_set V.
                               \<forall>ip2 \<in> wordinterval_list_to_set V.
                               same_fw_behaviour_one ip1 ip2 c rs"
  using groupParts_same_fw_wi0 groupParts_same_fw_wi1 by (simp add: wordinterval_list_to_set_def)

lemma groupWIs_same_fw_not2: "A \<in> set (groupWIs c rs) \<Longrightarrow> B \<in> set (groupWIs c rs) \<Longrightarrow> 
                                A \<noteq> B \<Longrightarrow>
                                \<forall>ip1 \<in> wordinterval_list_to_set A.
                                \<forall>ip2 \<in> wordinterval_list_to_set B.
                                \<not> same_fw_behaviour_one ip1 ip2 c rs"
  apply(simp add: wordinterval_list_to_set_def)
  using groupWIs_same_fw_not by simp

(*I like this version -- corny*)
lemma "A \<in> set (groupWIs c rs) \<Longrightarrow> B \<in> set (groupWIs c rs) \<Longrightarrow> 
                \<exists>ip1 \<in> wordinterval_list_to_set A.
                \<exists>ip2 \<in> wordinterval_list_to_set B. same_fw_behaviour_one ip1 ip2 c rs
                \<Longrightarrow> A = B"
using groupWIs_same_fw_not2 by blast


lemma groupWIs_complete: "(\<Union>x\<in> set (groupWIs c rs). wordinterval_list_to_set x) = (UNIV::ipv4addr set)"
  proof -
  have "(\<Union> y \<in> (\<Union>x\<in> set (groupWIs c rs). set x). wordinterval_to_set y) = (UNIV::ipv4addr set)"
    apply(simp add: groupWIs_def Let_def groupF_set_Union_lem)
    using getParts_complete wordinterval_list_to_set_def by fastforce
  thus ?thesis by(simp add: wordinterval_list_to_set_def)
qed


(*begin groupWIs1 and groupWIs2 optimization*)
  (*TODO*)
  definition groupWIs1 :: "'a parts_connection_scheme \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list list" where
    "groupWIs1 c rs = (let P = getParts rs in
                        (let W = map getOneIp P in 
                         (let f = (\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c rs) W,
                                         map (\<lambda>s. runFw s (getOneIp wi) c rs) W)) in
                        map (map fst) (groupF snd (map (\<lambda>x. (x, f x)) P)))))"
  
  lemma groupWIs_groupWIs1_equi: "groupWIs1 c rs = groupWIs c rs"
    apply(subst groupWIs1_def)
    apply(subst groupWIs_def)
  using groupF_tuple by metis
  
  definition simple_conn_matches :: "simple_match \<Rightarrow> parts_connection \<Rightarrow> bool" where
      "simple_conn_matches m c \<longleftrightarrow>
        (match_iface (iiface m) (pc_iiface c)) \<and>
        (match_iface (oiface m) (pc_oiface c)) \<and>
        (match_proto (proto m) (pc_proto c)) \<and>
        (simple_match_port (sports m) (pc_sport c)) \<and>
        (simple_match_port (dports m) (pc_dport c))"
  
  lemma simple_conn_matches_simple_match_any: "simple_conn_matches simple_match_any c"
    apply(simp add: simple_conn_matches_def)
    apply(simp add: simple_match_any_def ipv4range_set_from_prefix_0 match_ifaceAny)
    apply(subgoal_tac "(65535::16 word) = max_word")
     apply(simp)
    by(simp add: max_word_def)
  
  lemma has_default_policy_simple_conn_matches:
    "has_default_policy rs \<Longrightarrow> has_default_policy [r\<leftarrow>rs . simple_conn_matches (match_sel r) c]"
    apply(induction rs rule: has_default_policy.induct)
      apply(simp; fail)
     apply(simp add: simple_conn_matches_simple_match_any; fail)
    apply(simp)
    apply(intro conjI)
     apply(simp split: split_if_asm; fail)
    apply(simp add: has_default_policy_fst split: split_if_asm)
    done
  
  
  lemma filter_conn_fw_lem: 
    "runFw s d c (filter (\<lambda>r. simple_conn_matches (match_sel r) c) rs) = runFw s d c rs"
    apply(simp add: runFw_def simple_conn_matches_def match_sel_def)
    apply(induction rs "\<lparr>p_iiface = pc_iiface c, p_oiface = pc_oiface c,
                         p_src = s, p_dst = d, p_proto = pc_proto c, 
                         p_sport = pc_sport c, p_dport = pc_dport c,
                         p_tcp_flags = {TCP_SYN},
                         p_tag_ctstate = pc_tag_ctstate c\<rparr>"
          rule: simple_fw.induct)
    apply(simp add: simple_matches.simps)+
  done
  
  
  (*performance: despite optimization, this function takes quite long and can be optimized*)
  definition groupWIs2 :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list list" where
    "groupWIs2 c rs =  (let P = getParts rs in
                         (let W = map getOneIp P in 
                         (let filterW = (filter (\<lambda>r. simple_conn_matches (match_sel r) c) rs) in
                           (let f = (\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c filterW) W,
                                           map (\<lambda>s. runFw s (getOneIp wi) c filterW) W)) in
                        map (map fst) (groupF snd (map (\<lambda>x. (x, f x)) P))))))"
  
  lemma groupWIs1_groupWIs2_equi: "groupWIs2 c rs = groupWIs1 c rs"
    by(simp add: groupWIs2_def groupWIs1_def filter_conn_fw_lem)
  
  
  lemma groupWIs_code[code]: "groupWIs c rs = groupWIs2 c rs"
    using groupWIs1_groupWIs2_equi groupWIs_groupWIs1_equi by metis
(*end groupWIs1 and groupWIs2 optimization*)


(*begin groupWIs3 optimization*)
  fun matching_dsts :: "ipv4addr \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval \<Rightarrow> 32 wordinterval" where
    "matching_dsts _ [] _ = Empty_WordInterval" |
    "matching_dsts s ((SimpleRule m Accept)#rs) acc_dropped =
        (if simple_match_ip (src m) s then
           wordinterval_union (wordinterval_setminus (ipv4_cidr_tuple_to_interval (dst m)) acc_dropped) (matching_dsts s rs acc_dropped)
         else
           matching_dsts s rs acc_dropped)" |
    "matching_dsts s ((SimpleRule m Drop)#rs) acc_dropped =
        (if simple_match_ip (src m) s then
           matching_dsts s rs (wordinterval_union (ipv4_cidr_tuple_to_interval (dst m)) acc_dropped)
         else
           matching_dsts s rs acc_dropped)"
  
  lemma matching_dsts_pull_out_accu:
    "wordinterval_to_set (matching_dsts s rs (wordinterval_union a1 a2)) = wordinterval_to_set (matching_dsts s rs a2) - wordinterval_to_set a1"
    apply(induction s rs a2 arbitrary: a1 a2 rule: matching_dsts.induct)
       apply(simp_all)
    by blast+
  
  (*a copy of matching_dsts*)
  fun matching_srcs :: "ipv4addr \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval \<Rightarrow> 32 wordinterval" where
    "matching_srcs _ [] _ = Empty_WordInterval" |
    "matching_srcs d ((SimpleRule m Accept)#rs) acc_dropped =
        (if simple_match_ip (dst m) d then
           wordinterval_union (wordinterval_setminus (ipv4_cidr_tuple_to_interval (src m)) acc_dropped) (matching_srcs d rs acc_dropped)
         else
           matching_srcs d rs acc_dropped)" |
    "matching_srcs d ((SimpleRule m Drop)#rs) acc_dropped =
        (if simple_match_ip (dst m) d then
           matching_srcs d rs (wordinterval_union (ipv4_cidr_tuple_to_interval (src m)) acc_dropped)
         else
           matching_srcs d rs acc_dropped)"
  
  lemma matching_srcs_pull_out_accu:
    "wordinterval_to_set (matching_srcs d rs (wordinterval_union a1 a2)) = wordinterval_to_set (matching_srcs d rs a2) - wordinterval_to_set a1"
    apply(induction d rs a2 arbitrary: a1 a2 rule: matching_srcs.induct)
       apply(simp_all)
    by blast+
  
  
  lemma matching_dsts: "\<forall>r \<in> set rs. simple_conn_matches (match_sel r) c \<Longrightarrow>
          wordinterval_to_set (matching_dsts s rs Empty_WordInterval) = {d. runFw s d c rs = Decision FinalAllow}"
    proof(induction rs)
    case Nil thus ?case by (simp add: runFw_def)
    next
    case (Cons r rs)
      obtain m a where r: "r = SimpleRule m a" by(cases r, blast)
      
      from Cons.prems r have simple_match_ip_Accept: "\<And>d. simple_match_ip (src m) s \<Longrightarrow>
        runFw s d c (SimpleRule m Accept # rs) = Decision FinalAllow \<longleftrightarrow> simple_match_ip (dst m) d \<or> runFw s d c rs = Decision FinalAllow"
        by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)
  
      { fix d a
        have "\<not> simple_match_ip (src m) s \<Longrightarrow>
         runFw s d c (SimpleRule m a # rs) = Decision FinalAllow \<longleftrightarrow> runFw s d c rs = Decision FinalAllow"
        apply(cases a)
         by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)+
       } note not_simple_match_ip=this
  
      from Cons.prems r have simple_match_ip_Drop: "\<And>d. simple_match_ip (src m) s \<Longrightarrow>
             runFw s d c (SimpleRule m Drop # rs) = Decision FinalAllow \<longleftrightarrow> \<not> simple_match_ip (dst m) d \<and> runFw s d c rs = Decision FinalAllow"
        by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)
  
      show ?case
        proof(cases a)
        case Accept with r Cons show ?thesis
         apply(simp, intro conjI impI)
          apply(simp add: simple_match_ip_Accept wordinterval_to_set_ipv4_cidr_tuple_to_interval_simple_match_ip_set)
          apply blast
         apply(simp add: not_simple_match_ip; fail)
         done
        next
        case Drop with r Cons show ?thesis
          apply(simp,intro conjI impI)
           apply(simp add: simple_match_ip_Drop matching_dsts_pull_out_accu wordinterval_to_set_ipv4_cidr_tuple_to_interval_simple_match_ip_set)
           apply blast
          apply(simp add: not_simple_match_ip; fail)
         done
        qed
    qed
  lemma matching_srcs: "\<forall>r \<in> set rs. simple_conn_matches (match_sel r) c \<Longrightarrow>
          wordinterval_to_set (matching_srcs d rs Empty_WordInterval) = {s. runFw s d c rs = Decision FinalAllow}"
    proof(induction rs)
    case Nil thus ?case by (simp add: runFw_def)
    next
    case (Cons r rs)
      obtain m a where r: "r = SimpleRule m a" by(cases r, blast)
      
      from Cons.prems r have simple_match_ip_Accept: "\<And>s. simple_match_ip (dst m) d \<Longrightarrow>
         runFw s d c (SimpleRule m simple_action.Accept # rs) = Decision FinalAllow \<longleftrightarrow> simple_match_ip (src m) s \<or> runFw s d c rs = Decision FinalAllow"
        by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)
  
      { fix s a
        have "\<not> simple_match_ip (dst m) d \<Longrightarrow>
         runFw s d c (SimpleRule m a # rs) = Decision FinalAllow \<longleftrightarrow> runFw s d c rs = Decision FinalAllow"
        apply(cases a)
         by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)+
       } note not_simple_match_ip=this
  
      from Cons.prems r have simple_match_ip_Drop: "\<And>s. simple_match_ip (dst m) d \<Longrightarrow>
         runFw s d c (SimpleRule m simple_action.Drop # rs) = Decision FinalAllow \<longleftrightarrow> \<not> simple_match_ip (src m) s \<and> runFw s d c rs = Decision FinalAllow"
        by(simp add: simple_conn_matches_def runFw_def simple_matches.simps)
  
      show ?case
        proof(cases a)
        case Accept with r Cons show ?thesis
         apply(simp, intro conjI impI)
          apply(simp add: simple_match_ip_Accept wordinterval_to_set_ipv4_cidr_tuple_to_interval_simple_match_ip_set)
          apply blast
         apply(simp add: not_simple_match_ip; fail)
         done
        next
        case Drop with r Cons show ?thesis
          apply(simp,intro conjI impI)
           apply(simp add: simple_match_ip_Drop matching_srcs_pull_out_accu wordinterval_to_set_ipv4_cidr_tuple_to_interval_simple_match_ip_set)
           apply blast
          apply(simp add: not_simple_match_ip; fail)
         done
        qed
    qed
  
  
  
  (*TODO: if we can get wordinterval_element to log runtime (this should be possible! maybe we want to
    use a type from the Collections to store wordintervals), then this should really improve the runtime!
    We mostly check for wordinterval_element after preprocessing. If they are ordered, a divide-and-conquer search is in log*)
  definition groupWIs3_default_policy :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list list" where
    "groupWIs3_default_policy c rs =  (let P = getParts rs in
                         (let W = map getOneIp P in 
                         (let filterW = (filter (\<lambda>r. simple_conn_matches (match_sel r) c) rs) in
                           (let f = (\<lambda>wi. let mtch_dsts = (matching_dsts (getOneIp wi) filterW Empty_WordInterval);
                                              mtch_srcs = (matching_srcs (getOneIp wi) filterW Empty_WordInterval) in 
                                          (map (\<lambda>d. wordinterval_element d mtch_dsts) W,
                                           map (\<lambda>s. wordinterval_element s mtch_srcs) W)) in
                        map (map fst) (groupF snd (map (\<lambda>x. (x, f x)) P))))))"
  
  
  lemma groupWIs3_default_policy_groupWIs2: assumes "has_default_policy rs" shows "groupWIs2 c rs = groupWIs3_default_policy c rs"
  proof -
    { fix filterW s d
      from matching_dsts[where c=c] have "filterW = filter (\<lambda>r. simple_conn_matches (match_sel r) c) rs \<Longrightarrow>
           wordinterval_element d (matching_dsts s filterW Empty_WordInterval) \<longleftrightarrow> runFw s d c filterW = Decision FinalAllow"
      by(simp)
    } note matching_dsts_filterW=this[simplified]
  
    { fix filterW s d
      from matching_srcs[where c=c] have "filterW = filter (\<lambda>r. simple_conn_matches (match_sel r) c) rs \<Longrightarrow>
            wordinterval_element s (matching_srcs d filterW Empty_WordInterval) \<longleftrightarrow> runFw s d c filterW = Decision FinalAllow"
      by simp
    } note matching_srcs_filterW=this[simplified]
  
    { fix W rs
      assume assms': "has_default_policy rs"
      have "groupF (\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c rs = Decision FinalAllow) (map getOneIp W),
                           map (\<lambda>s. runFw s (getOneIp wi) c rs = Decision FinalAllow) (map getOneIp W))) W =
             groupF (\<lambda>wi. (map (\<lambda>d. runFw (getOneIp wi) d c rs) (map getOneIp W),
                           map (\<lambda>s. runFw s (getOneIp wi) c rs) (map getOneIp W))) W"
      proof -
        { (*unused fresh generic variables. 'a is used for the tuple already*)
          fix f1::"'w \<Rightarrow> 'u \<Rightarrow> 'v" and f2::" 'w \<Rightarrow> 'u \<Rightarrow> 'x" and x and y and g1::"'w \<Rightarrow> 'u \<Rightarrow> 'y" and g2::"'w \<Rightarrow> 'u \<Rightarrow> 'z" and W::"'u list"
            assume 1: "\<forall>w \<in> set W. (f1 x) w = (f1 y) w \<longleftrightarrow> (f2 x) w =  (f2 y) w"
               and 2: "\<forall>w \<in> set W. (g1 x) w = (g1 y) w \<longleftrightarrow> (g2 x) w =  (g2 y) w"
               have "
                 ((map (f1 x) W, map (g1 x) W) = (map (f1 y) W, map (g1 y) W)) 
                 \<longleftrightarrow>
                 ((map (f2 x) W, map (g2 x) W) = (map (f2 y) W, map (g2 y) W))"
          proof -
            from 1 have p1: "(map (f1 x) W = map (f1 y) W \<longleftrightarrow> map (f2 x) W = map (f2 y) W)" by(induction W)(simp_all)
            from 2 have p2: "(map (g1 x) W = map (g1 y) W \<longleftrightarrow> map (g2 x) W = map (g2 y) W)" by(induction W)(simp_all)
            from p1 p2 show ?thesis by fast
          qed
        } note map_over_tuples_equal_helper=this
      
        show ?thesis
        apply(rule groupF_cong)
        apply(intro ballI)
        apply(rule map_over_tuples_equal_helper)
         using has_default_policy_runFw[OF assms'] by metis+
      qed
    } note has_default_policy_groupF=this[simplified]
  
    from assms show ?thesis
    apply(simp add: groupWIs3_default_policy_def groupWIs_code[symmetric])
    apply(subst groupF_tuple[symmetric])
    apply(simp add: Let_def)
    apply(simp add: matching_srcs_filterW matching_dsts_filterW)
    apply(subst has_default_policy_groupF)
     apply(simp add: has_default_policy_simple_conn_matches; fail)
    apply(simp add: groupWIs_def Let_def filter_conn_fw_lem)
    done
  qed
  
  
  definition groupWIs3 :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list list" where
    "groupWIs3 c rs = (if has_default_policy rs then groupWIs3_default_policy c rs else groupWIs2 c rs)"
  
  lemma groupWIs3: "groupWIs3 = groupWIs"
    by(simp add: fun_eq_iff groupWIs3_def groupWIs_code groupWIs3_default_policy_groupWIs2) 

(*end groupWIs3 optimization*)

(*construct partitions. main function!*)
definition build_ip_partition :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> 32 wordinterval list" where
  "build_ip_partition c rs = map (\<lambda>xs. wordinterval_compress (foldr wordinterval_union xs Empty_WordInterval)) (groupWIs3 c rs)"


theorem build_ip_partition_same_fw: "V \<in> set (build_ip_partition c rs) \<Longrightarrow>
                               \<forall>ip1 \<in> wordinterval_to_set V.
                               \<forall>ip2 \<in> wordinterval_to_set V.
                               same_fw_behaviour_one ip1 ip2 c rs"
  apply(simp add: build_ip_partition_def groupWIs3)
  using wordinterval_list_to_set_compressed groupParts_same_fw_wi2 by blast

theorem build_ip_partition_same_fw_min: "A \<in> set (build_ip_partition c rs) \<Longrightarrow> B \<in> set (build_ip_partition c rs) \<Longrightarrow> 
                                A \<noteq> B \<Longrightarrow>
                                \<forall>ip1 \<in> wordinterval_to_set A.
                                \<forall>ip2 \<in> wordinterval_to_set B.
                                \<not> same_fw_behaviour_one ip1 ip2 c rs"
  apply(simp add: build_ip_partition_def groupWIs3)
  using  groupWIs_same_fw_not2 wordinterval_list_to_set_compressed by blast

theorem build_ip_partition_complete: "(\<Union>x\<in>set (build_ip_partition c rs). wordinterval_to_set x) = (UNIV :: ipv4addr set)"
  proof -
  have "wordinterval_to_set (foldr wordinterval_union x Empty_WordInterval) = (\<Union>set (map wordinterval_to_set x))"
    for x::"32 wordinterval list"
    by(induction x) simp_all
  thus ?thesis
  apply(simp add: build_ip_partition_def groupWIs3 wordinterval_compress)
  using groupWIs_complete[simplified wordinterval_list_to_set_def] by simp
  qed



(*TODO: move or delete*)
lemma wordinterval_empty_wordinterval_compress: "wordinterval_empty (wordinterval_compress wi) \<longleftrightarrow> wordinterval_empty wi"
  by (simp add: wordinterval_compress) 


(*TODO: ugly proof, apply before proof-*)
lemma build_ip_partition_no_empty_elems: "wi \<in> set (build_ip_partition c rs) \<Longrightarrow> \<not> wordinterval_empty wi"
  proof(simp add: build_ip_partition_def groupWIs3)
    assume assm: "wi \<in> (\<lambda>xs. wordinterval_compress (foldr wordinterval_union xs Empty_WordInterval)) ` set (groupWIs c rs)"
    from assm obtain wi_orig where 1: "wi_orig \<in>  set (groupWIs c rs)" and
       2: "wi = wordinterval_compress (foldr wordinterval_union wi_orig Empty_WordInterval)" by blast
    from 1 groupWIs_not_empty_elem have i1: "wi_orig \<noteq> []" by simp
    from 1 groupWIs_not_empty_elems have i2: "\<And>w. w \<in> set wi_orig \<Longrightarrow> \<not> wordinterval_empty w" by simp
    from i1 i2 have "wordinterval_to_set (foldr wordinterval_union wi_orig Empty_WordInterval) \<noteq> {}"
      by(induction wi_orig) simp_all
    with 2 show "wordinterval_to_set wi \<noteq> {}" by(simp add: wordinterval_compress)
  qed


lemma build_ip_partition_disjoint: 
      "V1 \<in> set (build_ip_partition c rs) \<Longrightarrow> V2 \<in> set (build_ip_partition c rs) \<Longrightarrow>
       V1 \<noteq> V2 \<Longrightarrow>
        wordinterval_to_set V1 \<inter> wordinterval_to_set V2 = {}"
  by (meson build_ip_partition_same_fw_min int_not_emptyD same_fw_behaviour_one_equi(1))


lemma map_wordinterval_to_set_distinct:
  assumes distinct: "distinct xs"
  and disjoint: "(\<forall>x1 \<in> set xs. \<forall>x2 \<in> set xs. x1 \<noteq> x2 \<longrightarrow> wordinterval_to_set x1 \<inter> wordinterval_to_set x2 = {})" 
  and notempty: "\<forall>x \<in> set xs. \<not> wordinterval_empty x"
  shows "distinct (map wordinterval_to_set xs)"
  proof -
    (*have "\<not> wordinterval_empty x1 \<Longrightarrow> 
        wordinterval_to_set x1 \<inter> wordinterval_to_set x2 = {} \<Longrightarrow> x1 \<noteq> x2" for x1::"('b::len) wordinterval" and x2
      by fastforce *)
    have "\<not> wordinterval_empty x1 \<Longrightarrow> 
        wordinterval_to_set x1 \<inter> wordinterval_to_set x2 = {} \<Longrightarrow> 
        wordinterval_to_set x1 \<noteq> wordinterval_to_set x2" for x1::"('b::len) wordinterval" and x2
      by auto
    with disjoint notempty have "(\<forall>x1 \<in> set xs. \<forall>x2 \<in> set xs. x1 \<noteq> x2 \<longrightarrow> wordinterval_to_set x1 \<noteq> wordinterval_to_set x2)"
      by force
    with distinct show "distinct (map wordinterval_to_set xs)"
    proof(induction xs)
    case Cons thus ?case by simp fast
    qed(simp)
  qed

lemma map_getOneIp_distinct: assumes
  distinct: "distinct xs"
  and disjoint: "(\<forall>x1 \<in> set xs. \<forall>x2 \<in> set xs. x1 \<noteq> x2 \<longrightarrow> wordinterval_to_set x1 \<inter> wordinterval_to_set x2 = {})" 
  and notempty: "\<forall>x \<in> set xs. \<not> wordinterval_empty x"
  shows "distinct (map getOneIp xs)"
  proof -
    have "\<not> wordinterval_empty x \<Longrightarrow> \<not> wordinterval_empty xa \<Longrightarrow> 
          wordinterval_to_set x \<inter> wordinterval_to_set xa = {} \<Longrightarrow> getOneIp x \<noteq> getOneIp xa"
     for x xa::"'b::len wordinterval"
     by(fastforce dest: getOneIp_elem)
    with disjoint notempty have "(\<forall>x1 \<in> set xs. \<forall>x2 \<in> set xs. x1 \<noteq> x2 \<longrightarrow> getOneIp x1 \<noteq> getOneIp x2)"
      by metis
    with distinct show ?thesis
    proof(induction xs)
    case Cons thus ?case by simp fast
    qed(simp)
  qed


lemma build_ip_partition_disjoint_list_helper: 
  "(wordinterval_to_set \<circ> (\<lambda>xs. wordinterval_compress (foldr wordinterval_union xs Empty_WordInterval))) ws
       = \<Union> set (map wordinterval_to_set ws)"
  proof(induction ws)
  qed(simp_all add: wordinterval_compress)

(*TODO: delete or move into the lemmas where it is needed*)
lemma build_ip_partition_distinct_hlp: "map wordinterval_to_set (build_ip_partition c rs) =
                 map (%x. \<Union> set (map wordinterval_to_set x)) (groupWIs c rs)"
  unfolding build_ip_partition_def groupWIs3
  using build_ip_partition_disjoint_list_helper by auto

lemma build_ip_partition_distinct_hlp'':
      "\<Union> (set (map (%x. \<Union> set (map wordinterval_to_set x)) (groupF f xs))) =
       \<Union> set (map wordinterval_to_set xs)"
  by(induction f xs rule: groupF.induct) (auto)

lemma build_ip_partition_distinct_hlp': "\<forall>x \<in> set xs. \<not> wordinterval_empty x \<Longrightarrow>
       disjoint_list (map wordinterval_to_set xs) \<Longrightarrow>
       distinct (map (\<lambda>x. \<Union>set (map wordinterval_to_set x)) (groupF f xs))"
  proof(induction f xs rule: groupF.induct)
  case 1 thus ?case by simp
  next
  case (2 f x xs) thus ?case
    unfolding disjoint_list_def
    apply(clarsimp, safe)
     apply(subgoal_tac "\<not> wordinterval_to_set x \<union> (\<Union>x\<in>{xa \<in> set xs. f x = f xa}. wordinterval_to_set x) \<subseteq> \<Union> (set (map (%x. \<Union> set (map wordinterval_to_set x)) (groupF f [y\<leftarrow>xs . f x \<noteq> f y])))")
      apply(auto)[1]
     apply(subgoal_tac "\<not> wordinterval_to_set x \<subseteq> \<Union> (set (map (%x. \<Union> set (map wordinterval_to_set x)) (groupF f [y\<leftarrow>xs . f x \<noteq> f y])))")
      apply(blast)
     apply(subst build_ip_partition_distinct_hlp'')
     apply(subgoal_tac "\<not> (wordinterval_to_set x) \<subseteq> \<Union>(wordinterval_to_set ` set xs)")
      apply(auto)[1]
     apply(subgoal_tac "(wordinterval_to_set x) \<inter> \<Union>(wordinterval_to_set ` set xs) = {}")
      apply(fast)
     unfolding disjoint_def apply(auto)[1]
    apply(subgoal_tac "distinct (map wordinterval_to_set [y\<leftarrow>xs . f x \<noteq> f y])")
     apply(subgoal_tac "disjoint (wordinterval_to_set ` {xa \<in> set xs. f x \<noteq> f xa})")
      apply(blast)
     apply(simp add: disjoint_def; fail)
    using distinct_map_filter by metis
  qed




lemma disjoint_list_partitioningIps: 
  "{} \<notin> set (map wordinterval_to_set ts) \<Longrightarrow> disjoint_list (map wordinterval_to_set ts) \<Longrightarrow> 
   (wordinterval_list_to_set ss) \<subseteq> (wordinterval_list_to_set ts) \<Longrightarrow>
   disjoint_list (map wordinterval_to_set (partitioningIps ss ts))"
by (simp add: partitioning1_disjoint_list partitioningIps_equi wordinterval_list_to_set_def)

lemma getParts_disjoint_list: "disjoint_list (map wordinterval_to_set (getParts rs))"
  apply(subst getParts_def)
  apply(rule disjoint_list_partitioningIps)
    apply(simp_all add: wordinterval_list_to_set_def disjoint_list_def disjoint_def)
  done

lemma build_ip_partition_distinct: "distinct (map wordinterval_to_set (build_ip_partition c rs))"
  unfolding build_ip_partition_distinct_hlp groupWIs_def Let_def
  apply(rule build_ip_partition_distinct_hlp')
   using getParts_disjoint_list getParts_nonempty_elems by auto

lemma build_ip_partition_distinct': "distinct (build_ip_partition c rs)"
  using build_ip_partition_distinct distinct_mapI by blast




definition all_pairs :: "'a list \<Rightarrow> ('a \<times> 'a) list" where
  "all_pairs xs \<equiv> concat (map (\<lambda>x. map (\<lambda>y. (x,y)) xs) xs)"

lemma all_pairs: "\<forall> (x,y) \<in> (set xs \<times> set xs). (x,y) \<in> set (all_pairs xs)"
  by(auto simp add: all_pairs_def)
lemma all_pairs_set: "set (all_pairs xs) = set xs \<times> set xs"
  by (metis Product_Type.product_def all_pairs_def product_code) 

definition simple_firewall_without_interfaces :: "simple_rule list \<Rightarrow> bool" where
  "simple_firewall_without_interfaces rs \<equiv> \<forall>m \<in> match_sel ` set rs. iiface m = ifaceAny \<and> oiface m = ifaceAny"

lemma[code_unfold]: "simple_firewall_without_interfaces rs \<equiv>
  \<forall>m \<in> set rs. iiface (match_sel m) = ifaceAny \<and> oiface (match_sel m) = ifaceAny"
  by(simp add: simple_firewall_without_interfaces_def)

(*construct an ip partition and print it in some usable format
  returns:
  (vertices, edges) where
  vertices = (name, list of ip addresses this vertex corresponds to)
  and edges = (name \<times> name) list
*)
(*TODO: can we use collect srcs or collect dsts here too?*)
text{*Only defined for @{const simple_firewall_without_interfaces}*}
(*TODO: delete, use definition below!*)
definition access_matrix_pretty
  :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> (string \<times> string) list \<times> (string \<times> string) list" 
  where
  "access_matrix_pretty c rs \<equiv>
    if \<not> simple_firewall_without_interfaces rs then undefined else
    (let W = build_ip_partition c rs;
         R = map getOneIp W;
         U = all_pairs R
     in
     ((''Nodes'','':'') # zip (map ipv4addr_toString R) (map ipv4addr_wordinterval_toString W), 
      (''Vertices'','':'') # map (\<lambda>(x,y). (ipv4addr_toString x, ipv4addr_toString y)) (filter (\<lambda>(a,b). runFw a b c rs = Decision FinalAllow) U)))"


(*TODO: simple_firewall_without_interfaces check here?*)
definition access_matrix 
  :: "parts_connection \<Rightarrow> simple_rule list \<Rightarrow> (ipv4addr \<times> 32 wordinterval) list \<times> (ipv4addr \<times> ipv4addr) list" 
  where
  "access_matrix c rs \<equiv>
    (let W = build_ip_partition c rs;
         R = map getOneIp W
     in
     (zip R W, [(s, d)\<leftarrow>all_pairs R. runFw s d c rs = Decision FinalAllow]))"

lemma access_matrix_nodes_defined:
      "(V,E) = access_matrix c rs \<Longrightarrow> (s, d) \<in> set E \<Longrightarrow> s \<in> dom (map_of V)" and
      "(V,E) = access_matrix c rs \<Longrightarrow> (s, d) \<in> set E \<Longrightarrow> d \<in> dom (map_of V)"
  by(auto simp add: access_matrix_def Let_def all_pairs_def)

text{*For all the entries @{term E} of the matrix, the access is allowed*}
lemma "(V,E) = access_matrix c rs \<Longrightarrow> (s, d) \<in> set E \<Longrightarrow> runFw s d c rs = Decision FinalAllow"
  by(auto simp add: access_matrix_def Let_def)
text{*However, the entries are only a representation of a whole set of IP addresses. 
      For all IP addresses which the entries represent, the access must be allowed.*}


(*TODO: move to generic library*)
lemma map_of_zip_map: "map_of (zip (map f rs) rs) k = Some v \<Longrightarrow> k = f v"
  apply(induction rs)
   apply(simp)
  apply(simp split: split_if_asm)
  done
lemma access_matrix_sound: assumes matrix: "(V,E) = access_matrix c rs" and
              repr: "(s_repr, d_repr) \<in> set E" and
              s_range: "(map_of V) s_repr = Some s_range" and s: "s \<in> wordinterval_to_set s_range" and
              d_range: "(map_of V) d_repr = Some d_range" and d: "d \<in> wordinterval_to_set d_range"
      shows "runFw s d c rs = Decision FinalAllow"
  proof -
    let ?part="(build_ip_partition c rs)"
    have V: "V = (zip (map getOneIp ?part) ?part)"
      using matrix by(simp add: access_matrix_def Let_def)
    (*have "E = [(s, d)\<leftarrow>all_pairs (map getOneIp ?part). runFw s d c rs = Decision FinalAllow]"
      using matrix by(simp add: access_matrix_def Let_def)
    with repr have "(s_repr, d_repr) \<in> set (all_pairs (map getOneIp ?part))" by simp
    hence "s_repr \<in> set (map getOneIp ?part)" and
          "d_repr \<in> set (map getOneIp ?part)"
      by(simp add: all_pairs_set)+*)
    (*from s_range have "(s_repr, s_range) \<in> set V" by (simp add: map_of_SomeD)*)

    from matrix repr have repr_Allow: "runFw s_repr d_repr c rs = Decision FinalAllow"
      by(auto simp add: access_matrix_def Let_def)

    have s_range_in_part: "s_range \<in> set ?part" using V in_set_zip2 s_range by (fastforce dest: map_of_SomeD)
    with build_ip_partition_no_empty_elems have "\<not> wordinterval_empty s_range" by simp

    have d_range_in_part: "d_range \<in> set ?part" using V in_set_zip2 d_range by (fastforce dest: map_of_SomeD)
    with build_ip_partition_no_empty_elems have "\<not> wordinterval_empty d_range" by simp

    from map_of_zip_map V s_range have "s_repr = getOneIp s_range" by fast
    with \<open>\<not> wordinterval_empty s_range\<close> getOneIp_elem wordinterval_element_set_eq 
    have "s_repr \<in> wordinterval_to_set s_range" by blast 

    from map_of_zip_map V d_range have "d_repr = getOneIp d_range" by fast
    with \<open>\<not> wordinterval_empty d_range\<close> getOneIp_elem wordinterval_element_set_eq 
    have "d_repr \<in> wordinterval_to_set d_range" by blast 

    from s_range_in_part have s_range_in_part': "s_range \<in> set (build_ip_partition c rs)" by simp
    from d_range_in_part have d_range_in_part': "d_range \<in> set (build_ip_partition c rs)" by simp

    from build_ip_partition_same_fw[OF s_range_in_part', unfolded same_fw_behaviour_one_def] s `s_repr \<in> wordinterval_to_set s_range` have 
      "\<forall>d. runFw s_repr d c rs = runFw s d c rs" by blast
    with repr_Allow have 1: "runFw s d_repr c rs = Decision FinalAllow" by simp

    from build_ip_partition_same_fw[OF d_range_in_part', unfolded same_fw_behaviour_one_def] d `d_repr \<in> wordinterval_to_set d_range` have 
      "\<forall>s. runFw s d_repr c rs = runFw s d c rs" by blast
    with 1 have 2: "runFw s d c rs = Decision FinalAllow" by simp
    thus ?thesis .
qed




(*TODO: access_matrix_complete*)

corollary build_ip_partition_obtain: 
  fixes s::ipv4addr obtains V where "V \<in> set (build_ip_partition c rs)" and "s \<in> wordinterval_to_set V"
  using build_ip_partition_complete 
  by fast


lemma distinct_map_getOneIp_obtain: "v \<in> set xs \<Longrightarrow> distinct (map getOneIp xs) \<Longrightarrow> 
  \<exists>s_repr. map_of (zip (map getOneIp xs) xs) s_repr = Some v"
  proof(induction xs)
  case Nil thus ?case by simp
  next
  case (Cons x xs)
    consider "v = x" | "v \<in> set xs" using Cons.prems(1) by fastforce
    thus ?case
    proof(cases)
    case 1 thus ?thesis by simp blast
    next
    case 2 with Cons.IH Cons.prems(2) obtain s_repr where
      s_repr: "map_of (zip (map getOneIp xs) xs) s_repr = Some v" by force
      show ?thesis
      proof(cases "s_repr \<noteq> getOneIp x")
        case True with Cons.prems s_repr show ?thesis by(rule_tac x=s_repr in exI, simp)
        next
        case False with Cons.prems s_repr show ?thesis by(fastforce elim: in_set_zipE)
      qed
    qed
  qed
  

lemma distinct_map_getOneIp_build_ip_partition_obtain:
    "v \<in> set (build_ip_partition c rs) \<Longrightarrow>
       \<exists>s_repr. map_of (zip (map getOneIp (build_ip_partition c rs)) (build_ip_partition c rs)) s_repr = Some v"
  apply(erule distinct_map_getOneIp_obtain)
  apply(rule map_getOneIp_distinct)
    subgoal using build_ip_partition_distinct' by(simp)
   subgoal using build_ip_partition_disjoint build_ip_partition_distinct' by(simp)
  subgoal using build_ip_partition_no_empty_elems[simplified] by simp
  done


lemma access_matrix_complete: assumes matrix: "(V,E) = access_matrix c rs" and
              allow: "runFw s d c rs = Decision FinalAllow"
      shows "\<exists>s_repr d_repr s_range d_range. (s_repr, d_repr) \<in> set E \<and>
              (map_of V) s_repr = Some s_range \<and> s \<in> wordinterval_to_set s_range \<and>
              (map_of V) d_repr = Some d_range \<and> d \<in> wordinterval_to_set d_range"
  proof -
    let ?part="(build_ip_partition c rs)"
    have V: "V = zip (map getOneIp ?part) ?part"
      using matrix by(simp add: access_matrix_def Let_def)
    have E: "E = [(s, d)\<leftarrow>all_pairs (map getOneIp ?part). runFw s d c rs = Decision FinalAllow]"
      using matrix by(simp add: access_matrix_def Let_def)

    from build_ip_partition_obtain obtain s_range where
      "s_range \<in> set ?part" and "s \<in> wordinterval_to_set s_range" by blast
    from this distinct_map_getOneIp_build_ip_partition_obtain V obtain s_repr where
      ex_s1: "(map_of V) s_repr = Some s_range" and ex_s2: "s \<in> wordinterval_to_set s_range"
      by blast


    from build_ip_partition_obtain obtain d_range where
      "d_range \<in> set ?part" and "d \<in> wordinterval_to_set d_range" by blast
    from this distinct_map_getOneIp_build_ip_partition_obtain V obtain d_repr where
      ex_d1: "(map_of V) d_repr = Some d_range" and ex_d2: "d \<in> wordinterval_to_set d_range"
      by blast

    have 1: "s_repr \<in> getOneIp ` set (build_ip_partition c rs)"
      using V \<open>map_of V s_repr = Some s_range\<close> in_set_zip1 map_of_SomeD by fastforce
    have 2: "d_repr \<in> getOneIp ` set (build_ip_partition c rs)"
      using V \<open>map_of V d_repr = Some d_range\<close> in_set_zip1 map_of_SomeD by fastforce

    have "runFw s_repr d_repr c rs = Decision FinalAllow"
    proof -
      have f1: "(\<forall>w wa p ss. \<not> same_fw_behaviour_one w wa (p::parts_connection) ss \<or>
              (\<forall>wb wc. runFw w wb p ss = runFw wa wb p ss \<and> runFw wc w p ss = runFw wc wa p ss)) \<and>
              (\<forall>w wa p ss. (\<exists>wb wc. runFw w wb (p::parts_connection) ss \<noteq> runFw wa wb p ss \<or> runFw wc w p ss \<noteq> runFw wc wa p ss) \<or>
              same_fw_behaviour_one w wa p ss)"
        using same_fw_behaviour_one_def by blast
      from \<open>s_range \<in> set (build_ip_partition c rs)\<close>  have f2: "same_fw_behaviour_one s s_repr c rs"
        by (metis (no_types) IPPartitioning.map_of_zip_map V build_ip_partition_no_empty_elems
            build_ip_partition_same_fw ex_s1 ex_s2 getOneIp_elem wordinterval_element_set_eq)
      from \<open>d_range \<in> set (build_ip_partition c rs)\<close> have "same_fw_behaviour_one d_repr d c rs"
        by (metis (no_types) IPPartitioning.map_of_zip_map V build_ip_partition_no_empty_elems
            build_ip_partition_same_fw ex_d1 ex_d2 getOneIp_elem wordinterval_element_set_eq)
      with f1 f2 show ?thesis
        using allow by presburger
    qed
      
    hence ex1: "(s_repr, d_repr) \<in> set E" by(simp add: E all_pairs_set 1 2)
    
    thus ?thesis using ex1 ex_s1 ex_s2 ex_d1 ex_d2 by blast 
qed


theorem access_matrix: assumes matrix: "(V,E) = access_matrix c rs"
      shows "(\<exists>s_repr d_repr s_range d_range. (s_repr, d_repr) \<in> set E \<and>
              (map_of V) s_repr = Some s_range \<and> s \<in> wordinterval_to_set s_range \<and>
              (map_of V) d_repr = Some d_range \<and> d \<in> wordinterval_to_set d_range)
             \<longleftrightarrow>
             runFw s d c rs = Decision FinalAllow"
using matrix access_matrix_sound access_matrix_complete by blast


definition parts_connection_ssh where "parts_connection_ssh = \<lparr>pc_iiface=''1'', pc_oiface=''1'', pc_proto=TCP,
                               pc_sport=10000, pc_dport=22, pc_tag_ctstate=CT_New\<rparr>"

definition parts_connection_http where "parts_connection_http = \<lparr>pc_iiface=''1'', pc_oiface=''1'', pc_proto=TCP,
                               pc_sport=10000, pc_dport=80, pc_tag_ctstate=CT_New\<rparr>"




value[code] "partitioningIps [WordInterval (0::ipv4addr) 0] [WordInterval 0 2, WordInterval 0 2]"






end                            
