From Coq Require Import
     Program
     List
     Logic.FunctionalExtensionality
     Logic.IndefiniteDescription
     micromega.Lia
     Init.Specif
     Fin.

From RelationAlgebra Require Import
     monoid
     kat
     kat_tac
     prop
     rel
     srel
     comparisons
     rewriting
     normalisation.

From Equations Require Import Equations.

From ITree Require Import
     Sum.

From CTree Require Import
     CTree
	   Eq
 	   Interp.Interp.

Import ListNotations.
Import CTreeNotations.

Variant choiceI_boundF {E R} b (choiceI_bound : ctree E R -> Prop) :
  ctree' E R -> Prop :=
  | bound_Ret r : choiceI_boundF b choiceI_bound (RetF r)
  | bound_Vis {X} (e : E X) k : (forall x, choiceI_bound (k x)) ->
                                choiceI_boundF b choiceI_bound (VisF e k)
  | bound_choiceF {n} k : (forall i, choiceI_bound (k i)) ->
                          choiceI_boundF b choiceI_bound (ChoiceF true n k)
  | bound_choiceI {n} k : (forall i, choiceI_bound (k i)) ->
                          (n <= b)%nat ->
                          choiceI_boundF b choiceI_bound (ChoiceF false n k)
.
#[global] Hint Constructors choiceI_boundF: core.

Definition choiceI_bound_ {E R} b choiceI_bound : ctree E R -> Prop :=
  fun t => choiceI_boundF b choiceI_bound (observe t).

Obligation Tactic := idtac.
Program Definition fchoiceI_bound {E R} (b : nat) : mon (ctree E R -> Prop) :=
  {| body := choiceI_bound_ b |}.
Next Obligation.
  intros E R b ?? INC t H. inversion H; unfold choiceI_bound_ in *.
  - rewrite <- H1 in *. constructor.
  - rewrite <- H0 in *. constructor. intros. apply INC; auto.
  - rewrite <- H0 in *. constructor. intros. apply INC; auto.
  - rewrite <- H0 in *. constructor; auto. intros. apply INC; auto.
Qed.

Definition choiceI_bound {E R} b := (gfp (@fchoiceI_bound E R b)).
#[global] Hint Unfold choiceI_bound: core.

#[global] Instance equ_choiceI_bound {E R} :
  Proper (eq ==> equ eq ==> impl) (@choiceI_bound E R).
Proof.
  unfold Proper, respectful, impl. intros ? b ?. subst. revert b.
  red. intros. revert x y H H0. coinduction r CIH. intros x y Hequ H.
  step in Hequ. step in H. cbn.
  red in H |- *. inversion Hequ; auto. 2: destruct b0.
  - rewrite <- H1 in H. inversion H. subst. apply inj_pair2 in H4, H5. subst.
    constructor. intros. eapply CIH. apply REL. apply H3.
  - rewrite <- H1 in H. inversion H. subst. apply inj_pair2 in H4. subst.
    constructor. intros. eapply CIH. apply REL. apply H3.
  - rewrite <- H1 in H. inversion H. subst. apply inj_pair2 in H3. subst.
    constructor; auto. intros. eapply CIH. apply REL. apply H4.
Qed.

#[global] Instance equ_choiceI_bound' {E R} :
  Proper (eq ==> equ eq ==> flip impl) (@choiceI_bound E R).
Proof.
  unfold Proper, respectful, flip, impl. intros ? b ?. subst. revert b.
  red. intros. revert x y H H0. coinduction r CIH. intros x y Hequ H.
  step in Hequ. step in H. cbn.
  red in H |- *. inversion Hequ; auto. 2: destruct b0.
  - rewrite <- H2 in H. inversion H. subst. apply inj_pair2 in H4, H5. subst.
    constructor. intros. eapply CIH. apply REL. apply H3.
  - rewrite <- H2 in H. inversion H. subst. apply inj_pair2 in H4. subst.
    constructor. intros. eapply CIH. apply REL. apply H3.
  - rewrite <- H2 in H. inversion H. subst. apply inj_pair2 in H3. subst.
    constructor; auto. intros. eapply CIH. apply REL. apply H4.
Qed.

Lemma choiceI_step {E R} n k x :
  choiceI_bound 1 (ChoiceI n k : ctree E R) ->
  n = 1%nat /\ choiceI_bound 1 (k x).
Proof.
  intros Hbound.
  step in Hbound.
  inversion Hbound.
  destruct n.
  - inversion x.
  - split. lia.
    apply inj_pair2 in H0. subst. apply H1.
Qed.

Lemma trans_choiceI_bound E R (t t' : ctree E R) :
  choiceI_bound 1 t ->
  trans tau t t' ->
  choiceI_bound 1 t'.
Proof.
  intros Hbound Htrans. revert Hbound.
  unfold trans in *.
  cbn in *. red in Htrans. dependent induction Htrans; intros.
  - eapply IHHtrans; auto.
    assert (t ≅ ChoiceI n k). { rewrite ctree_eta. rewrite <- x. reflexivity. }
    rewrite H in Hbound. step in Hbound. inversion Hbound.
    apply inj_pair2 in H1. subst. apply H2.
  - assert (t' ≅ k x0).
    { rewrite ctree_eta. rewrite <- x. rewrite H. rewrite <- ctree_eta. reflexivity. }
    assert (t ≅ ChoiceV n k).
    { rewrite ctree_eta. rewrite <- x1. reflexivity. }
    rewrite H1 in Hbound. rewrite H0. step in Hbound. inversion Hbound.
    apply inj_pair2 in H4. subst. apply H3.
Qed.

Lemma visible_choiceI_bound E R n (t t' : ctree E R) :
  choiceI_bound n t ->
  visible t t' ->
  choiceI_bound n t'.
Proof.
  intros Hbound Hvisible. revert n Hbound.
  cbn in *. red in Hvisible. dependent induction Hvisible; intros.
  - eapply IHHvisible; auto.
    assert (t ≅ ChoiceI n k). { rewrite ctree_eta. rewrite <- x. reflexivity. }
    rewrite H in Hbound.
    step in Hbound. inversion Hbound. apply inj_pair2 in H1. subst. auto.
  - assert (t ≅ ChoiceV n k1). { rewrite ctree_eta. rewrite <- x1. reflexivity. }
    assert (t' ≅ ChoiceV n k2). { rewrite ctree_eta. rewrite <- x. reflexivity. }
    rewrite H0 in Hbound. rewrite H1. clear H0 H1 x x1.
    step in Hbound. inversion Hbound. apply inj_pair2 in H2. subst.
    (* TODO: fix step in the coinduction library to work on unary relations *)
    red. apply (proj2 (gfp_fp (fchoiceI_bound n0) (ChoiceV n k2))). cbn.
    constructor. intros. specialize (H1 i). fold (@choiceI_bound E R n0) in *.
    rewrite H in H1. auto.
  - assert (t ≅ Vis e k1). { rewrite ctree_eta. rewrite <- x0. reflexivity. }
    assert (t' ≅ Vis e k2). { rewrite ctree_eta. rewrite <- x. reflexivity. }
    rewrite H0 in Hbound. rewrite H1. clear H0 H1 x x0.
    step in Hbound. inversion Hbound. apply inj_pair2 in H2, H3. subst.
    red. apply (proj2 (gfp_fp (fchoiceI_bound n) (Vis e k2))). cbn.
    constructor. intros. specialize (H1 x). fold (@choiceI_bound E R n) in *.
    rewrite H in H1. auto.
  - assert (t ≅ Ret r). { rewrite ctree_eta. rewrite <- x0. reflexivity. }
    assert (t' ≅ Ret r). { rewrite ctree_eta. rewrite <- x. reflexivity. }
    rewrite H in Hbound. rewrite H0. auto.
Qed.

Variant yieldE S : Type -> Type :=
| Yield : S -> yieldE S S.

Variant spawnE : Type -> Type :=
| Spawn : spawnE bool.

Section parallel.
  Context {config : Type}.

  Definition parE c := yieldE c +' spawnE.

  Definition thread := Monads.stateT config
                                     (ctree (parE config))
                                     unit.

  Definition completed := Monads.stateT config (ctree void1) unit.

  Definition vec n := fin n -> thread.

  Definition vec_relation {n : nat} (P : rel _ _) (v1 v2 : vec n) : Prop :=
    forall i c, P (v1 i c) (v2 i c).

  Instance vec_relation_symmetric n (P : rel _ _) `{@Symmetric _ P} :
    Symmetric (@vec_relation n P).
  Proof. repeat intro. auto. Qed.

  Definition remove_front_vec {n : nat} (v : vec (S n)) : vec n :=
    fun i => v (FS i).

  Lemma remove_front_vec_vec_relation n P (v1 v2 : vec (S n)) :
    vec_relation P v1 v2 ->
    vec_relation P (remove_front_vec v1) (remove_front_vec v2).
  Proof.
    repeat intro. apply H.
  Qed.

  Equations remove_vec {n : nat} (v : vec (S n)) (i : fin (S n)) : vec n :=
    remove_vec v F1     i'      := remove_front_vec v i';
    remove_vec v (FS i) F1      := v F1;
    remove_vec v (FS i) (FS i') := remove_vec (remove_front_vec v) i i'.
  Transparent remove_vec.

  Lemma remove_vec_vec_relation n P (v1 v2 : vec (S n)) i :
    vec_relation P v1 v2 ->
    vec_relation P (remove_vec v1 i) (remove_vec v2 i).
  Proof.
    intros.
    depind i; [apply remove_front_vec_vec_relation; auto |].
    repeat intro. destruct i0; cbn; auto.
    apply IHi; auto.
    repeat intro. apply remove_front_vec_vec_relation; auto.
  Qed.

  Definition remove_vec_helper n n' (v : vec n) (i : fin n) (H : n = S n')
    : vec n'.
    subst. apply remove_vec; eauto.
  Defined.

  Definition replace_vec {n : nat} (v : vec n) (i : fin n) (t : thread) : vec n :=
    fun i' => if Fin.eqb i i' then t else v i'.

  Lemma remove_front_vec_replace_vec n (v : vec (S n)) i t :
    remove_front_vec (replace_vec v (Fin.FS i) t) =
      replace_vec (remove_front_vec v) i t.
  Proof. reflexivity. Qed.

  Lemma remove_vec_replace_vec_eq {n} (v : vec (S n)) i t :
    remove_vec v i = remove_vec (replace_vec v i t) i.
  Proof.
    dependent induction i.
    - unfold remove_vec. unfold remove_front_vec. cbn. reflexivity.
    - unfold remove_vec. cbn. apply functional_extensionality. intros.
      dependent destruction x; auto.
      erewrite IHi; eauto.
  Qed.

  Lemma remove_vec_helper_replace_vec_eq {n n'} (v : vec n) i t H :
    remove_vec_helper n n' v i H = remove_vec_helper n n' (replace_vec v i t) i H.
  Proof.
    subst. cbn. eapply remove_vec_replace_vec_eq.
  Qed.

  Lemma replace_vec_vec_relation n P (v1 v2 : vec n) i t1 t2 :
    vec_relation P v1 v2 ->
    (forall x, P (t1 x) (t2 x)) ->
    vec_relation P (replace_vec v1 i t1) (replace_vec v2 i t2).
  Proof.
    unfold replace_vec. repeat intro. destruct (Fin.eqb i i0); auto.
  Qed.

  Lemma replace_vec_twice n (v : vec n) i t1 t2 :
    replace_vec (replace_vec v i t1) i t2 = replace_vec v i t2.
  Proof.
    unfold replace_vec. apply functional_extensionality. intro.
    destruct (Fin.eqb i x) eqn:?; auto.
  Qed.

  Lemma replace_vec_eq n (v : vec n) i t :
    (replace_vec v i t) i = t.
  Proof.
    unfold replace_vec.
    assert (i = i) by reflexivity. apply Fin.eqb_eq in H. rewrite H.
    reflexivity.
  Qed.

  Lemma replace_vec_same n (v : vec n) i :
    replace_vec v i (v i) = v.
  Proof.
    unfold replace_vec. apply functional_extensionality. intro.
    destruct (Fin.eqb i x) eqn:?; auto.
    apply Fin.eqb_eq in Heqb. subst. auto.
  Qed.

  Equations cons_vec {n : nat} (t : thread) (v : vec n) : vec (S n) :=
    cons_vec t v F1      := t;
    cons_vec t v (FS i)  := v i.
  Transparent cons_vec.

  Lemma cons_vec_vec_relation n P (v1 v2 : vec n) t1 t2 :
    vec_relation P v1 v2 ->
    (forall x, P (t1 x) (t2 x)) ->
    vec_relation P (cons_vec t1 v1) (cons_vec t2 v2).
  Proof.
    unfold cons_vec. repeat intro. depind i; cbn; auto.
  Qed.


  (* Program Definition append_vec {n : nat} (v : vec n) (t : thread) : vec (S n) := *)
  (*   fun i => let i' := Fin.to_nat i in *)
  (*         match PeanoNat.Nat.eqb (`i') n with *)
  (*         | true => t *)
  (*         | false => v (@Fin.of_nat_lt (`i') _ _) *)
  (*         end. *)
  (* Next Obligation. *)
  (*   (* why is the space after ` necessary...... *) *)
  (*   assert ((` (Fin.to_nat i)) <> n). *)
  (*   { *)
  (*     pose proof (Bool.reflect_iff _ _ (PeanoNat.Nat.eqb_spec (` (Fin.to_nat i)) n)). *)
  (*     intro. rewrite H in H0. rewrite H0 in Heq_anonymous. inv Heq_anonymous. *)
  (*   } *)
  (*   pose proof (proj2_sig (Fin.to_nat i)). *)
  (*   simpl in H0. lia. *)
  (* Defined. *)

  (* Lemma append_vec_vec_relation n P (v1 v2 : vec n) t1 t2 : *)
  (*   vec_relation P v1 v2 -> *)
  (*   (forall x, P (t1 x) (t2 x)) -> *)
  (*   vec_relation P (append_vec v1 t1) (append_vec v2 t2). *)
  (* Proof. *)
  (*   unfold append_vec. repeat intro. *)
  (* Qed. *)

  (* Alternate definition: factoring out the yielding effect *)
  Equations schedule_match
             (schedule : forall (n : nat), vec n -> option (fin n) -> thread)
             (n : nat)
             (v: vec n)
    : option (fin n) -> thread :=
    (* If no thread is focused, and there are none left in the pool, we are done *)
    schedule_match schedule 0     v None     c    :=
      Ret (c,tt);

    (* If no thread is focused, but there are some left in the pool, we pick one *)
    schedule_match schedule (S n) v None     c    :=
      ChoiceV (S n) (fun i' => schedule (S n) v (Some i') c);

    (* If a thread is focused on, we analyze its head constructor *)
    schedule_match schedule (S n) v (Some i) c with observe (v i c) =>
      {
        (* If it's a [Ret], we simply remove it from the pool and focus *)
        schedule_match _ _ _ _ _ (RetF (c',_)) :=
          TauI (schedule n (remove_vec v i) None c');

        (* If it's a [Choice], we propagate the choice and update the thread *)
        schedule_match _ _ _ _ _ (ChoiceF b n' k) :=
          Choice b n' (fun i' => schedule (S n) (replace_vec v i (fun _ => k i')) (Some i) c);

        (* If it's a [Yield], we remove the focus *)
        schedule_match _ _ _ _ _ (VisF (inl1 (Yield _ s')) k) :=
          TauI (schedule (S n) (replace_vec v i k) None s');

        (* If it's a [Spawn], we extend the pool *)
        schedule_match _ _ _ _ _ (VisF (inr1 Spawn) k) :=
          TauV (schedule
                  (S (S n))
                  (cons_vec (fun _ => k true) (replace_vec v i (fun _ => k false)))
                  (* The [i] here means that we don't yield at a spawn *)
                  (Some (Fin.L_R 1 i)) (* view [i] as a [fin (n + 1)] *)
                  c)
      }.
  (* Transparent schedule_match. *)
  CoFixpoint schedule := schedule_match schedule.

  Lemma rewrite_schedule n v i c : schedule n v i c ≅ schedule_match schedule n v i c.
  Proof.
    step. eauto.
  Qed.

  #[global] Instance equ_schedule n :
    Proper ((vec_relation (equ eq)) ==> eq ==> pwr (equ eq)) (schedule n).
  Proof.
    intros x y H ? i ? c. subst. revert n x y i c H.
    coinduction r CIH. intros n v1 v2 i c Hv.
    do 2 rewrite rewrite_schedule.
    destruct i as [i |].
    2: { destruct n; auto. cbn. constructor. intros. apply CIH; auto. }
    destruct n as [| n]; auto.
    rewrite 2 schedule_match_equation_3.
    pose proof (Hv i c).
    step in H. cbn. inv H; eauto. 2: destruct e.
    - clear H1 H2. destruct y; cbn in *; auto.
      constructor. intros. apply CIH.
      apply remove_vec_vec_relation; auto.
    - clear H1 H2. destruct y. cbn.
      constructor. intros. eapply CIH.
      apply replace_vec_vec_relation; auto.
    - destruct s. constructor. intros. eapply CIH.
      apply cons_vec_vec_relation; auto.
      apply replace_vec_vec_relation; auto.
    - cbn. constructor. intros. apply CIH.
      apply replace_vec_vec_relation; auto.
  Qed.

  (** Helper lemmas for dealing with [schedule] *)

  Lemma ChoiceI_schedule_inv n1 k n2 (v : vec n2) i c :
    ChoiceI n1 k ≅ schedule n2 v (Some i) c ->
    (exists k', v i c ≅ ChoiceI n1 k' /\
             forall i', k i' ≅ schedule n2 (replace_vec v i (fun _ => k' i')) (Some i) c) \/
      (exists c' k', v i c ≅ Vis (inl1 (Yield config c')) k' /\
                  n1 = 1%nat /\
                  forall i', k i' ≅ schedule n2 (replace_vec v i k') None c') \/
      (exists c' n2' H1, v i c ≅ Ret (c', ()) /\
                      n1 = 1%nat /\
                      forall i', k i' ≅ schedule n2' (remove_vec_helper n2 n2' v i H1) None c').
  Proof.
    intros Hequ.
    rewrite rewrite_schedule in Hequ.
    destruct n2 as [| n2]; [inv i |].
    rewrite schedule_match_equation_3 in Hequ; cbn in Hequ.
    destruct (observe (v i c)) eqn:?; cbn in Hequ.
    - destruct r, u.
      right. right.
      step in Hequ. pose proof (equb_choice_invT _ _ Hequ) as [? _]. subst.
      pose proof (equb_choice_invE _ _ Hequ).
      eexists; exists n2, eq_refl.
      split; auto.
      step. rewrite Heqc0. reflexivity.
    - destruct e; [destruct y | destruct s]. 2: step in Hequ; inv Hequ.
      step in Hequ. pose proof (equb_choice_invT _ _ Hequ) as [? _]. subst.
      pose proof (equb_choice_invE _ _ Hequ).
      right. left.
      do 2 eexists. split; [| split]; auto.
      step. rewrite Heqc0. reflexivity.
    - destruct vis; [step in Hequ; inv Hequ |].
      pose proof (equ_choice_invT _ _ Hequ) as [? _]; subst.
      pose proof (equ_choice_invE _ _ Hequ).
      left.
      exists k0. split; auto.
      rewrite ctree_eta. rewrite Heqc0. reflexivity.
  Qed.

  (** Helper lemmas for when [schedule] transitions with a [val] *)
  Lemma trans_schedule_val_1 {X} n v i c (x : X) t :
    trans (val x) (schedule n v (Some i) c) t ->
    n = 1%nat.
  Proof.
    intro. unfold trans in *; cbn in H. red in H.
    remember (observe (schedule n v (Some i) c)).
    pose proof (ctree_eta (go (observe (schedule n v (Some i) c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val x).
    revert t v i c x Heql Heqc1 H0.
    induction H; intros t' v i c c' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule_inv in Hequ. destruct Hequ as [? | [? | ?]].
      + destruct H0 as (k' & Hvic & Hk).
        eapply IHtrans_; eauto.
        rewrite Hk. auto.
      + destruct H0 as (c'' & k' & Hvic & Hn & Hk). subst.
        rewrite Hk in H. rewrite rewrite_schedule in H.
        destruct n; [inv i | inv H].
      + destruct H0 as (c'' & n' & Hn2' & Hvic & Hn & Hk).
        (* assert (n2' = O). { clear Hk. inv Hn2'. reflexivity. } subst. *)
        rewrite Hk in H. rewrite rewrite_schedule in H.
        destruct n'; auto. inv H.
    - apply inj_pair2 in H1. subst.
      rewrite rewrite_schedule in Hequ.
      destruct n; [inv i |].
      rewrite schedule_match_equation_3 in Hequ; cbn in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct r, u; step in Hequ; inv Hequ.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  Lemma trans_schedule_thread_val {X} v i c (x : X) t :
    trans (val x) (schedule 1 v (Some i) c) t ->
    trans (val x) (v i c) CTree.stuckI.
  Proof.
    intro. unfold trans in *; cbn in H. red in H.
    remember (observe (schedule 1 v (Some i) c)).
    pose proof (ctree_eta (go (observe (schedule 1 v (Some i) c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val x).
    revert t v i c x Heql Heqc1 H0.
    induction H; intros t' v i c c' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ. cbn.
      apply ChoiceI_schedule_inv in Hequ. destruct Hequ as [? | [? | ?]].
      + destruct H0 as (k' & Hvic & Hk).
        setoid_rewrite Hk in IHtrans_.
        rewrite Hvic.
        econstructor.
        specialize (IHtrans_ _ (replace_vec v i (fun _ : config => k' x)) i c _ eq_refl eq_refl).
        rewrite replace_vec_eq in IHtrans_. apply IHtrans_. reflexivity.
      + destruct H0 as (c'' & k' & Hvic & Hn & Hk). subst.
        rewrite Hk in H. rewrite rewrite_schedule in H.
        inv H.
      + destruct H0 as (c'' & n2' & Hn2' & Hvic & Hn & Hk).
        assert (n2' = O). { clear Hk. inv Hn2'. reflexivity. } subst.
        rewrite Hk in H. rewrite rewrite_schedule in H.
        apply trans_ret_inv in H. destruct H. inv H0. apply inj_pair2 in H3. subst.
        rewrite Hvic. constructor.
    - apply inj_pair2 in H1. subst.
      rewrite rewrite_schedule in Hequ.
      rewrite schedule_match_equation_3 in Hequ; cbn in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct r, u. step in Hequ. inv Hequ.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  Lemma trans_thread_schedule_val_1 {X} v i c (x : X) t :
    trans (val x) (v i c) t ->
    trans (val x) (schedule 1 v (Some i) c) CTree.stuckI.
  Proof.
    intro. unfold trans in *; cbn in H. red in H.
    remember (observe (v i c)).
    pose proof (ctree_eta (go (observe (v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). cbn. remember (val x).
    revert t v i c x Heql Heqc1 H0.
    induction H; intros t' v i c x' Heql Heq Hequ; try inv Heql.
    - (* is there a better way to do this *)
      step in Hequ. inv Hequ. apply inj_pair2 in H3; subst.
      rewrite rewrite_schedule. rewrite schedule_match_equation_3. rewrite <- H4.
      econstructor. eapply IHtrans_; try reflexivity. rewrite REL.
      rewrite replace_vec_eq. reflexivity.
    - apply inj_pair2 in H1. subst.
      step in Hequ. inv Hequ.
      rewrite rewrite_schedule. rewrite schedule_match_equation_3. rewrite <- H.
      destruct y, u. econstructor; eauto.
      rewrite rewrite_schedule. constructor.
  Qed.

  (** [schedule] cannot transition with an [obs] *)
  Lemma trans_schedule_obs {X} n v o c (e : parE config X) (x : X) t :
    trans (obs e x) (schedule n v o c) t ->
    False.
  Proof.
    unfold trans; intro. destruct o as [i |].
    2: {
      rewrite rewrite_schedule in H.  destruct n; inv H.
    }
    cbn in H. red in H.
    remember (observe (schedule n v (Some i) c)).
    pose proof (ctree_eta (go (observe (schedule n v (Some i) c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (obs _ _).
    revert t n v i c e x Heql Heqc1 H0.
    induction H; intros t' n' v i c e' x' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule_inv in Hequ. destruct Hequ as [? | [? | ?]].
      + destruct H0 as (k' & Hvic & Hk).
        setoid_rewrite Hk in IHtrans_.
        eapply IHtrans_; eauto.
      + destruct H0 as (c' & k' & Hvic & ? & Hk). subst.
        setoid_rewrite Hk in H.
        rewrite rewrite_schedule in H. destruct n'; inv H.
      + destruct H0 as (c' & n'' & ? & Hvic & ? & Hk). subst.
        setoid_rewrite Hk in H.
        rewrite rewrite_schedule in H. destruct n''; inv H.
    - apply inj_pair2 in H2, H3. subst.
      rewrite rewrite_schedule in Hequ.
      destruct n'; [inv i |].
      rewrite schedule_match_equation_3 in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct r. destruct n'; step in Hequ; inv Hequ.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  #[global] Instance sbisim_schedule n :
    Proper ((vec_relation sbisim) ==> eq ==> eq ==> sbisim) (schedule n).
  Proof.
    repeat intro. subst. revert n x y y0 y1 H.
    coinduction r CIH.
    symmetric using intuition.
    intros n v1 v2 o c Hv l t Ht.
    destruct l.
    - admit.
    - apply trans_schedule_obs in Ht. contradiction.
    - destruct o as [i |].
      + pose proof (trans_schedule_val_1 _ _ _ _ _ _ Ht). subst.
        pose proof (trans_val_inv Ht).
        specialize (Hv i c). step in Hv. destruct Hv as [Hf Hb].
        pose proof (trans_schedule_thread_val _ _ _ _ _ Ht) as Hv1.
        edestruct Hf; eauto.
        apply trans_thread_schedule_val_1 in H0. eexists; eauto. rewrite H. reflexivity.
      + rewrite rewrite_schedule in Ht.
        destruct n; [| inv Ht].
        destruct (trans_ret_inv Ht). inv H0. apply inj_pair2 in H3. subst.
        exists CTree.stuckI.
        * rewrite rewrite_schedule. constructor.
        * rewrite H. reflexivity.
  Admitted.


  Equations schedule'_match
            (schedule' : forall (n : nat), vec n -> vec n)
            (n : nat)
            (v: vec n)
    : vec n :=
    (* We start by observing the head constructor of the focused thread *)
    schedule'_match schedule' n v i c with observe (v i c) => {

        (* If the computation is over, we check whether there remains someone in the pool *)
        schedule'_match _ _ _ _ _ (RetF (c', _)) with n => {
          (* If not, we are done *)
          schedule'_match _ _ _ _ _ _ (S O)      := Ret (c',tt);
          (* If yes, we pick a new focus *)
          schedule'_match _ _ _ _ _ _ (S n') := ChoiceV n' (fun i' => schedule' n' (remove_vec v i) i' c')
        };

        (* If there's a choice, we propagate it *)
        schedule'_match _ _ _ _ _ (ChoiceF b n' k) :=
          Choice b n' (fun i' => schedule' n (replace_vec v i (fun _ => k i')) i c);

        (* If it's a yield, we pick a new focus and update the state *)
        schedule'_match _ _ _ _ _ (VisF (inl1 (Yield _ s')) k) :=
        ChoiceV n (fun i' => schedule' n (replace_vec v i k) i' s');

        schedule'_match _ _ _ _ _ (VisF (inr1 Spawn) k) :=
          TauV (schedule'
                  (S n)
                  (cons_vec (fun _ => k true) (replace_vec v i (fun _ => k false)))
                  (* The [i] here means that we don't yield at a spawn *)
                  (Fin.L_R 1 i) (* view [i] as a [fin (n + 1)] *)
                  c) (* this [c] doesn't matter, since the running thread won't use it *)

      }.


  (* Definition k1 : bool -> ctree fooE nat := fun b : bool => (if b then Ret 0%nat else Ret 1%nat). *)
  (* Definition k2 : bool -> ctree fooE nat := fun b : bool => (if b then Ret 2%nat else Ret 3%nat). *)
  (* Definition t1 : ctree fooE nat := choiceI2 (Vis Foo k1) (Vis Foo k2). *)
  (* Definition t2 : ctree fooE nat := *)
  (*   choiceI2 (Vis Foo (fun b: bool => if b then Ret 0%nat else Ret 3%nat)) *)
  (*            (Vis Foo (fun b: bool => if b then Ret 2%nat else Ret 1%nat)). *)

  (* sched [Ret tt; t] 0 c ~  sched [t] 0 c *)

  (* sched [t1] ~~ ChoiceI2 (sched [Spawn 0 1]) (sched [Spawn 2 3]) ~~ChoiceI2 (TauV ( *)
  (* sched [t2] ~~ ChoiceI2 (Spawn 0 3) (Spawn 2 1) *)


  CoFixpoint schedule' := schedule'_match schedule'.

  Lemma rewrite_schedule' n v i c : schedule' n v i c ≅ schedule'_match schedule' n v i c.
  Proof.
    step. eauto.
  Qed.

  #[global] Instance equ_schedule' n :
    Proper ((vec_relation (equ eq)) ==> vec_relation (equ eq)) (schedule' n).
  Proof.
    repeat intro. revert H. revert x y i c. revert n.
    coinduction r CIH. intros n v1 v2 i c Hv.
    destruct n as [|n]; [inv i|].
    do 2 rewrite rewrite_schedule'. simp schedule'_match. cbn.
    pose proof (Hv i c). step in H. inv H; eauto. 2: destruct e.
    - clear H1 H2. destruct y. destruct n; cbn in *; auto.
      constructor. intros. apply CIH.
      apply remove_vec_vec_relation; auto.
    - clear H1 H2. destruct y. cbn.
      constructor. intros. eapply CIH.
      apply replace_vec_vec_relation; auto.
    - destruct s. constructor. intros. eapply CIH.
      apply cons_vec_vec_relation; auto.
      apply replace_vec_vec_relation; auto.
    - cbn. constructor. intros. apply CIH.
      apply replace_vec_vec_relation; auto.
  Qed.

  Lemma ChoiceI_schedule'_inv n1 k n2 (v : vec n2) i c :
    ChoiceI n1 k ≅ schedule' n2 v i c ->
    exists k', v i c ≅ ChoiceI n1 k' /\
            forall i', k i' ≅ schedule' n2 (replace_vec v i (fun _ => k' i')) i c.
  Proof.
    intros Hequ.
    rewrite rewrite_schedule' in Hequ. simp schedule'_match in Hequ.
    destruct (observe (v i c)) eqn:?.
    - destruct r, n2; [inv i |]. destruct n2; step in Hequ; inv Hequ.
    - destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
    - destruct vis; [step in Hequ; inv Hequ |].
      destruct (equ_choice_invT _ _ Hequ); subst. clear H0.
      epose proof (equ_choice_invE _ _ Hequ). clear Hequ. cbn in H.
      exists k0. split; auto.
      rewrite ctree_eta. rewrite Heqc0. reflexivity.
  Qed.

  Lemma ChoiceV_schedule'_inv n1 n2 (v : vec n2) i i' c k k' :
    ChoiceV n1 k ≅ schedule' n2 v i c ->
    observe (v i c) = ChoiceF true n1 k' -> (* can replace with ≅ if needed *)
    k i' ≅ schedule' n2 (replace_vec v i (fun _ => k' i')) i c.
  Proof.
    intros Hequ Heq.
    rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
    rewrite Heq in Hequ.
    pose proof (equ_choice_invE _ _ Hequ). cbn in H.
    rewrite H. reflexivity.
  Qed.

  Lemma trans_schedule'_val_1 {X} n v i c (x : X) t :
    trans (val x) (schedule' n v i c) t ->
    n = 1%nat.
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (schedule' n v i c)).
    pose proof (ctree_eta (go (observe (schedule' n v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val x).
    revert t n v i c x Heql Heqc1 H0.
    induction H; intros t' n' v i c x' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule'_inv in Hequ. destruct Hequ as (k' & Hequ & Hk).
      setoid_rewrite Hk in IHtrans_.
      eapply IHtrans_; eauto.
    - apply inj_pair2 in H1. subst.
      rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct n'; [inv i |]. destruct n'; [| destruct r; step in Hequ; inv Hequ]; auto.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  Lemma trans_schedule'_thread_val {X} v i c (x : X) t :
    trans (val x) (schedule' 1 v i c) t ->
    trans (val x) (v i c) CTree.stuckI.
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (schedule' 1 v i c)).
    pose proof (ctree_eta (go (observe (schedule' 1 v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val x).
    revert t v i c x Heql Heqc1 H0.
    induction H; intros t' v i c c' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule'_inv in Hequ. destruct Hequ as (k' & Hequ & Hk).
      setoid_rewrite Hk in IHtrans_.
      rewrite Hequ.
      econstructor.
      specialize (IHtrans_ _ (replace_vec v i (fun _ : config => k' x)) i c _ eq_refl eq_refl).
      rewrite replace_vec_eq in IHtrans_. apply IHtrans_. reflexivity.
    - apply inj_pair2 in H1. subst.
      rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + cbn. red. rewrite Hv. destruct r, u.
        step in Hequ. inv Hequ. constructor.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  Lemma trans_schedule'_obs {X} n v i c (e : parE config X) (x : X) t :
    trans (obs e x) (schedule' n v i c) t ->
    False.
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (schedule' n v i c)).
    pose proof (ctree_eta (go (observe (schedule' n v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (obs _ _).
    revert t n v i c e x Heql Heqc1 H0.
    induction H; intros t' n' v i c e' x' Heql Heq Hequ; try inv Heql; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule'_inv in Hequ. destruct Hequ as (k' & Hequ & Hk).
      setoid_rewrite Hk in IHtrans_.
      eapply IHtrans_; eauto.
    - apply inj_pair2 in H2, H3. subst.
      rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct n'. inv i. destruct r. destruct n'; step in Hequ; inv Hequ.
      + destruct e; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
  Qed.

  Lemma trans_schedule'_thread_tau n v i c t (Hbound : choiceI_bound 1 (v i c)) :
    trans tau (schedule' n v i c) t ->
    (exists (c' : config) n' i',
        trans (val (c', ())) (v i c) CTree.stuckI /\
          {H: n = S (S n') &
                t ≅ schedule' (S n') (remove_vec_helper n (S n') v i H) i' c'}) \/
      (exists t', trans tau (v i c) t' /\
               choiceI_bound 1 t' /\
               t ≅ schedule' n (replace_vec v i (fun _ => t')) i c) \/
      (exists c' k, visible (v i c) (Vis (inl1 (Yield _ c')) k) /\
                 exists i', t ≅ schedule' n (replace_vec v i k) i' c') \/
      (exists k, visible (v i c) (Vis (inr1 Spawn) k) /\
              t ≅ schedule'
                (S n)
                (cons_vec (fun _ => k true) (replace_vec v i (fun _ => k false)))
                (Fin.L_R 1 i)
                c).
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (schedule' n v i c)).
    pose proof (ctree_eta (go (observe (schedule' n v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember tau.
    revert t n v i c Heqc1 Heql H0 Hbound.
    induction H; intros t' n' v i c Heq Heql Hequ Hbound; subst.
    - rewrite <- ctree_eta in Hequ.
      apply ChoiceI_schedule'_inv in Hequ. destruct Hequ as (k' & Hequ & Hk).
      setoid_rewrite Hk in IHtrans_.
      edestruct IHtrans_ as [? | [? | [? | ?]]]; eauto; clear IHtrans_.
      { rewrite replace_vec_eq. apply choiceI_step. rewrite <- Hequ. auto. }
      + left. destruct H0 as (c' & n'' & i' & Ht & Hn' & Ht').
        exists c', n'', i'. rewrite replace_vec_eq in Ht. split.
        * rewrite Hequ. econstructor. apply Ht.
        * econstructor. rewrite Ht'.
          erewrite <- remove_vec_helper_replace_vec_eq. reflexivity.
      + right. left. destruct H0 as (t'' & Ht & Hbound' & Ht').
        rewrite replace_vec_eq in Ht. exists t''. split; [| split]; auto.
        * rewrite Hequ. econstructor. apply Ht.
        * rewrite replace_vec_twice in Ht'. apply Ht'.
      + right. right. left. destruct H0 as (c' & k'' & Hvis & i' & Ht').
        rewrite replace_vec_eq in Hvis.
        exists c', k''. split.
        * rewrite Hequ. econstructor. apply Hvis.
        * exists i'. setoid_rewrite replace_vec_twice in Ht'. apply Ht'.
      + right. right. right. destruct H0 as (kb & Hvis & Ht').
        rewrite replace_vec_eq in Hvis.
        exists kb. split.
        * rewrite Hequ. econstructor. apply Hvis.
        * rewrite replace_vec_twice in Ht'. apply Ht'.
    - rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
      destruct (observe (v i c)) eqn:Hv; [| destruct e |].
      + destruct r, u, n'; [inv i |].
        destruct n'; [step in Hequ; inv Hequ; inv x |].
        left.
        pose proof (ctree_eta t). rewrite Heq in H0. rewrite <- ctree_eta in H0.
        clear Heq. rename H0 into Heq. cbn in *.
        destruct (equ_choice_invT _ _ Hequ) as [? _]; subst.
        pose proof (equ_choice_invE _ _ Hequ) as Hk. cbn in Hk.
        eexists. exists n', x. split.
        * cbn. red. rewrite Hv. constructor.
        * exists eq_refl.
          rewrite <- Heq. rewrite <- H. rewrite Hk. reflexivity.
      + right. right. left. destruct y. cbn in Hequ.
        exists c0, k0. split.
        * cbn. red. rewrite Hv. constructor. reflexivity.
        * pose proof (ctree_eta t). rewrite Heq in H0. rewrite <- ctree_eta in H0.
          setoid_rewrite <- H0. setoid_rewrite <- H.
          destruct (equ_choice_invT _ _ Hequ); subst. clear H2.
          exists x. pose proof (equ_choice_invE _ _ Hequ). setoid_rewrite H1.
          reflexivity.
      + right. right. right. destruct s. cbn in Hequ.
        destruct (equ_choice_invT _ _ Hequ) as [? _]. subst.
        pose proof (equ_choice_invE _ _ Hequ) as Hk. cbn in Hk.
        eexists. split.
        * cbn. red. rewrite Hv. constructor. reflexivity.
        * rewrite ctree_eta. rewrite <- Heq. rewrite <- ctree_eta.
          rewrite <- H. apply Hk.
      + destruct vis; [| step in Hequ; inv Hequ].
        right. left.
        destruct (equ_choice_invT _ _ Hequ); subst. clear H1.
        eexists. split; [| split].
        * cbn. red. rewrite Hv. constructor 2 with (x := x). reflexivity.
        * step in Hbound. red in Hbound. rewrite Hv in Hbound. inversion Hbound. subst.
          apply inj_pair2 in H2. subst. apply H1.
        * pose proof (equ_choice_invE _ _ Hequ).
          pose proof (ctree_eta t). rewrite Heq in H1. rewrite <- ctree_eta in H1.
          rewrite <- H1. rewrite <- H. rewrite H0. reflexivity.
    - clear H.
      rewrite rewrite_schedule' in Hequ. rewrite schedule'_match_equation_1 in Hequ.
      destruct (observe (v i c)) eqn:Hv.
      + destruct n'. inv i. destruct r. destruct n'; step in Hequ; inv Hequ.
      + destruct e0; [destruct y | destruct s]; step in Hequ; inv Hequ.
      + step in Hequ; inv Hequ.
    - inv Heql.
  Qed.

  Lemma trans_thread_schedule'_val_1 {X} v i c (x : X) t :
    trans (val x) (v i c) t ->
    trans (val x) (schedule' 1 v i c) CTree.stuckI.
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (v i c)).
    pose proof (ctree_eta (go (observe (v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val x).
    revert t v i c x Heql Heqc1 H0.
    induction H; intros t' v i c x' Heql Heq Hequ; try inv Heql.
    - (* is there a better way to do this *)
      step in Hequ. inv Hequ. apply inj_pair2 in H3; subst.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1; rewrite <- H4.
      econstructor. eapply IHtrans_; try reflexivity. rewrite REL.
      rewrite replace_vec_eq. reflexivity.
    - apply inj_pair2 in H1. subst.
      step in Hequ. inv Hequ.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1, <- H.
      cbn. destruct y, u. econstructor.
  Qed.

  Lemma trans_thread_schedule'_val_SS n v i c (c' : config) t :
    trans (val (c', ())) (v i c) t ->
    forall i', trans tau (schedule' (S (S n)) v i c) (schedule' (S n) (remove_vec v i) i' c').
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (v i c)).
    pose proof (ctree_eta (go (observe (v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember (val (c', ())).
    revert t v i c c' Heql Heqc1 H0.
    induction H; intros t' v i c x' Heql Heq Hequ i'; try inv Heql.
    - (* is there a better way to do this *)
      step in Hequ. inv Hequ. apply inj_pair2 in H3; subst.
      setoid_rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1. rewrite <- H4.
      epose proof (IHtrans_ t' (replace_vec v i (fun _ => k2 x)) i c x' eq_refl eq_refl _ i').
      Unshelve. 2: { rewrite REL. rewrite replace_vec_eq. reflexivity. }
      econstructor.
      erewrite <- remove_vec_replace_vec_eq in H0. apply H0.
    - apply inj_pair2 in H0. subst. step in Hequ. inv Hequ.
      setoid_rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1. rewrite <- H.
      econstructor. reflexivity.
  Qed.

  Lemma trans_thread_schedule'_tau n v i c t :
    trans tau (v i c) t ->
    trans tau (schedule' n v i c) (schedule' n (replace_vec v i (fun _ => t)) i c).
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (v i c)).
    pose proof (ctree_eta (go (observe (v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (observe t). remember tau.
    revert t v i c Heql Heqc1 H0.
    induction H; intros t' v i c Heql Heq Hequ; try inv Heql.
    - step in Hequ. inv Hequ. apply inj_pair2 in H3; subst.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1. rewrite <- H4.
      constructor 1 with (x:=x).
      erewrite <- (replace_vec_twice n v i (fun _ => k2 x) (fun _ => t')).
      apply IHtrans_; auto.
      rewrite replace_vec_eq. rewrite REL. reflexivity.
    - step in Hequ. inv Hequ. apply inj_pair2 in H3; subst.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1. rewrite <- H4.
      constructor 2 with (x:=x).
      pose proof (ctree_eta t).
      rewrite Heq in H0. clear Heq. rename H0 into Heq. rewrite <- ctree_eta in Heq.
      apply equ_schedule'. (* TODO: some instance is missing *)
      apply replace_vec_vec_relation; repeat intro; try reflexivity.
      rewrite <- Heq. rewrite <- REL. auto.
  Qed.

  Lemma trans_thread_schedule'_spawn n (v : vec n) i c k b :
    trans (obs (inr1 (Spawn)) b) (v i c) (k b) ->
    trans tau (schedule' n v i c)
          (schedule'
             (S n)
             (cons_vec (fun _ => k true) (replace_vec v i (fun _ => k false)))
             (Fin.L_R 1 i)
             c).
  Proof.
    unfold trans; intro. cbn in H. red in H.
    remember (observe (v i c)).
    pose proof (ctree_eta (go (observe (v i c)))).
    rewrite <- Heqc0 in H0 at 1. cbn in H0. clear Heqc0.
    remember (obs _ b) as l.
    remember (observe (k b)) as k'.
    revert b k n v i c H0 Heql Heqk'.
    induction H; intros; subst; try inv Heql.
    - step in H0. inv H0. apply inj_pair2 in H4. subst.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1. rewrite <- H5.
      constructor 1 with (x:=x).
      rewrite <- (replace_vec_twice n0 v i (fun _ => k3 x) (fun _ => k0 false)).
      eapply IHtrans_; eauto. rewrite REL. rewrite replace_vec_eq. reflexivity.
    - step in H0. inv H0. apply inj_pair2 in H3, H4, H5, H6. subst.
      rewrite rewrite_schedule'. rewrite schedule'_match_equation_1. rewrite <- H7.
      constructor 2 with (x:=Fin.F1).
  Abort.

  (* actually this is trivial, it's just by defn *)
  Lemma trans_forall_spawn (e : parE config bool) (k : bool -> ctree (parE config) (config * ())) k' :
    (forall b, trans (obs (inr1 (Spawn)) b) (Vis e k) (k' b)) ->
    forall b, k b ≅ k' b.
  Proof.
    intros. specialize (H b). inv H.
    apply inj_pair2 in H2, H3, H4, H5. subst.
    rewrite (ctree_eta t) in H1. rewrite H6 in H1.
    rewrite <- ctree_eta in H1. auto.
  Qed.

  Lemma trans_thread_schedule'_yield_vis (c' : config) n v i i' c e (k k' : thread) :
    observe (v i c) = VisF e k' ->
    (forall c'', trans (obs (inl1 (Yield _ c')) c'') (v i c) (k c'')) ->
    trans tau (schedule' n v i c) (schedule' n (replace_vec v i k) i' c').
  Proof.
    unfold trans; intros. rewrite rewrite_schedule'. rewrite schedule'_match_equation_1. rewrite H.
    (* destruct e. *)
    pose proof (H0 c). cbn in H1. red in H1.
    rewrite H in H1. inv H1. apply inj_pair2 in H4, H5, H6, H7. subst.
    constructor 2 with (x:=i').
    apply equ_schedule'.
    apply replace_vec_vec_relation. repeat intro. reflexivity.
    intro. specialize (H0 x). cbn in H0. red in H0. rewrite H in H0.
    inv H0. apply inj_pair2 in H4, H5, H6, H7. subst. rewrite H2.
    rewrite ctree_eta. rewrite H9. rewrite <- ctree_eta. reflexivity.
  Qed.

  Lemma sbisim_vis_visible {E R X} (t2 : ctree E R) (e : E X) k1 (Hin: inhabited X) (Hbound : choiceI_bound 1 t2) :
    Vis e k1 ~ t2 ->
    exists k2, visible t2 (Vis e k2) /\ (forall x, k1 x ~ k2 x).
  Proof.
    unfold trans in *; intros.
    step in H. destruct H as [Hf Hb].
    cbn in *. unfold transR in Hf.
    assert
      (forall (l : label) (t' : ctree E R),
          trans_ l (VisF e k1) (observe t') ->
          {u' : ctree E R | trans_ l (observe t2) (observe u') /\ t' ~ u'}).
    {
      unfold trans in *.
      intros. apply constructive_indefinite_description.
      edestruct Hf; eauto.
    } clear Hf. rename X0 into Hf.
    destruct Hin as [x].
    edestruct (Hf (obs e x)). constructor. reflexivity.
    destruct a. clear H0 Hb.
    dependent induction H.
    - edestruct @choiceI_step as (? & Hbound').
      {
        assert (t2 ≅ ChoiceI n k).
        rewrite ctree_eta. rewrite <- x. reflexivity.
        rewrite H0 in Hbound. apply Hbound.
      }
      subst.
      edestruct IHtrans_; try reflexivity; eauto.
      intros. rewrite <- x in Hf. edestruct Hf. eauto.
      destruct a.
      exists x3. split. inv H1. apply inj_pair2 in H6. subst.
      assert (x1 = x4).
      {
        remember 1%nat.
        destruct x1.
        - dependent destruction x4; auto.
          inversion Heqn. subst. inv x4.
        - inv Heqn. inv x1.
      }
      subst. auto. auto.
      exists x3. split; auto. red. cbn. rewrite <- x. econstructor. apply H0. apply H0.
    - rewrite <- x2 in Hf.
      eexists. Unshelve.
      2: {
        intros x'. edestruct Hf. constructor. reflexivity.
        Unshelve. apply x3. apply x'.
      }
      split.
      + red. cbn. rewrite <- x2. constructor. intros. destruct Hf. destruct a.
        inv H0. apply inj_pair2 in H4, H5, H6, H7. subst.
        rewrite (ctree_eta t0) in H3. rewrite H8 in H3. rewrite <- ctree_eta in H3. auto.
      + intros. destruct Hf. destruct a. cbn. auto.
  Qed.

  Lemma sbisim_visible {E R X} (t1 t2 : ctree E R) (e : E X) k1 (Hin: inhabited X) (Hbound1 : choiceI_bound 1 t1) (Hbound2 : choiceI_bound 1 t2):
    t1 ~ t2 ->
    visible t1 (Vis e k1) ->
    exists k2, visible t2 (Vis e k2) /\ (forall x, k1 x ~ k2 x).
  Proof.
    unfold trans; intros. cbn in *. red in H0. remember (observe t1). remember (observe (Vis e k1)).
    revert X t1 e k1 t2 H Heqc Heqc0 Hin Hbound1 Hbound2.
    induction H0; intros; auto.
    - edestruct @choiceI_step as (? & Hbound1').
      {
        assert (t1 ≅ ChoiceI n k).
        rewrite ctree_eta. rewrite <- Heqc. reflexivity.
        rewrite H1 in Hbound1. apply Hbound1.
      }
      subst. eapply IHvisible_. 2: reflexivity. all: eauto.
      pose proof (ctree_eta t1). rewrite <- Heqc in H1. rewrite H1 in H.
      epose proof (sbisim_ChoiceI_1_inv _ _ _ H); auto. apply H2.
    - inv Heqc0.
    - inv Heqc0. apply inj_pair2 in H3, H4. subst.
      apply sbisim_vis_visible; auto.
      pose proof (ctree_eta t1).  rewrite <- Heqc in H1.
      (* TODO: clean this up *) eapply equ_VisF in H. rewrite H in H1.
      rewrite H1 in H0. auto.
    - inv Heqc0.
  Qed.

  Lemma visible_yield_trans_schedule' n v i c i' c' k (Hbound : choiceI_bound 1 (v i c)) :
    visible (v i c) (Vis (inl1 (Yield config c')) k) ->
    trans tau (schedule' n v i c) (schedule' n (replace_vec v i k) i' c').
  Proof.
    intros. cbn in *. red in H |- *.
    remember (observe (v i c)). remember (observe (Vis _ k)).
    revert v i c i' c' k Heqc0 Heqc1 Hbound.
    induction H; intros; subst; try inv Heqc1.
    - edestruct @choiceI_step as (? & Hbound').
      {
        assert (v i c ≅ ChoiceI n0 k).
        rewrite ctree_eta. rewrite <- Heqc0. reflexivity.
        rewrite H0 in Hbound. apply Hbound.
      } subst.
      rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1.
      rewrite <- Heqc0. constructor 1 with (x:=x).
      rewrite <- (replace_vec_twice _ v i (fun _ => k x) k0).
      eapply IHvisible_; auto; rewrite replace_vec_eq; eauto.
    - apply inj_pair2 in H2, H3. subst.
      rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1.
      rewrite <- Heqc0. econstructor. apply equ_schedule'.
      apply replace_vec_vec_relation; repeat intro; auto.
  Qed.

  Lemma visible_spawn_trans_schedule' n v i c k (Hbound : choiceI_bound 1 (v i c)) :
    visible (v i c) (Vis (inr1 Spawn) k) ->
    trans tau (schedule' n v i c)
          (schedule' (S n)
                     (cons_vec (fun _ => k true)
                               (replace_vec v i (fun _ => k false)))
                     (Fin.L_R 1 i)
                     c).
  Proof.
    intros. cbn in *. red in H |- *.
    remember (observe (v i c)). remember (observe (Vis _ k)).
    revert v i c k Heqc0 Heqc1 Hbound.
    induction H; intros; subst; try inv Heqc1.
    - edestruct @choiceI_step as (? & Hbound').
      {
        assert (v i c ≅ ChoiceI n0 k).
        rewrite ctree_eta. rewrite <- Heqc0. reflexivity.
        rewrite H0 in Hbound. apply Hbound.
      } subst.
      rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1.
      rewrite <- Heqc0. constructor 1 with (x:=x).
      rewrite <- (replace_vec_twice _ v i (fun _ => k x) (fun _ => k0 false)).
      eapply IHvisible_; auto; rewrite replace_vec_eq; eauto.
    - apply inj_pair2 in H2, H3. subst.
      rewrite rewrite_schedule' at 1. rewrite schedule'_match_equation_1.
      rewrite <- Heqc0. econstructor. apply Fin.F1. apply equ_schedule'.
      apply cons_vec_vec_relation; auto.
      apply replace_vec_vec_relation; repeat intro; auto.
  Qed.

  #[global] Instance sbisim_schedule' n :
    Proper ((vec_relation (fun x y => sbisim x y /\ choiceI_bound 1 x /\ choiceI_bound 1 y)) ==> vec_relation sbisim) (schedule' n).
  Proof.
    repeat intro. revert H. revert n x y i c.
    coinduction r CIH.
    symmetric using idtac.
    {
      intros. apply H. repeat intro. split; [symmetry | split]; apply H0.
    }
    intros n v1 v2 i c Hv l t Ht.
    destruct l.
    - apply trans_schedule'_thread_tau in Ht.
      2: { apply Hv. }
      decompose [or] Ht; clear Ht.
      + destruct H as (c' & n' & i' & Ht & Hn & Hequ).
        subst. pose proof (Hv i c) as (Hsb & _). step in Hsb. destruct Hsb as [Hf Hb].
        edestruct Hf as [? ? ?]; eauto.
        eapply trans_thread_schedule'_val_SS in H.
        eexists. apply H. rewrite Hequ. apply CIH.
        cbn. apply remove_vec_vec_relation; auto.
      + destruct H0 as (t' & Ht & Hbound' & Hequ).
        pose proof (Hv i c) as (Hsb & Hbound1 & Hbound2). step in Hsb. destruct Hsb as [Hf _].
        edestruct Hf as [? ? ?]; eauto.
        pose proof (trans_choiceI_bound _ _ _ _ Hbound2 H).
        apply trans_thread_schedule'_tau in H.
        eexists; eauto. rewrite Hequ. apply CIH.
        apply replace_vec_vec_relation; auto.
      + destruct H as (c' & k & Hvis & i' & Hequ).
        pose proof (Hv i c) as (Hsb & Hbound1 & Hbound2).
        pose proof Hvis as Hvis'.
        eapply sbisim_visible in Hvis'; eauto. destruct Hvis' as (k' & ? & ?).
        exists (schedule' n (replace_vec v2 i k') i' c').
        2: {
          rewrite Hequ. apply CIH. apply replace_vec_vec_relation; auto.
          intros; split; [| split]; auto.
          - pose proof (visible_choiceI_bound _ _ _ _ _ Hbound1 Hvis).
            step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
          - pose proof (visible_choiceI_bound _ _ _ _ _ Hbound2 H).
            step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
        }
        apply visible_yield_trans_schedule'; auto.
      + destruct H as (k & Hvis & Hequ).
        pose proof (Hv i c) as (Hsb & Hbound1 & Hbound2).
        pose proof Hvis as Hvis'.
        eapply sbisim_visible in Hvis'; eauto. 2: { constructor. apply true. }
        destruct Hvis' as (k' & ? & ?).
        exists (schedule' (S n)
                     (cons_vec (fun _ => k' true)
                               (replace_vec v2 i (fun _ => k' false)))
                     (Fin.L_R 1 i) c).
        2: { rewrite Hequ. apply CIH. apply cons_vec_vec_relation; auto.
             - apply replace_vec_vec_relation; auto; split; auto. split.
               + pose proof (visible_choiceI_bound _ _ _ _ _ Hbound1 Hvis).
                 step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
               + pose proof (visible_choiceI_bound _ _ _ _ _ Hbound2 H).
                 step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
             - split; auto. split.
               + pose proof (visible_choiceI_bound _ _ _ _ _ Hbound1 Hvis).
                 step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
               + pose proof (visible_choiceI_bound _ _ _ _ _ Hbound2 H).
                 step in H1. inversion H1. apply inj_pair2 in H4, H5. subst. apply H3.
        }
        apply visible_spawn_trans_schedule'; auto.
    - apply trans_schedule'_obs in Ht. contradiction.
    - pose proof (trans_schedule'_val_1 _ _ _ _ _ _ Ht). subst.
      pose proof (trans_val_inv Ht).
      destruct (Hv i c) as (Hsb & _). step in Hsb. destruct Hsb as [Hf Hb].
      pose proof (trans_schedule'_thread_val _ _ _ _ _ Ht) as Hv1.
      edestruct Hf; eauto.
      apply trans_thread_schedule'_val_1 in H0. eexists; eauto. rewrite H. reflexivity.
  Qed.

End parallel.
